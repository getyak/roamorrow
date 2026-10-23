package harness

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestGoogleStartReturnsPKCEURLAndExpiry(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	w := doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d: %s", w.Code, w.Body.String())
	}
	m := decodeBody(t, w)
	rawURL, _ := m["authorization_url"].(string)
	if rawURL == "" {
		t.Fatal("missing authorization_url")
	}
	if m["expires_at"] == "" {
		t.Fatal("missing expires_at")
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		t.Fatal(err)
	}
	q := u.Query()
	if q.Get("code_challenge") == "" || q.Get("code_challenge_method") != "S256" {
		t.Fatalf("PKCE missing in %v", q)
	}
	if !strings.Contains(q.Get("scope"), ScopeCalendarReadonly) ||
		!strings.Contains(q.Get("scope"), ScopeGmailReadonly) {
		t.Fatalf("requested scopes wrong: %q", q.Get("scope"))
	}
	if strings.Contains(q.Get("scope"), "gmail.send") || strings.Contains(q.Get("scope"), "mail.google.com") {
		t.Fatalf("write scope requested: %q", q.Get("scope"))
	}
	if q.Get("state") == "" {
		t.Fatal("state missing")
	}
}

func TestGoogleStartRequiresScopeSelection(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	for _, body := range []map[string]any{
		{"calendar": false, "mail": false},
		{"calendar": true},
		{},
		{"calendar": true, "mail": "true"},
	} {
		w := doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", body)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("body %v must 400, got %d", body, w.Code)
		}
	}
}

func TestGoogleStartMissingConfigIs503(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	srv := NewServer(Config{TokenKey: testKey}, h.store)
	srv.verifier = h.verify
	engine := newEngine(srv)
	req := httptest.NewRequest(http.MethodPost, "/v1/harness/google/start", strings.NewReader(`{"calendar":true,"mail":false}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer tok-a")
	w := httptest.NewRecorder()
	engine.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("unconfigured google must 503, got %d", w.Code)
	}
}

func TestGoogleCallbackHappyPathStoresEncryptedTokens(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.google.email = "traveler@example.test"

	// Start flow to create state + PKCE verifier.
	w := doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	})
	start := decodeBody(t, w)
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)

	if rec.Code != http.StatusFound {
		t.Fatalf("callback must redirect, got %d", rec.Code)
	}
	loc := rec.Header().Get("Location")
	if loc != callbackRedirectBase+callbackConnected {
		t.Fatalf("unexpected redirect %q", loc)
	}
	// No tokens or personal data in the redirect URL.
	for _, secret := range []string{"good-code", "access-", "refresh-", "traveler@example.test", state} {
		if strings.Contains(loc, secret) {
			t.Fatalf("redirect leaks %q: %q", secret, loc)
		}
	}

	st, err := h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(st.AccessEnc), "access-good-code") ||
		strings.Contains(string(st.RefreshEnc), "refresh-good-code") {
		t.Fatal("tokens stored in plaintext")
	}
	tok, err := h.srv.decryptTokens("user-a", st)
	if err != nil {
		t.Fatal(err)
	}
	if tok.AccessToken != "access-good-code" || tok.RefreshToken != "refresh-good-code" {
		t.Fatal("token round trip mismatch")
	}
	if st.GoogleEmail != "traveler@example.test" {
		t.Fatalf("google email not stored: %q", st.GoogleEmail)
	}

	// The state owner is the verified auth user, not any query value.
	if got := st.GoogleEmail; got == "" {
		t.Fatal("expected google email")
	}
}

func TestGoogleCallbackReplayExpiryAndBadState(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	callback := func(q string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, "/v1/harness/google/callback?"+q, nil)
		rec := httptest.NewRecorder()
		h.engine.ServeHTTP(rec, req)
		return rec
	}

	// Unknown / malformed / missing state fails closed.
	rec := callback("code=good-code&state=not-a-valid-state")
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("bad state must error redirect, got %q", rec.Header().Get("Location"))
	}
	rec = callback("code=good-code")
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("missing state must error redirect, got %q", rec.Header().Get("Location"))
	}

	// Denial consumes the valid state exactly once: the denial itself gets an
	// error redirect and any replay of the same state fails closed.
	rec = callback("error=access_denied&state=" + url.QueryEscape(state))
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("denial must error redirect, got %q", rec.Header().Get("Location"))
	}
	rec = callback("code=good-code&state=" + url.QueryEscape(state))
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("state used for denial must not be reusable, got %q", rec.Header().Get("Location"))
	}

	// A fresh state's first legitimate use succeeds; replay fails.
	start = decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	}))
	u, _ = url.Parse(start["authorization_url"].(string))
	state = u.Query().Get("state")
	rec = callback("code=good-code&state=" + url.QueryEscape(state))
	if rec.Header().Get("Location") != callbackRedirectBase+callbackConnected {
		t.Fatalf("first use must connect, got %q", rec.Header().Get("Location"))
	}
	rec = callback("code=good-code&state=" + url.QueryEscape(state))
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("replay must error redirect, got %q", rec.Header().Get("Location"))
	}
}

func TestGoogleCallbackExpiredState(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": false,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	// Advance the server clock beyond stateTTL.
	fixed := time.Now().Add(stateTTL + time.Minute)
	h.srv.now = func() time.Time { return fixed }

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("expired state must error redirect, got %q", rec.Header().Get("Location"))
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("expired state must not persist tokens")
	}
}

func TestGoogleCallbackNoConfigIsErrorRedirect(t *testing.T) {
	h := newTestHarness(t)
	srv := NewServer(Config{}, h.store)
	engine := newEngine(srv)
	req := httptest.NewRequest(http.MethodGet, "/v1/harness/google/callback?code=x&state=abcdefghijabcdefghij", nil)
	rec := httptest.NewRecorder()
	engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("unconfigured must error redirect, got %q", rec.Header().Get("Location"))
	}
}

func TestGoogleDisconnectErasesAndRevokes(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})
	h.google.revokeOK = true

	w := doJSON(t, h, http.MethodDelete, "/v1/harness/google", "tok-a", nil)
	m := decodeBody(t, w)
	if m["disconnected"] != true {
		t.Fatalf("expected disconnected: %v", m)
	}
	if m["provider_revocation_confirmed"] != true {
		t.Fatalf("honest revocation flag expected true: %v", m)
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("local tokens must be erased")
	}
	if h.google.revokeCalls != 1 {
		t.Fatalf("expected 1 revoke call, got %d", h.google.revokeCalls)
	}

	// Second call: nothing connected -> honest false flag.
	w = doJSON(t, h, http.MethodDelete, "/v1/harness/google", "tok-a", nil)
	m = decodeBody(t, w)
	if m["disconnected"] != true || m["provider_revocation_confirmed"] != false {
		t.Fatalf("expected honest no-op result, got %v", m)
	}
}

func TestGoogleDisconnectProviderFailureIsHonest(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})
	h.google.revokeOK = false

	w := doJSON(t, h, http.MethodDelete, "/v1/harness/google", "tok-a", nil)
	m := decodeBody(t, w)
	if m["provider_revocation_confirmed"] != false {
		t.Fatalf("failed revocation must report false: %v", m)
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("local tokens must be erased even when revocation fails")
	}
}

func newEngine(srv *Server) *gin.Engine {
	engine := gin.New()
	srv.Register(engine)
	return engine
}

// --- review regressions ---------------------------------------------------

// P1-1: include_granted_scopes=true lets Google return historic grants. A
// calendar-only state must never enable mail.
func TestGoogleCallbackCalendarOnlyStateNeverEnablesMail(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	// Google returns BOTH calendar and gmail (historic grant combined).
	h.google.exchange = func(code, verifier string) (TokenSet, error) {
		return TokenSet{
			AccessToken: "a", RefreshToken: "r", TokenType: "Bearer",
			Expiry: time.Now().Add(time.Hour),
			Scopes: []string{"openid", "email", ScopeCalendarReadonly, ScopeGmailReadonly},
		}, nil
	}

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": false,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackConnected {
		t.Fatalf("expected connected, got %q", rec.Header().Get("Location"))
	}

	st, err := h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	for _, sc := range st.Scopes {
		if sc == ScopeGmailReadonly {
			t.Fatalf("mail scope must never be enabled by a calendar-only state: %v", st.Scopes)
		}
	}
	if !contains(st.Scopes, ScopeCalendarReadonly) {
		t.Fatalf("calendar scope expected: %v", st.Scopes)
	}

	// The mail tool must stay denied for this connection.
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	res, _ := execTool(t, h, Identity{ID: "user-a"}, "search_travel_mail", "{}", false)
	if res.Error != "missing_scope" {
		t.Fatalf("mail tool must be denied, got %+v", res)
	}
}

// P1-2: disconnect cancels pending states; a later callback with the old
// state must fail closed and never create a connection.
func TestGoogleDisconnectCancelsPendingStates(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	w := doJSON(t, h, http.MethodDelete, "/v1/harness/google", "tok-a", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("disconnect got %d", w.Code)
	}

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("cancelled state must error redirect, got %q", rec.Header().Get("Location"))
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("cancelled state must not create a connection")
	}
}

// P1-2: an exchange already in flight when the user disconnects must lose the
// generation compare-and-commit and cannot restore the connection.
func TestGoogleCallbackBlockedByDisconnectDuringExchange(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": true,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	// The user disconnects while Google's token exchange is on the wire.
	h.google.exchange = func(code, verifier string) (TokenSet, error) {
		if _, err := h.store.Disconnect(context.Background(), "user-a"); err != nil {
			t.Fatal(err)
		}
		return TokenSet{
			AccessToken: "late-access", RefreshToken: "late-refresh", TokenType: "Bearer",
			Expiry: time.Now().Add(time.Hour),
			Scopes: []string{ScopeCalendarReadonly, ScopeGmailReadonly},
		}, nil
	}

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("in-flight exchange after disconnect must fail, got %q", rec.Header().Get("Location"))
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("in-flight exchange must not restore a disconnected account")
	}
}

// P1-2: even with nothing connected, disconnect bumps the generation so a
// state started earlier can never commit afterwards.
func TestGoogleDisconnectWithoutTokensStillBlocksOldState(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
		"calendar": true, "mail": false,
	}))
	u, _ := url.Parse(start["authorization_url"].(string))
	state := u.Query().Get("state")

	// Disconnect before any tokens existed (cancel + generation bump).
	if _, err := h.store.Disconnect(context.Background(), "user-a"); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("old state after disconnect must fail, got %q", rec.Header().Get("Location"))
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("no tokens may be committed after disconnect")
	}
}

// B01: an older broad-scope refresh that started before a narrow/new-account
// OAuth callback must fail its CAS when it returns — the new connection (new
// scopes, new Google identity) stays authoritative and no stale data is served.
func TestOldRefreshCannotOverwriteNewConnection(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})

	// Old connection: broad scopes, old Google identity, expired access.
	access, err := h.srv.crypto.SealToken("user-a", purposeAccess, []byte("old-access"))
	if err != nil {
		t.Fatal(err)
	}
	refreshEnc, err := h.srv.crypto.SealToken("user-a", purposeRefresh, []byte("old-refresh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := h.store.ReplaceConnection(context.Background(), "user-a", 0, StoredTokens{
		AccessEnc: access, RefreshEnc: refreshEnc, TokenType: "Bearer",
		Scopes:      []string{"openid", "email", ScopeCalendarReadonly, ScopeGmailReadonly},
		GoogleEmail: "old@example.test", ExpiresAt: time.Now().Add(-time.Hour),
	}); err != nil {
		t.Fatal(err)
	}

	// While the old refresh is on the wire, a NEW calendar-only OAuth flow for
	// a different Google account completes. The old refresh returns afterwards.
	h.google.email = "new@example.test"
	h.google.refreshFn = func(tok TokenSet) (TokenSet, error) {
		start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
			"calendar": true, "mail": false,
		}))
		u, _ := url.Parse(start["authorization_url"].(string))
		state := u.Query().Get("state")
		h.google.exchange = func(code, verifier string) (TokenSet, error) {
			return TokenSet{
				AccessToken: "new-access", RefreshToken: "new-refresh", TokenType: "Bearer",
				Expiry: time.Now().Add(time.Hour),
				// Google returns a historic gmail grant too: must be trimmed.
				Scopes: []string{"openid", "email", ScopeCalendarReadonly, ScopeGmailReadonly},
			}, nil
		}
		req := httptest.NewRequest(http.MethodGet,
			"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(state), nil)
		rec := httptest.NewRecorder()
		h.engine.ServeHTTP(rec, req)
		if rec.Header().Get("Location") != callbackRedirectBase+callbackConnected {
			t.Fatalf("new narrow callback must win, got %q", rec.Header().Get("Location"))
		}
		// The OLD refresh result (broad scopes, old identity) comes back late.
		return TokenSet{
			AccessToken: "old-refreshed-access", RefreshToken: "old-rotated-refresh",
			TokenType: "Bearer", Expiry: time.Now().Add(time.Hour),
			Scopes: []string{"openid", "email", ScopeCalendarReadonly, ScopeGmailReadonly},
		}, nil
	}

	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "connection_changed" {
		t.Fatalf("stale refresh must be refused, got %+v", res)
	}
	if res.Data != nil {
		t.Fatalf("stale refresh must not serve data: %+v", res)
	}

	st, err := h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	tok, err := h.srv.decryptTokens("user-a", st)
	if err != nil {
		t.Fatal(err)
	}
	if tok.AccessToken != "new-access" || tok.RefreshToken != "new-refresh" {
		t.Fatalf("old refresh overwrote the new connection: %+v", tok)
	}
	if st.GoogleEmail != "new@example.test" {
		t.Fatalf("old Google identity returned: %q", st.GoogleEmail)
	}
	for _, sc := range st.Scopes {
		if sc == ScopeGmailReadonly {
			t.Fatalf("old broad scopes returned: %v", st.Scopes)
		}
	}
	if !contains(st.Scopes, ScopeCalendarReadonly) {
		t.Fatalf("new narrow scope missing: %v", st.Scopes)
	}

	// A fresh call now serves the new connection (calendar only).
	h.google.events = []CalendarEvent{{ID: "1", Summary: "Train", Provenance: "google_calendar"}}
	res, _ = execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "ok" {
		t.Fatalf("new connection must work on retry, got %+v", res)
	}
	res, _ = execTool(t, h, id, "search_travel_mail", "{}", false)
	if res.Error != "missing_scope" {
		t.Fatalf("mail must stay denied on the new connection, got %+v", res)
	}
}

// B01: two callbacks racing the same epoch — exactly one wins; the stale
// callback is rejected and the pending loser state is cancelled.
func TestConcurrentOAuthCallbacksOneWinner(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	mkState := func() string {
		start := decodeBody(t, doJSON(t, h, http.MethodPost, "/v1/harness/google/start", "tok-a", map[string]any{
			"calendar": true, "mail": true,
		}))
		u, _ := url.Parse(start["authorization_url"].(string))
		return u.Query().Get("state")
	}
	stateA, stateB, stateC := mkState(), mkState(), mkState()

	mkTokens := func(access, email string) StoredTokens {
		a, err := h.srv.crypto.SealToken("user-a", purposeAccess, []byte(access))
		if err != nil {
			t.Fatal(err)
		}
		r, err := h.srv.crypto.SealToken("user-a", purposeRefresh, []byte("r-"+access))
		if err != nil {
			t.Fatal(err)
		}
		return StoredTokens{
			AccessEnc: a, RefreshEnc: r, TokenType: "Bearer",
			Scopes: []string{"openid", "email", ScopeCalendarReadonly}, GoogleEmail: email,
			ExpiresAt: time.Now().Add(time.Hour),
		}
	}

	// Both callbacks consume their states before either persists (in flight).
	recA, err := h.store.ConsumeState(context.Background(), stateA, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	recB, err := h.store.ConsumeState(context.Background(), stateB, time.Now())
	if err != nil {
		t.Fatal(err)
	}

	// Exactly one winner.
	if err := h.store.ReplaceConnection(context.Background(), "user-a", recA.Generation, mkTokens("access-a", "a@example.test")); err != nil {
		t.Fatalf("first callback must win: %v", err)
	}
	err = h.store.ReplaceConnection(context.Background(), "user-a", recB.Generation, mkTokens("access-b", "b@example.test"))
	if !errors.Is(err, ErrStaleConnection) {
		t.Fatalf("stale callback must be rejected, got %v", err)
	}

	st, err := h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	if st.GoogleEmail != "a@example.test" {
		t.Fatalf("stale callback overwrote the winner: %q", st.GoogleEmail)
	}

	// A pending third state started earlier is cancelled by the winner and
	// its HTTP callback fails closed.
	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=good-code&state="+url.QueryEscape(stateC), nil)
	rec := httptest.NewRecorder()
	h.engine.ServeHTTP(rec, req)
	if rec.Header().Get("Location") != callbackRedirectBase+callbackError {
		t.Fatalf("cancelled stale state must error, got %q", rec.Header().Get("Location"))
	}
	st, err = h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	if st.GoogleEmail != "a@example.test" {
		t.Fatalf("winner connection must survive: %q", st.GoogleEmail)
	}
}
