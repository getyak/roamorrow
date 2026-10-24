package harness

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func supabaseStub(t *testing.T, handler http.HandlerFunc) (*httptest.Server, *SupabaseVerifier) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return srv, NewSupabaseVerifier(srv.URL, "anon-key")
}

func TestSupabaseVerifierAcceptsVerifiedUser(t *testing.T) {
	_, v := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/v1/user" || r.Method != http.MethodGet {
			t.Errorf("unexpected upstream call %s %s", r.Method, r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer good-jwt" {
			t.Errorf("unexpected authorization header")
		}
		json.NewEncoder(w).Encode(map[string]any{
			"id": "user-1", "email": "a@example.test",
			"email_confirmed_at": "2026-01-01T00:00:00Z",
			"identities":         []map[string]string{{"provider": "email"}},
		})
	})
	id, err := v.Verify(context.Background(), "good-jwt")
	if err != nil {
		t.Fatal(err)
	}
	if id.ID != "user-1" || id.Email != "a@example.test" {
		t.Fatalf("unexpected identity %+v", id)
	}
}

func TestSupabaseVerifierRejectsInvalidToken(t *testing.T) {
	_, v := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"message":"invalid JWT"}`))
	})
	if _, err := v.Verify(context.Background(), "bad-jwt"); err == nil {
		t.Fatal("invalid token must be rejected")
	}
	if _, err := v.Verify(context.Background(), "   "); err == nil {
		t.Fatal("blank token must be rejected")
	}
}

func TestSupabaseVerifierRejectsUnverifiedAndAnonymous(t *testing.T) {
	cases := []struct {
		name string
		user map[string]any
	}{
		{"unverified email", map[string]any{
			"id": "u", "email": "a@example.test", "email_confirmed_at": "",
			"identities": []map[string]string{{"provider": "email"}},
		}},
		{"anonymous flag", map[string]any{
			"id": "u", "email": "a@example.test", "email_confirmed_at": "2026-01-01T00:00:00Z",
			"is_anonymous": true,
			"identities":   []map[string]string{{"provider": "email"}},
		}},
		{"anonymous identities only", map[string]any{
			"id": "u", "email": "", "email_confirmed_at": "",
			"identities": []map[string]string{},
		}},
		{"missing id", map[string]any{
			"id": "", "email": "a@example.test", "email_confirmed_at": "2026-01-01T00:00:00Z",
			"identities": []map[string]string{{"provider": "email"}},
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, v := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
				json.NewEncoder(w).Encode(tc.user)
			})
			if _, err := v.Verify(context.Background(), "jwt"); err == nil {
				t.Fatalf("%s must be rejected", tc.name)
			}
		})
	}
}

// TestSupabaseVerifierNeverFollowsRedirects proves the token-bearing client
// cannot be redirected into leaking the bearer token to another host.
func TestSupabaseVerifierNeverFollowsRedirects(t *testing.T) {
	var leaked atomic.Bool
	second := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "" {
			leaked.Store(true)
		}
		w.Write([]byte(`{"id":"evil","email":"e@e.e","email_confirmed_at":"2026-01-01T00:00:00Z","identities":[{"provider":"email"}]}`))
	}))
	defer second.Close()

	_, v := supabaseStub(t, func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, second.URL+"/steal", http.StatusFound)
	})
	if _, err := v.Verify(context.Background(), "jwt-secret"); err == nil {
		t.Fatal("redirected auth must fail, not succeed")
	}
	if leaked.Load() {
		t.Fatal("bearer token leaked to redirect target")
	}
}

func TestAuthMiddlewareEnforcesBearer(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	req := httptest.NewRequest(http.MethodGet, "/v1/harness/profile", nil)
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("missing auth must 401, got %d", w.Code)
	}

	req = httptest.NewRequest(http.MethodGet, "/v1/harness/profile", nil)
	req.Header.Set("Authorization", "Bearer unknown")
	w = httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("unknown token must 401, got %d", w.Code)
	}

	req = httptest.NewRequest(http.MethodGet, "/v1/harness/profile", nil)
	req.Header.Set("Authorization", "Bearer tok-a")
	w = httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("valid token must 200, got %d", w.Code)
	}
}

func TestAuthMiddlewareMissingConfigIs503(t *testing.T) {
	h := newTestHarness(t)
	h.srv.verifier = NewSupabaseVerifier("", "")
	req := httptest.NewRequest(http.MethodGet, "/v1/harness/profile", nil)
	req.Header.Set("Authorization", "Bearer anything")
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("unconfigured auth must 503, got %d", w.Code)
	}
}

// TestSanitizedLoggingKeepsCodesOutOfLogs runs the OAuth callback (which
// carries ?code= and ?state=) and asserts the access log never contains the
// query string or credential values.
func TestSanitizedLoggingKeepsCodesOutOfLogs(t *testing.T) {
	h := newTestHarness(t)
	req := httptest.NewRequest(http.MethodGet,
		"/v1/harness/google/callback?code=VERY-SECRET-CODE&state=VERY-SECRET-STATE-VALUE-XXXXX&error=", nil)
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)

	logs := h.logs.String()
	if strings.Contains(logs, "VERY-SECRET-CODE") || strings.Contains(logs, "VERY-SECRET-STATE") {
		t.Fatalf("oauth credential leaked into logs: %q", logs)
	}
	if strings.Contains(logs, "code=") || strings.Contains(logs, "?") {
		t.Fatalf("query string leaked into logs: %q", logs)
	}
	if !strings.Contains(logs, "/v1/harness/google/callback") {
		t.Fatalf("expected path in logs, got %q", logs)
	}
}

func TestNoRedirectClientAborts(t *testing.T) {
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("redirect target must not be reached")
	}))
	defer target.Close()
	redirector := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, target.URL, http.StatusFound)
	}))
	defer redirector.Close()

	client := noRedirectClient(2 * time.Second)
	if _, err := client.Get(redirector.URL); err == nil {
		t.Fatal("redirect must abort the request")
	}
}

// B07: with Supabase missing, NewServer leaves the verifier as a true nil
// interface. Protected routes must answer a sanitized 503 without panicking —
// proven on an engine WITHOUT a recovery wrapper and without installing any
// verifier in the test.
func TestAuthMiddlewareNilVerifierNoPanic(t *testing.T) {
	gin.SetMode(gin.TestMode)
	srv := NewServer(Config{}, newMemStore())
	engine := gin.New() // deliberately no recovery: a panic fails the test
	srv.Register(engine)

	req := httptest.NewRequest(http.MethodGet, "/v1/harness/profile", nil)
	req.Header.Set("Authorization", "Bearer some-token")
	w := httptest.NewRecorder()
	engine.ServeHTTP(w, req) // must not panic
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("nil verifier must 503, got %d: %s", w.Code, w.Body.String())
	}

	req = httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"ping"}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer some-token")
	w = httptest.NewRecorder()
	engine.ServeHTTP(w, req) // must not panic
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("nil verifier on /mcp must 503, got %d: %s", w.Code, w.Body.String())
	}
}
