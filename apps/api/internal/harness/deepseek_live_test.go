package harness

import (
	"os"
	"strings"
	"testing"
)

// Explicit opt-in: real DeepSeek, synthetic identity/profile, test-only auth
// fixture. This proves the production tool loop, not real Supabase login or
// Google access. The production executable contains no auth bypass.
func TestDeepSeekLiveHarness(t *testing.T) {
	if os.Getenv("HARNESS_LIVE_DEEPSEEK") != "1" {
		t.Skip("requires explicit paid provider acceptance opt-in")
	}
	key := os.Getenv("DEEPSEEK_API_KEY")
	if key == "" {
		t.Fatal("live DeepSeek key missing; no request sent")
	}
	h := newTestHarness(t)
	h.auth("synthetic-live-token", "synthetic-live-owner", "synthetic@example.invalid")
	w := doJSON(t, h, "PUT", "/v1/harness/profile", "synthetic-live-token", map[string]any{
		"display_name": "Synthetic Traveler", "home_city": "Lisbon",
		"interests": []string{"walking"}, "ai_context_consent": true,
	})
	if w.Code != 200 {
		t.Fatal("synthetic confirmed profile setup failed")
	}
	h.srv.deepseek = newDeepSeekClient(Config{DeepSeekAPIKey: key, DeepSeekBaseURL: "https://api.deepseek.com/v1"})
	w = doJSON(t, h, "POST", "/v1/harness/chat", "synthetic-live-token", map[string]any{
		"message": "Use get_traveler_profile to read my confirmed home city, then answer with that city in one short sentence. Do not infer it. This is synthetic acceptance data.",
	})
	if w.Code != 200 {
		t.Fatalf("live harness returned HTTP %d (body deliberately omitted)", w.Code)
	}
	result := decodeBody(t, w)
	reply, _ := result["reply"].(string)
	if !strings.Contains(reply, "Lisbon") {
		t.Fatal("answer did not use the confirmed synthetic city (body omitted)")
	}
	calls, _ := result["tool_calls"].([]any)
	profileUsed := false
	for _, raw := range calls {
		call, ok := raw.(map[string]any)
		if !ok {
			t.Fatal("invalid tool trace")
		}
		if call["name"] == "get_traveler_profile" && call["status"] == "ok" {
			profileUsed = true
		}
		if call["name"] != "get_traveler_profile" {
			t.Fatal("unexpected source tool requested without a connection")
		}
	}
	if !profileUsed || len(calls) > MaxToolCallsPerChat {
		t.Fatal("live bounded tool execution was not proven")
	}
	t.Logf("real DeepSeek harness completed with %d profile tool call(s); synthetic data only", len(calls))
}
