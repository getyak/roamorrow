package harness

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const mcpOrigin = "https://smile-m4-minimac-mini.tail25e61f.ts.net:18443"

func doMCP(t *testing.T, h *testHarness, token, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	return w
}

func rpcResult(t *testing.T, w *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	m := decodeBody(t, w)
	if e, ok := m["error"]; ok {
		t.Fatalf("unexpected rpc error: %v", e)
	}
	res, ok := m["result"].(map[string]any)
	if !ok {
		t.Fatalf("missing result: %v", m)
	}
	return res
}

func rpcErrorCode(t *testing.T, w *httptest.ResponseRecorder) float64 {
	t.Helper()
	m := decodeBody(t, w)
	e, ok := m["error"].(map[string]any)
	if !ok {
		t.Fatalf("expected rpc error, got %v", m)
	}
	return e["code"].(float64)
}

const initMsg = `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}`

func TestMCPInitializeLifecycle(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	w := doMCP(t, h, "tok-a", initMsg, map[string]string{"Origin": mcpOrigin})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d: %s", w.Code, w.Body.String())
	}
	res := rpcResult(t, w)
	if res["protocolVersion"] != "2025-11-25" {
		t.Fatalf("expected protocolVersion 2025-11-25, got %v", res["protocolVersion"])
	}
	info := res["serverInfo"].(map[string]any)
	if info["name"] != "roamorrow-harness" {
		t.Fatalf("unexpected serverInfo %v", info)
	}
	caps := res["capabilities"].(map[string]any)
	if _, ok := caps["tools"].(map[string]any); !ok {
		t.Fatalf("expected tools capability, got %v", caps)
	}
}

func TestMCPInitializeValidation(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	cases := []string{
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}`,
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"","clientInfo":{"name":"t","version":"1"}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}`,
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"","version":"1"}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"t","version":"1"},"capabilities":"nope"}}`,
	}
	for _, body := range cases {
		w := doMCP(t, h, "tok-a", body, nil)
		if code := rpcErrorCode(t, w); code != rpcInvalidParams {
			t.Fatalf("body %s: expected -32602, got %v", body, code)
		}
	}
}

func TestMCPPingAndToolsList(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	w := doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":"p","method":"ping","params":{}}`, nil)
	res := rpcResult(t, w)
	if len(res) != 0 {
		t.Fatalf("ping result must be empty, got %v", res)
	}

	w = doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":"l","method":"tools/list"}`, nil)
	res = rpcResult(t, w)
	tools, _ := res["tools"].([]any)
	if len(tools) != 3 {
		t.Fatalf("expected exactly 3 read tools, got %d", len(tools))
	}
	seen := map[string]bool{}
	for _, tv := range tools {
		tool := tv.(map[string]any)
		seen[tool["name"].(string)] = true
		ann := tool["annotations"].(map[string]any)
		if ann["readOnlyHint"] != true || ann["destructiveHint"] != false {
			t.Fatalf("read-only annotation wrong: %v", ann)
		}
		if _, ok := tool["inputSchema"].(map[string]any); !ok {
			t.Fatalf("missing inputSchema: %v", tool)
		}
	}
	for _, n := range []string{"get_traveler_profile", "list_calendar_events", "search_travel_mail"} {
		if !seen[n] {
			t.Fatalf("missing tool %s", n)
		}
	}

	// cursor is unsupported and must fail rather than silently misbehave.
	w = doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":"l","method":"tools/list","params":{"cursor":"x"}}`, nil)
	if code := rpcErrorCode(t, w); code != rpcInvalidParams {
		t.Fatalf("expected -32602 for cursor, got %v", code)
	}
}

func TestMCPToolsCallExecution(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{"food"}, "ai_context_consent": true,
	})

	w := doMCP(t, h, "tok-a",
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_traveler_profile","arguments":{}}}`, nil)
	res := rpcResult(t, w)
	if res["isError"] != false {
		t.Fatalf("expected success, got %v", res)
	}
	if strings.Contains(w.Body.String(), "a@example.test") {
		t.Fatal("email leaked via MCP tool result")
	}

	// Google tool without connection: clear error result, never empty success.
	w = doMCP(t, h, "tok-a",
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_calendar_events","arguments":{}}}`, nil)
	res = rpcResult(t, w)
	if res["isError"] != true {
		t.Fatalf("expected isError result, got %v", res)
	}
	if !strings.Contains(w.Body.String(), "google_not_connected") {
		t.Fatalf("expected clear error code, got %s", w.Body.String())
	}
}

func TestMCPToolsCallStrictArguments(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	cases := []string{
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"nope","arguments":{}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"","arguments":{}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_traveler_profile","arguments":{"user_id":"user-b"}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_travel_mail","arguments":{"query":"in:spam"}}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_traveler_profile","endpoint":"x"}}`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_calendar_events","arguments":{"days":365}}}`,
	}
	for _, body := range cases {
		w := doMCP(t, h, "tok-a", body, nil)
		if code := rpcErrorCode(t, w); code != rpcInvalidParams {
			t.Fatalf("body %s: expected -32602, got %v", body, code)
		}
	}
}

func TestMCPProtocolErrors(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	// Parse error.
	w := doMCP(t, h, "tok-a", `{not json`, nil)
	if code := rpcErrorCode(t, w); code != rpcParseError {
		t.Fatalf("expected -32700, got %v", code)
	}
	// Batch is invalid in the 2025-11-25 revision.
	w = doMCP(t, h, "tok-a", `[{"jsonrpc":"2.0","id":1,"method":"ping"}]`, nil)
	if code := rpcErrorCode(t, w); code != rpcInvalidRequest {
		t.Fatalf("batch must be -32600, got %v", code)
	}
	// Wrong jsonrpc version.
	w = doMCP(t, h, "tok-a", `{"jsonrpc":"1.0","id":1,"method":"ping"}`, nil)
	if code := rpcErrorCode(t, w); code != rpcInvalidRequest {
		t.Fatalf("bad jsonrpc must be -32600, got %v", code)
	}
	// Bad id type.
	w = doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":{"x":1},"method":"ping"}`, nil)
	if code := rpcErrorCode(t, w); code != rpcInvalidRequest {
		t.Fatalf("bad id must be -32600, got %v", code)
	}
	// Missing method.
	w = doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":1}`, nil)
	if code := rpcErrorCode(t, w); code != rpcInvalidRequest {
		t.Fatalf("missing method must be -32600, got %v", code)
	}
	// Unknown method.
	w = doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","id":1,"method":"resources/list"}`, nil)
	if code := rpcErrorCode(t, w); code != rpcMethodNotFound {
		t.Fatalf("unknown method must be -32601, got %v", code)
	}
}

func TestMCPNotificationsAcceptedWith202(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	for _, body := range []string{
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":1}}`,
		`{"jsonrpc":"2.0","method":"unknown/notification"}`,
	} {
		w := doMCP(t, h, "tok-a", body, nil)
		if w.Code != http.StatusAccepted {
			t.Fatalf("notification %s must 202, got %d", body, w.Code)
		}
		if w.Body.Len() != 0 {
			t.Fatalf("notification response must be empty, got %q", w.Body.String())
		}
	}
}

func TestMCPGetReturns405(t *testing.T) {
	h := newTestHarness(t)
	req := httptest.NewRequest(http.MethodGet, "/mcp", nil)
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET /mcp must 405 (no SSE), got %d", w.Code)
	}
	if w.Header().Get("Allow") != http.MethodPost {
		t.Fatalf("expected Allow: POST, got %q", w.Header().Get("Allow"))
	}
}

func TestMCPRequiresAuth(t *testing.T) {
	h := newTestHarness(t)
	w := doMCP(t, h, "", initMsg, nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("unauthenticated must 401, got %d", w.Code)
	}
	w = doMCP(t, h, "bad-token", initMsg, nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("invalid token must 401, got %d", w.Code)
	}
}

func TestMCPOriginValidation(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	// Allowed origin passes.
	w := doMCP(t, h, "tok-a", initMsg, map[string]string{"Origin": mcpOrigin})
	if w.Code != http.StatusOK {
		t.Fatalf("allowed origin must pass, got %d", w.Code)
	}
	// Absent origin (non-browser client) passes.
	w = doMCP(t, h, "tok-a", initMsg, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("absent origin must pass, got %d", w.Code)
	}
	// Unknown/mismatched origin is rejected (DNS-rebinding protection).
	for _, origin := range []string{"https://evil.test", "http://localhost:3000", "null"} {
		w = doMCP(t, h, "tok-a", initMsg, map[string]string{"Origin": origin})
		if w.Code != http.StatusForbidden {
			t.Fatalf("origin %q must 403, got %d", origin, w.Code)
		}
	}
	// Fail closed when no origin is configured.
	srv := NewServer(Config{TokenKey: testKey, SupabaseURL: "https://s.test", SupabaseAnonKey: "a"}, h.store)
	srv.verifier = h.verify
	engine := newEngine(srv)
	req := httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader(initMsg))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer tok-a")
	req.Header.Set("Origin", mcpOrigin)
	w = httptest.NewRecorder()
	engine.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Fatalf("unconfigured origins must fail closed, got %d", w.Code)
	}
}

func TestMCPUpperLevelProtocolChecks(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	req := httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader(initMsg))
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer tok-a")
	w := httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("wrong content type must 415, got %d", w.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader(initMsg))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "text/html")
	req.Header.Set("Authorization", "Bearer tok-a")
	w = httptest.NewRecorder()
	h.engine.ServeHTTP(w, req)
	if w.Code != http.StatusNotAcceptable {
		t.Fatalf("wrong accept must 406, got %d", w.Code)
	}

	w = doMCP(t, h, "tok-a", initMsg, map[string]string{"MCP-Protocol-Version": "2024-11-05"})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("wrong protocol version header must 400, got %d", w.Code)
	}
}

func TestMCPOversizedBodyFails(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	big := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_traveler_profile","arguments":{"pad":"` +
		strings.Repeat("x", 300<<10) + `"}}}`
	w := doMCP(t, h, "tok-a", big, nil)
	if w.Code == http.StatusOK {
		t.Fatalf("oversized body must fail, got %d", w.Code)
	}
}

// --- review regressions ---------------------------------------------------

// P2-6: a message must be one complete JSON value. A notification with a
// trailing tail is NOT a valid notification and must not get 202.
func TestMCPTrailingGarbageRejected(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")

	bodies := []string{
		`{"jsonrpc":"2.0","method":"notifications/initialized"}` + `]`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}{}`,
		`{"jsonrpc":"2.0","id":1,"method":"ping"}{"jsonrpc":"2.0","id":2,"method":"ping"}`,
		`{"jsonrpc":"2.0","id":1,"method":"ping"} trailing`,
		`{"jsonrpc":"2.0","id":1,"method":"ping"}]`,
	}
	for i, body := range bodies {
		w := doMCP(t, h, "tok-a", body, nil)
		if w.Code != http.StatusOK {
			t.Fatalf("body %d: expected rpc error envelope, got HTTP %d", i, w.Code)
		}
		if code := rpcErrorCode(t, w); code != rpcParseError {
			t.Fatalf("body %d: expected -32700 parse error, got %v", i, code)
		}
	}

	// A valid complete notification still gets exactly 202 + empty body.
	w := doMCP(t, h, "tok-a", `{"jsonrpc":"2.0","method":"notifications/initialized"}`, nil)
	if w.Code != http.StatusAccepted || w.Body.Len() != 0 {
		t.Fatalf("valid notification must 202 empty, got %d %q", w.Code, w.Body.String())
	}
}

// P2-6: Origin is validated on GET/DELETE too, before the 405 answer.
func TestMCPOriginValidatedOnGetDelete(t *testing.T) {
	h := newTestHarness(t)

	for _, method := range []string{http.MethodGet, http.MethodDelete} {
		req := httptest.NewRequest(method, "/mcp", nil)
		req.Header.Set("Origin", "https://evil.test")
		w := httptest.NewRecorder()
		h.engine.ServeHTTP(w, req)
		if w.Code != http.StatusForbidden {
			t.Fatalf("%s with bad origin must 403 before 405, got %d", method, w.Code)
		}

		req = httptest.NewRequest(method, "/mcp", nil)
		req.Header.Set("Origin", mcpOrigin)
		w = httptest.NewRecorder()
		h.engine.ServeHTTP(w, req)
		if w.Code != http.StatusMethodNotAllowed {
			t.Fatalf("%s with allowed origin must 405, got %d", method, w.Code)
		}

		req = httptest.NewRequest(method, "/mcp", nil)
		w = httptest.NewRecorder()
		h.engine.ServeHTTP(w, req)
		if w.Code != http.StatusMethodNotAllowed {
			t.Fatalf("%s without origin must 405, got %d", method, w.Code)
		}
	}
}
