package harness

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"net/http"
	"regexp"
	"time"

	"github.com/gin-gonic/gin"
)

// callbackStatus* are the only values ever appended to the OAuth redirect.
// The redirect URL carries no tokens, codes or personal data.
const (
	callbackRedirectBase = "solocompass://google-connected?status="
	callbackConnected    = "connected"
	callbackError        = "error"
)

var statePattern = regexp.MustCompile(`^[A-Za-z0-9_-]{20,128}$`)

func randomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// handleGoogleStart begins the one-use PKCE Google read-only OAuth flow.
func (s *Server) handleGoogleStart(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		failJSON(c, http.StatusServiceUnavailable, "database not configured")
		return
	}
	if !s.cfg.googleConfigured() || s.google == nil {
		failJSON(c, http.StatusServiceUnavailable, "google not configured")
		return
	}
	var body struct {
		Calendar *bool `json:"calendar"`
		Mail     *bool `json:"mail"`
	}
	if err := decodeStrict(c, &body, maxBodyJSON); err != nil {
		failJSON(c, 400, "invalid request")
		return
	}
	if body.Calendar == nil || body.Mail == nil || (!*body.Calendar && !*body.Mail) {
		failJSON(c, 400, "at least one of calendar, mail must be true")
		return
	}

	state, err := randomToken(32)
	if err != nil {
		failJSON(c, 500, "state generation failed")
		return
	}
	verifier, err := randomToken(64) // 64 bytes -> 86-char PKCE verifier
	if err != nil {
		failJSON(c, 500, "state generation failed")
		return
	}
	// The PKCE verifier is a secret: encrypted at rest, AAD-bound to the
	// owner and the PKCE purpose.
	verifierEnc, err := s.crypto.SealToken(ident.ID, purposePKCEVerifier, []byte(verifier))
	if err != nil {
		failJSON(c, 500, "state generation failed")
		return
	}
	sum := sha256.Sum256([]byte(verifier))
	challenge := base64.RawURLEncoding.EncodeToString(sum[:])

	expiry := s.now().Add(stateTTL)
	rec := StateRecord{
		State:        state,
		UserID:       ident.ID,
		VerifierEnc:  verifierEnc,
		WantCalendar: *body.Calendar,
		WantMail:     *body.Mail,
		ExpiresAt:    expiry,
	}
	if err := s.store.CreateState(c.Request.Context(), rec); err != nil {
		failJSON(c, 503, "store unavailable")
		return
	}
	url := s.google.AuthorizationURL(state, challenge, *body.Calendar, *body.Mail)
	c.JSON(http.StatusOK, gin.H{
		"authorization_url": url,
		"expires_at":        expiry.UTC().Format(time.RFC3339),
	})
}

// handleGoogleCallback is the OAuth redirect target. It is authorized by the
// one-use, expiring, server-issued state only. Every failure path redirects to
// solocompass://google-connected?status=error; nothing sensitive is ever put
// into the redirect URL or logs.
func (s *Server) handleGoogleCallback(c *gin.Context) {
	status := callbackError
	defer func() {
		c.Redirect(http.StatusFound, callbackRedirectBase+status)
	}()

	if s.store == nil || !s.cfg.googleConfigured() || s.google == nil || s.crypto == nil {
		return
	}
	q := c.Request.URL.Query()
	code := q.Get("code")
	state := q.Get("state")
	denied := q.Get("error") != ""
	if !statePattern.MatchString(state) {
		return
	}

	// The valid state is consumed exactly once even when the user denied the
	// consent screen: a denial can never leave the state reusable.
	rec, err := s.store.ConsumeState(c.Request.Context(), state, s.now())
	if err != nil {
		// Unknown, replayed and expired states all fail closed. The state
		// value itself is never logged.
		return
	}
	if denied || code == "" {
		return
	}

	verifier, err := s.crypto.OpenToken(rec.UserID, purposePKCEVerifier, rec.VerifierEnc)
	if err != nil {
		return
	}
	tok, err := s.google.ExchangeCode(c.Request.Context(), code, string(verifier))
	if err != nil {
		return
	}
	tok.GoogleEmail = s.google.FetchGoogleEmail(c.Request.Context(), tok)

	// include_granted_scopes=true lets Google return historic grants that this
	// flow never selected. Only THIS state's selection may become effective:
	// a calendar-only flow can never enable mail.
	allowed := []string{"openid", "email"}
	if rec.WantCalendar {
		allowed = append(allowed, ScopeCalendarReadonly)
	}
	if rec.WantMail {
		allowed = append(allowed, ScopeGmailReadonly)
	}
	tok.Scopes = intersectScopes(tok.Scopes, allowed)

	accessEnc, err := s.crypto.SealToken(rec.UserID, purposeAccess, []byte(tok.AccessToken))
	if err != nil {
		return
	}
	refreshEnc, err := s.crypto.SealToken(rec.UserID, purposeRefresh, []byte(tok.RefreshToken))
	if err != nil {
		return
	}
	st := StoredTokens{
		AccessEnc:   accessEnc,
		RefreshEnc:  refreshEnc,
		TokenType:   tok.TokenType,
		Scopes:      tok.Scopes,
		GoogleEmail: tok.GoogleEmail,
		ExpiresAt:   tok.Expiry,
	}
	if st.TokenType == "" {
		st.TokenType = "Bearer"
	}
	if st.Scopes == nil {
		st.Scopes = []string{}
	}
	// ReplaceConnection (not the refresh commit path): under the owner row
	// lock the state's epoch must still be current, the epoch advances, the
	// tokens are stored under the NEW epoch and other pending states are
	// cancelled. A racing disconnect or a second callback makes this fail.
	if err := s.store.ReplaceConnection(c.Request.Context(), rec.UserID, rec.Generation, st); err != nil {
		return
	}
	status = callbackConnected
}

// handleGoogleDisconnect erases local access immediately (bumping the
// connection generation and cancelling pending states in the same atomic
// store operation), then attempts provider revocation. The response reports
// revocation honestly.
func (s *Server) handleGoogleDisconnect(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		failJSON(c, http.StatusServiceUnavailable, "database not configured")
		return
	}
	st, err := s.store.GetTokens(c.Request.Context(), ident.ID)
	if errors.Is(err, ErrNotFound) {
		// Nothing connected: still bump the generation and cancel any pending
		// state so a late callback cannot create a connection afterwards.
		if _, derr := s.store.Disconnect(c.Request.Context(), ident.ID); derr != nil {
			failJSON(c, 503, "store unavailable")
			return
		}
		c.JSON(http.StatusOK, gin.H{"disconnected": true, "provider_revocation_confirmed": false})
		return
	}
	if err != nil {
		failJSON(c, 503, "store unavailable")
		return
	}
	// Local erasure first: access dies immediately regardless of Google. This
	// also invalidates every in-flight exchange/refresh (generation bump).
	if _, err := s.store.Disconnect(c.Request.Context(), ident.ID); err != nil {
		failJSON(c, 503, "store unavailable")
		return
	}
	revoked := false
	if s.google != nil {
		if tok, derr := s.decryptTokens(ident.ID, st); derr == nil {
			revoked = s.google.Revoke(c.Request.Context(), tok)
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"disconnected":                  true,
		"provider_revocation_confirmed": revoked,
	})
}
