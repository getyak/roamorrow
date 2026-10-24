package harness

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// Server wires the harness API: verified Supabase auth, owner-scoped store,
// encrypted Google tokens, bounded read tools, the DeepSeek loop and the
// authenticated MCP endpoint.
type Server struct {
	cfg      Config
	store    Store
	verifier Verifier
	google   GoogleReader
	deepseek DeepSeekClient
	crypto   *Cipher
	limiter  *Limiter
	now      func() time.Time
}

// NewServer builds a Server. Missing optional config degrades to disabled
// capabilities (never a crash, never a bypass). Only non-nil concrete clients
// are assigned so interface fields never carry typed nils.
func NewServer(cfg Config, store Store) *Server {
	s := &Server{
		cfg:     cfg,
		store:   store,
		limiter: NewLimiter(cfg.RatePerMin, cfg.MaxConcurrentUser, cfg.MaxConcurrentTotal),
		now:     time.Now,
	}
	if v := NewSupabaseVerifier(cfg.SupabaseURL, cfg.SupabaseAnonKey); v != nil {
		s.verifier = v
	}
	if g := newGoogleAPI(cfg); g != nil {
		s.google = g
	}
	if d := newDeepSeekClient(cfg); d != nil {
		s.deepseek = d
	}
	if len(cfg.TokenKey) == 32 {
		if c, err := NewCipher(cfg.TokenKey); err == nil {
			s.crypto = c
		}
	}
	return s
}

// Register mounts the frozen wire contract: all routes below /v1/harness plus
// /mcp. Protected routes require the project's Supabase bearer token.
func (s *Server) Register(r *gin.Engine) {
	h := r.Group("/v1/harness")
	h.GET("/capabilities", s.handleCapabilities)
	// OAuth redirect target: authorized by the one-use server-issued state,
	// never by client-supplied identity.
	h.GET("/google/callback", s.handleGoogleCallback)

	auth := h.Group("", s.AuthMiddleware)
	auth.GET("/profile", s.handleGetProfile)
	auth.PUT("/profile", s.handlePutProfile)
	auth.POST("/google/start", s.handleGoogleStart)
	auth.DELETE("/google", s.handleGoogleDisconnect)
	auth.GET("/context", s.handleContext)
	auth.POST("/tools/call", s.handleToolsCall)
	auth.POST("/chat", s.handleChat)

	r.POST("/mcp", s.checkOrigin, s.AuthMiddleware, s.handleMCP)
	// Origin is validated on every method, including GET/DELETE, before the
	// 405 (no SSE) answer.
	r.GET("/mcp", s.checkOrigin, s.handleMCPMethodNotAllowed)
	r.DELETE("/mcp", s.checkOrigin, s.handleMCPMethodNotAllowed)
}

// checkOrigin validates browser Origin headers on /mcp against the configured
// allow-list (DNS-rebinding protection). Absent Origin (non-browser MCP
// clients) is allowed; present-but-unlisted Origin is rejected. When no
// origin is configured, any Origin is rejected (fail closed).
func (s *Server) checkOrigin(c *gin.Context) {
	origin := strings.TrimSpace(c.GetHeader("Origin"))
	if origin == "" {
		c.Next()
		return
	}
	for _, o := range s.cfg.AllowedOrigins {
		if origin == o {
			c.Next()
			return
		}
	}
	c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "origin not allowed"})
}

func failJSON(c *gin.Context, status int, msg string) {
	c.JSON(status, gin.H{"error": msg})
}

// decodeStrict decodes a single complete JSON object with unknown fields
// rejected and a hard body-size cap on the whole request (trailing whitespace
// and oversized tails included). Malformed JSON, trailing values (`]`, `}`,
// a second object) and oversized bodies all fail: a second Decode must
// return io.EOF.
func decodeStrict(c *gin.Context, dst any, max int64) error {
	body, err := io.ReadAll(http.MaxBytesReader(c.Writer, c.Request.Body, max))
	if err != nil {
		return err
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return err
	}
	if err := dec.Decode(new(any)); !errors.Is(err, io.EOF) {
		return errors.New("trailing json")
	}
	return nil
}

func (s *Server) handleCapabilities(c *gin.Context) {
	c.JSON(http.StatusOK, s.cfg.Capabilities(s.store != nil))
}

type googleStatus struct {
	Connected bool     `json:"connected"`
	Email     string   `json:"email"`
	Scopes    []string `json:"scopes"`
}

type profileResponse struct {
	UserID           string       `json:"user_id"`
	Email            string       `json:"email"`
	DisplayName      string       `json:"display_name"`
	HomeCity         string       `json:"home_city"`
	Interests        []string     `json:"interests"`
	AIContextConsent bool         `json:"ai_context_consent"`
	Google           googleStatus `json:"google"`
}

func (s *Server) profileFor(c *gin.Context, ident Identity) (profileResponse, bool) {
	out := profileResponse{
		UserID:    ident.ID,
		Email:     ident.Email,
		Interests: []string{},
		Google:    googleStatus{Scopes: []string{}},
	}
	if s.store == nil {
		failJSON(c, 503, "database not configured")
		return out, false
	}
	p, err := s.store.GetProfile(c.Request.Context(), ident.ID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		failJSON(c, 503, "store unavailable")
		return out, false
	}
	if err == nil {
		out.DisplayName = p.DisplayName
		out.HomeCity = p.HomeCity
		if p.Interests != nil {
			out.Interests = p.Interests
		}
		out.AIContextConsent = p.AIContextConsent
	}
	if st, err := s.store.GetTokens(c.Request.Context(), ident.ID); err == nil {
		out.Google.Connected = true
		out.Google.Email = st.GoogleEmail
		out.Google.Scopes = st.Scopes
		if out.Google.Scopes == nil {
			out.Google.Scopes = []string{}
		}
	}
	return out, true
}

func (s *Server) handleGetProfile(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	out, ok := s.profileFor(c, ident)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, out)
}

type putProfileRequest struct {
	DisplayName      *string   `json:"display_name"`
	HomeCity         *string   `json:"home_city"`
	Interests        *[]string `json:"interests"`
	AIContextConsent *bool     `json:"ai_context_consent"`
}

// handlePutProfile fully replaces the editable profile fields. Email and
// user id come exclusively from verified auth; a body carrying them is
// rejected outright (unknown fields).
func (s *Server) handlePutProfile(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		failJSON(c, 503, "database not configured")
		return
	}
	var body putProfileRequest
	if err := decodeStrict(c, &body, maxBodyJSON); err != nil {
		failJSON(c, 400, "invalid request")
		return
	}
	if body.DisplayName == nil || body.HomeCity == nil ||
		body.Interests == nil || body.AIContextConsent == nil {
		failJSON(c, 400, "missing field")
		return
	}
	displayName := strings.TrimSpace(*body.DisplayName)
	homeCity := strings.TrimSpace(*body.HomeCity)
	if displayName == "" || len(displayName) > 80 {
		failJSON(c, 400, "invalid display_name")
		return
	}
	if homeCity == "" || len(homeCity) > 120 {
		failJSON(c, 400, "invalid home_city")
		return
	}
	interests := *body.Interests
	if len(interests) > 10 {
		failJSON(c, 400, "invalid interests")
		return
	}
	clean := make([]string, 0, len(interests))
	for _, it := range interests {
		it = strings.TrimSpace(it)
		if it == "" || len(it) > 60 {
			failJSON(c, 400, "invalid interests")
			return
		}
		clean = append(clean, it)
	}
	p := Profile{
		UserID:           ident.ID,
		Email:            ident.Email,
		DisplayName:      displayName,
		HomeCity:         homeCity,
		Interests:        clean,
		AIContextConsent: *body.AIContextConsent,
	}
	if err := s.store.SaveProfile(c.Request.Context(), p); err != nil {
		failJSON(c, 503, "store unavailable")
		return
	}
	out, ok := s.profileFor(c, ident)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, out)
}

type contextItem struct {
	Kind       string `json:"kind"`
	Value      string `json:"value"`
	Provenance string `json:"provenance"`
	Confirmed  bool   `json:"confirmed"`
}

// handleContext returns confirmed/manual context with provenance only. Raw
// mail, message bodies and tokens are never exposed here.
func (s *Server) handleContext(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		failJSON(c, 503, "database not configured")
		return
	}
	items := []contextItem{}
	p, err := s.store.GetProfile(c.Request.Context(), ident.ID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		failJSON(c, 503, "store unavailable")
		return
	}
	if err == nil {
		if v := strings.TrimSpace(p.DisplayName); v != "" {
			items = append(items, contextItem{Kind: "display_name", Value: v, Provenance: "manual", Confirmed: true})
		}
		if v := strings.TrimSpace(p.HomeCity); v != "" {
			items = append(items, contextItem{Kind: "home_city", Value: v, Provenance: "manual", Confirmed: true})
		}
		if len(p.Interests) > 0 {
			items = append(items, contextItem{
				Kind: "interests", Value: strings.Join(p.Interests, ", "),
				Provenance: "manual", Confirmed: true,
			})
		}
	}
	if st, err := s.store.GetTokens(c.Request.Context(), ident.ID); err == nil && len(st.Scopes) > 0 {
		items = append(items, contextItem{
			Kind: "google_connection", Value: strings.Join(st.Scopes, " "),
			Provenance: "google_oauth", Confirmed: true,
		})
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

var toolNamePattern = regexp.MustCompile(`^[a-z][a-z0-9_]{0,63}$`)

type toolsCallResponse struct {
	Name       string   `json:"name"`
	Status     string   `json:"status"`
	Result     any      `json:"result,omitempty"`
	Error      string   `json:"error,omitempty"`
	Provenance []string `json:"provenance"`
}

// handleToolsCall executes one bounded read tool from the registry that is
// identical to the MCP endpoint and the DeepSeek loop.
func (s *Server) handleToolsCall(c *gin.Context) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		failJSON(c, 503, "database not configured")
		return
	}
	var body struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := decodeStrict(c, &body, maxBodyJSON); err != nil {
		failJSON(c, 400, "invalid request")
		return
	}
	if !toolNamePattern.MatchString(body.Name) {
		failJSON(c, 400, "invalid tool name")
		return
	}

	release, err := s.limiter.Acquire(ident.ID)
	if err != nil {
		c.Header("Retry-After", "60")
		failJSON(c, 429, "rate limit exceeded")
		return
	}
	defer release()

	result, err := s.ExecuteTool(c.Request.Context(), ident, body.Name, body.Arguments, false)
	if err != nil {
		failJSON(c, 400, "invalid arguments")
		return
	}
	resp := toolsCallResponse{
		Name:       body.Name,
		Status:     result.Status,
		Result:     result.Data,
		Error:      result.Error,
		Provenance: result.Provenance,
	}
	if resp.Provenance == nil {
		resp.Provenance = []string{}
	}
	c.JSON(http.StatusOK, resp)
}

// decryptTokens turns stored AES-GCM ciphertext back into an in-memory token
// set. Ciphertext is AAD-bound to the owner and purpose, so values swapped
// across users or across the access/refresh slots fail to open. Failures
// never leak key or ciphertext details.
func (s *Server) decryptTokens(userID string, st StoredTokens) (TokenSet, error) {
	if s.crypto == nil {
		return TokenSet{}, ErrDecrypt
	}
	access, err := s.crypto.OpenToken(userID, purposeAccess, st.AccessEnc)
	if err != nil {
		return TokenSet{}, ErrDecrypt
	}
	refresh := ""
	if len(st.RefreshEnc) > 0 {
		b, err := s.crypto.OpenToken(userID, purposeRefresh, st.RefreshEnc)
		if err != nil {
			return TokenSet{}, ErrDecrypt
		}
		refresh = string(b)
	}
	return TokenSet{
		AccessToken:  string(access),
		RefreshToken: refresh,
		TokenType:    st.TokenType,
		Scopes:       st.Scopes,
		GoogleEmail:  st.GoogleEmail,
		Expiry:       st.ExpiresAt,
	}, nil
}
