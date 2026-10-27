package harness

import (
	"net/http"
	"strings"
	"testing"
)

func TestChatResponseShapeAndToolTrace(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{"food"}, "ai_context_consent": true,
	})

	h.model.steps = []ChatResponse{
		{ToolCalls: []ToolCallReq{{ID: "c1", Type: "function", Function: struct {
			Name      string `json:"name"`
			Arguments string `json:"arguments"`
		}{Name: "get_traveler_profile", Arguments: "{}"}}}},
		{Content: "You are set up, Ada."},
	}

	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{
		"message": "What do you know about me?",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d: %s", w.Code, w.Body.String())
	}
	m := decodeBody(t, w)
	if m["reply"] != "You are set up, Ada." {
		t.Fatalf("unexpected reply %v", m["reply"])
	}
	calls, _ := m["tool_calls"].([]any)
	if len(calls) != 1 {
		t.Fatalf("expected 1 tool call trace, got %v", calls)
	}
	trace := calls[0].(map[string]any)
	if trace["name"] != "get_traveler_profile" || trace["status"] != "ok" {
		t.Fatalf("trace must carry name/status only, got %v", trace)
	}
	if len(trace) != 2 {
		t.Fatalf("trace must carry name/status only, got %v", trace)
	}
	// The response never leaks tool payloads, prompts or mail.
	body := w.Body.String()
	for _, secret := range []string{"a@example.test", "system", "tool_call_id"} {
		if strings.Contains(body, secret) {
			t.Fatalf("response leaks %q: %s", secret, body)
		}
	}
}

func TestChatWithoutConsentOffersNoTools(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})

	h.model.steps = []ChatResponse{{Content: "Standing by."}}
	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{
		"message": "Plan my week",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d", w.Code)
	}
	if len(h.model.reqs[0].Tools) != 0 {
		t.Fatalf("without consent no tools may be offered, got %v", h.model.reqs[0].Tools)
	}
}

func TestChatWithConsentOffersOnlyGrantedScopes(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})

	h.model.steps = []ChatResponse{{Content: "ok"}}
	doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "hi"})

	names := map[string]bool{}
	for _, tool := range h.model.reqs[0].Tools {
		fn := tool["function"].(map[string]any)
		names[fn["name"].(string)] = true
	}
	if !names["get_traveler_profile"] || !names["list_calendar_events"] {
		t.Fatalf("expected profile+calendar tools, got %v", names)
	}
	if names["search_travel_mail"] {
		t.Fatalf("mail tool must not be offered without scope: %v", names)
	}
}

func TestChatBoundsRoundsAndCalls(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly, ScopeGmailReadonly})

	// The model asks for tool calls on every round; the loop must stop at
	// MaxChatRounds and never execute more than MaxToolCallsPerChat calls.
	for i := 0; i < 10; i++ {
		h.model.steps = append(h.model.steps, ChatResponse{ToolCalls: []ToolCallReq{
			{ID: "c1", Type: "function", Function: struct {
				Name      string `json:"name"`
				Arguments string `json:"arguments"`
			}{Name: "get_traveler_profile", Arguments: "{}"}},
			{ID: "c2", Type: "function", Function: struct {
				Name      string `json:"name"`
				Arguments string `json:"arguments"`
			}{Name: "list_calendar_events", Arguments: "{}"}},
			{ID: "c3", Type: "function", Function: struct {
				Name      string `json:"name"`
				Arguments string `json:"arguments"`
			}{Name: "search_travel_mail", Arguments: "{}"}},
		}})
	}

	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{
		"message": "Do everything",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d: %s", w.Code, w.Body.String())
	}
	if h.model.calls > MaxChatRounds {
		t.Fatalf("model rounds %d exceed bound %d", h.model.calls, MaxChatRounds)
	}
	m := decodeBody(t, w)
	traces, _ := m["tool_calls"].([]any)
	executed := 0
	for _, tr := range traces {
		if tr.(map[string]any)["status"] != "limit_reached" {
			executed++
		}
	}
	if executed > MaxToolCallsPerChat {
		t.Fatalf("executed %d tool calls, bound is %d", executed, MaxToolCallsPerChat)
	}
	if len(traces) == 0 {
		t.Fatal("expected tool traces")
	}
}

func TestChatRejectsBadMessages(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	for _, body := range []map[string]any{
		{"message": ""},
		{"message": "    "},
		{"message": strings.Repeat("x", 5000)},
		{"prompt": "hi"},
	} {
		w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", body)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("body %v must 400, got %d", body, w.Code)
		}
	}
}

func TestChatMissingConfigIs503(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.srv.deepseek = nil
	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "hi"})
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("missing deepseek config must 503, got %d", w.Code)
	}
}

func TestChatRateLimitPerVerifiedUser(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.auth("tok-b", "user-b", "b@example.test")
	h.srv.limiter = NewLimiter(2, 4, 8)
	h.model.steps = []ChatResponse{{Content: "ok"}}

	for i := 0; i < 2; i++ {
		w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "hi"})
		if w.Code != http.StatusOK {
			t.Fatalf("request %d got %d", i, w.Code)
		}
	}
	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "hi"})
	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("third request must 429, got %d", w.Code)
	}
	// Other users are unaffected (per verified user budget).
	w = doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-b", map[string]any{"message": "hi"})
	if w.Code != http.StatusOK {
		t.Fatalf("other user must not be throttled, got %d", w.Code)
	}
}

func TestChatModelFailureIsSanitized(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	h.model.err = errString("deepseek exploded with key=SECRET")
	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "hi"})
	if w.Code != http.StatusBadGateway {
		t.Fatalf("model failure must map to 502, got %d", w.Code)
	}
	if strings.Contains(w.Body.String(), "SECRET") {
		t.Fatalf("provider error leaked: %s", w.Body.String())
	}
	if strings.Contains(h.logs.String(), "SECRET") {
		t.Fatalf("provider error leaked into logs: %s", h.logs.String())
	}
}

func TestChatUntrustedProviderTextIsNotInstructions(t *testing.T) {
	// Provider mail text claiming tool authority must never escalate into the
	// tool surface: the registry stays server-owned and model tool calls are
	// validated against it.
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.model.steps = []ChatResponse{
		{ToolCalls: []ToolCallReq{{ID: "c1", Type: "function", Function: struct {
			Name      string `json:"name"`
			Arguments string `json:"arguments"`
		}{Name: "send_mail", Arguments: "{\"to\":\"victim@example.test\"}"}}}},
		{Content: "I could not do that."},
	}
	w := doJSON(t, h, http.MethodPost, "/v1/harness/chat", "tok-a", map[string]any{"message": "help"})
	if w.Code != http.StatusOK {
		t.Fatalf("got %d", w.Code)
	}
	traces := decodeBody(t, w)["tool_calls"].([]any)
	if traces[0].(map[string]any)["status"] != "error" {
		t.Fatalf("unknown tool must fail, got %v", traces)
	}
	if strings.Contains(h.logs.String(), "victim@example.test") {
		t.Fatal("arguments leaked into logs")
	}
}
