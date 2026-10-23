package harness

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func doJSON(t *testing.T, h *testHarness, method, path, token string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	return w
}

func decodeBody(t *testing.T, w *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &m); err != nil {
		t.Fatalf("decode %q: %v", w.Body.String(), err)
	}
	return m
}

func TestCapabilitiesHasExactBooleans(t *testing.T) {
	h := newTestHarness(t)
	w := doJSON(t, h, http.MethodGet, "/v1/harness/capabilities", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("got %d", w.Code)
	}
	m := decodeBody(t, w)
	for _, k := range []string{"email_auth", "google", "deepseek", "database"} {
		if _, ok := m[k].(bool); !ok {
			t.Fatalf("missing boolean %q in %v", k, m)
		}
	}
	if len(m) != 4 {
		t.Fatalf("capabilities must contain exactly the four fields, got %v", m)
	}
	if m["database"] != true {
		t.Fatal("mem-store server should report database=true")
	}
}

func TestCapabilitiesMissingConfig(t *testing.T) {
	h := newTestHarness(t)
	srv := NewServer(Config{TokenKey: testKey}, h.store)
	engine := gin.New()
	srv.Register(engine)
	req := httptest.NewRequest(http.MethodGet, "/v1/harness/capabilities", nil)
	w := httptest.NewRecorder()
	engine.ServeHTTP(w, req)
	m := decodeBody(t, w)
	if m["email_auth"] != false || m["google"] != false || m["deepseek"] != false {
		t.Fatalf("missing config must disable capabilities, got %v", m)
	}
}

func TestProfileRoundTrip(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	w := doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{"food", "hiking"}, "ai_context_consent": true,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("put got %d: %s", w.Code, w.Body.String())
	}
	m := decodeBody(t, w)
	if m["display_name"] != "Ada" || m["email"] != "a@example.test" || m["user_id"] != "user-a" {
		t.Fatalf("unexpected profile %v", m)
	}

	w = doJSON(t, h, http.MethodGet, "/v1/harness/profile", "tok-a", nil)
	m = decodeBody(t, w)
	if m["ai_context_consent"] != true {
		t.Fatalf("consent not persisted: %v", m)
	}
	google := m["google"].(map[string]any)
	if google["connected"] != false {
		t.Fatalf("google must be disconnected: %v", google)
	}
}

func TestPutProfileRejectsSpoofedIdentityAndBadInput(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	// user_id / email in the body must be rejected outright (unknown fields).
	w := doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Eve", "home_city": "Oslo", "interests": []string{},
		"ai_context_consent": true, "user_id": "user-b", "email": "eve@x.test",
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("spoofed identity fields must 400, got %d", w.Code)
	}

	bad := []map[string]any{
		{"display_name": "", "home_city": "Oslo", "interests": []string{}, "ai_context_consent": true},
		{"display_name": "  ", "home_city": "Oslo", "interests": []string{}, "ai_context_consent": true},
		{"display_name": "A", "home_city": "", "interests": []string{}, "ai_context_consent": true},
		{"display_name": "A", "home_city": "Oslo", "interests": []string{""}, "ai_context_consent": true},
		{"display_name": "A", "home_city": "Oslo", "ai_context_consent": true},
		{"display_name": "A", "home_city": "Oslo", "interests": []string{"x", "y"}, "ai_context_consent": "yes"},
	}
	for i, body := range bad {
		w := doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", body)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("case %d must 400, got %d: %s", i, w.Code, w.Body.String())
		}
	}

	// oversized interests item
	long := ""
	for i := 0; i < 61; i++ {
		long += "x"
	}
	w = doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "A", "home_city": "Oslo", "interests": []string{long}, "ai_context_consent": true,
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("oversized interest must 400, got %d", w.Code)
	}

	// malformed JSON must fail
	req := httptest.NewRequest(http.MethodPut, "/v1/harness/profile", bytes.NewReader([]byte("{not json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer tok-a")
	w2 := httptest.NewRecorder()
	h.engine.ServeHTTP(w2, req)
	if w2.Code != http.StatusBadRequest {
		t.Fatalf("malformed JSON must 400, got %d", w2.Code)
	}
}

func TestOwnerIsolationAcrossUsers(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.auth("tok-b", "user-b", "b@example.test")

	doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Alice", "home_city": "Berlin",
		"interests": []string{"museums"}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})

	// User B sees nothing of user A.
	w := doJSON(t, h, http.MethodGet, "/v1/harness/profile", "tok-b", nil)
	m := decodeBody(t, w)
	if m["display_name"] != "" {
		t.Fatalf("user B must not see user A profile: %v", m)
	}
	if m["email"] != "b@example.test" {
		t.Fatalf("email must come from verified auth: %v", m)
	}
	if m["google"].(map[string]any)["connected"] != false {
		t.Fatal("user B must not see user A google link")
	}

	// User B cannot delete user A's google tokens.
	w = doJSON(t, h, http.MethodDelete, "/v1/harness/google", "tok-b", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("delete got %d", w.Code)
	}
	if _, err := h.store.GetTokens(nil, "user-a"); err != nil {
		t.Fatal("user A tokens must survive user B disconnect")
	}
}

func TestContextItemsCarryProvenance(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, http.MethodPut, "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{"food"}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeGmailReadonly})

	w := doJSON(t, h, http.MethodGet, "/v1/harness/context", "tok-a", nil)
	m := decodeBody(t, w)
	raw := w.Body.String()
	if bytes.Contains(w.Body.Bytes(), []byte("access-token-value")) || bytes.Contains(w.Body.Bytes(), []byte("refresh-token-value")) {
		t.Fatalf("tokens leaked into context: %s", raw)
	}
	items, _ := m["items"].([]any)
	if len(items) != 4 {
		t.Fatalf("expected 4 context items, got %v", items)
	}
	for _, it := range items {
		item := it.(map[string]any)
		if item["provenance"] == "" || item["confirmed"] != true {
			t.Fatalf("every item needs provenance and confirmed: %v", item)
		}
	}
}

func TestToolsCallValidatesStrictly(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	// Unknown tool name.
	w := doJSON(t, h, http.MethodPost, "/v1/harness/tools/call", "tok-a", map[string]any{
		"name": "drop_all_tables", "arguments": map[string]any{},
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("unknown tool must 400, got %d", w.Code)
	}

	// Arguments cannot select another user / arbitrary fields.
	w = doJSON(t, h, http.MethodPost, "/v1/harness/tools/call", "tok-a", map[string]any{
		"name":      "get_traveler_profile",
		"arguments": map[string]any{"user_id": "user-b", "endpoint": "https://evil.test"},
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("unknown arguments must 400, got %d", w.Code)
	}

	// Blank / malformed name.
	w = doJSON(t, h, http.MethodPost, "/v1/harness/tools/call", "tok-a", map[string]any{
		"name": "   ", "arguments": map[string]any{},
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("blank tool name must 400, got %d", w.Code)
	}

	// Successful call returns only manual fields, never email.
	w = doJSON(t, h, http.MethodPost, "/v1/harness/tools/call", "tok-a", map[string]any{
		"name": "get_traveler_profile", "arguments": map[string]any{},
	})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d: %s", w.Code, w.Body.String())
	}
	m := decodeBody(t, w)
	if m["status"] != "ok" {
		t.Fatalf("unexpected status %v", m)
	}
	if bytes.Contains(w.Body.Bytes(), []byte("a@example.test")) {
		t.Fatal("email must never appear in tool output")
	}
}

// --- review regressions ---------------------------------------------------

// P2-6: REST bodies must be one complete JSON value. Trailing `]`/`}`, a
// second object, trailing garbage and oversized tails all fail.
func TestStrictJSONTrailingDataRejected(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	valid := `{"display_name":"A","home_city":"Oslo","interests":[],"ai_context_consent":true}`
	bodies := []string{
		valid + `]`,
		valid + `}`,
		valid + ` {"display_name":"B","home_city":"Oslo","interests":[],"ai_context_consent":true}`,
		valid + ` trailing`,
		valid + "\n\n\n tail",
	}
	for i, body := range bodies {
		req := httptest.NewRequest(http.MethodPut, "/v1/harness/profile", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer tok-a")
		w := httptest.NewRecorder()
		h.engine.ServeHTTP(w, req)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("body %d must 400, got %d: %s", i, w.Code, w.Body.String())
		}
	}

	// Oversized body — including a whitespace-padded tail — fails.
	req := httptest.NewRequest(http.MethodPut, "/v1/harness/profile",
		strings.NewReader(valid+strings.Repeat(" ", int(maxBodyJSON)+1024)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer tok-a")
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("oversized body must 400, got %d", w.Code)
	}
}

// P2-7: NewServer must never assign typed-nil clients to interfaces.
func TestNewServerNoTypedNilClients(t *testing.T) {
	srv := NewServer(Config{}, nil)
	if srv.verifier != nil {
		t.Fatalf("unconfigured verifier must be a true nil interface, got %#v", srv.verifier)
	}
	if srv.google != nil {
		t.Fatalf("unconfigured google must be a true nil interface, got %#v", srv.google)
	}
	if srv.deepseek != nil {
		t.Fatalf("unconfigured deepseek must be a true nil interface, got %#v", srv.deepseek)
	}
}

// P2-7: a real NewServer without DeepSeek config answers /chat with 503 —
// wired through the real Supabase verifier, no manual interface replacement.
func TestNewServerMissingDeepSeekIs503(t *testing.T) {
	stub, _ := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"id": "user-a", "email": "a@example.test",
			"email_confirmed_at": "2026-01-01T00:00:00Z",
			"identities":         []map[string]string{{"provider": "email"}},
		})
	})
	cfg := Config{
		SupabaseURL:     stub.URL,
		SupabaseAnonKey: "anon-key",
		TokenKey:        testKey,
		RatePerMin:      10, MaxConcurrentUser: 2, MaxConcurrentTotal: 4,
	}
	srv := NewServer(cfg, newMemStore())
	engine := newEngine(srv)

	req := httptest.NewRequest(http.MethodPost, "/v1/harness/chat",
		strings.NewReader(`{"message":"hi"}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer tok")
	w := httptest.NewRecorder()
	engine.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("unconfigured deepseek must 503, got %d: %s", w.Code, w.Body.String())
	}
}

// P2-7: a real NewServer with Google unconfigured and saved tokens returns a
// clear tool error via /tools/call instead of panicking.
func TestNewServerMissingGoogleWithSavedTokens(t *testing.T) {
	stub, _ := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"id": "user-a", "email": "a@example.test",
			"email_confirmed_at": "2026-01-01T00:00:00Z",
			"identities":         []map[string]string{{"provider": "email"}},
		})
	})
	store := newMemStore()
	cfg := Config{
		SupabaseURL: stub.URL, SupabaseAnonKey: "anon-key",
		TokenKey: testKey,
		// Google client id/secret/redirect intentionally absent.
		RatePerMin: 10, MaxConcurrentUser: 2, MaxConcurrentTotal: 4,
	}
	srv := NewServer(cfg, store)
	engine := newEngine(srv)

	c := srv.crypto
	access, err := c.SealToken("user-a", purposeAccess, []byte("access"))
	if err != nil {
		t.Fatal(err)
	}
	refresh, err := c.SealToken("user-a", purposeRefresh, []byte("refresh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := store.ReplaceConnection(context.Background(), "user-a", 0, StoredTokens{
		AccessEnc: access, RefreshEnc: refresh, TokenType: "Bearer",
		Scopes: []string{ScopeCalendarReadonly}, ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodPost, "/v1/harness/tools/call",
		strings.NewReader(`{"name":"list_calendar_events","arguments":{}}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer tok")
	w := httptest.NewRecorder()
	engine.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 tool result, got %d: %s", w.Code, w.Body.String())
	}
	m := decodeBody(t, w)
	if m["status"] != "error" || m["error"] != "google_not_configured" {
		t.Fatalf("expected google_not_configured, got %v", m)
	}
}
