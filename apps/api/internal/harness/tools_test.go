package harness

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"
)

func execTool(t *testing.T, h *testHarness, ident Identity, name string, args string, forModel bool) (ToolResult, error) {
	t.Helper()
	return h.srv.ExecuteTool(context.Background(), ident, name, json.RawMessage(args), forModel)
}

func TestTravelerProfileToolNeverReturnsEmail(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{"food"}, "ai_context_consent": true,
	})

	res, err := execTool(t, h, Identity{ID: "user-a", Email: "a@example.test"},
		"get_traveler_profile", "{}", true)
	if err != nil {
		t.Fatal(err)
	}
	if res.Status != "ok" {
		t.Fatalf("unexpected status %+v", res)
	}
	b, _ := json.Marshal(res)
	if strings.Contains(string(b), "a@example.test") {
		t.Fatalf("email leaked through tool: %s", b)
	}
}

func TestToolArgumentsCannotSelectUserOrWindow(t *testing.T) {
	h := newTestHarness(t)
	id := Identity{ID: "user-a", Email: "a@example.test"}

	for _, args := range []string{
		`{"user_id":"user-b"}`,
		`{"date_window":"2020-01-01/2030-01-01"}`,
		`{"mailbox":"other@example.test"}`,
		`{"endpoint":"https://evil.test"}`,
		`[]`,
		`"strings"`,
		`null`,
		`{"query":"x"}{"y":1}`,
	} {
		_, err := execTool(t, h, id, "get_traveler_profile", args, false)
		if err == nil {
			t.Fatalf("arguments %s must be rejected", args)
		}
	}
	// list_calendar_events takes no arguments at all.
	if _, err := execTool(t, h, id, "list_calendar_events", `{"days":999}`, false); err == nil {
		t.Fatal("calendar tool must reject arguments")
	}
	// search_travel_mail rejects operator/selector injection.
	for _, q := range []string{
		`{"query":"in:spam"}`,
		`{"query":"from:boss@example.test"}`,
		`{"query":"{a b}"}`,
		`{"query":"-flight"}`,
		`{"query":"older_than:90d"}`,
		`{"query":"` + strings.Repeat("x", 200) + `"}`,
		`{"query":"   "}`,
	} {
		_, err := execTool(t, h, id, "search_travel_mail", q, false)
		if err == nil {
			t.Fatalf("mail query %s must be rejected", q)
		}
	}
}

func TestGoogleToolsRequireConsentThenScopeThenConnection(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}

	// No consent: denied before anything else.
	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Error != "consent_required" {
		t.Fatalf("expected consent_required, got %+v", res)
	}

	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})

	// Consent but not connected.
	res, _ = execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Error != "google_not_connected" {
		t.Fatalf("expected google_not_connected, got %+v", res)
	}

	// Connected but missing the calendar scope.
	h.seedTokens(t, "user-a", []string{ScopeGmailReadonly})
	res, _ = execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Error != "missing_scope" {
		t.Fatalf("expected missing_scope, got %+v", res)
	}

	// Provider failure is a clear error, never an invented empty success.
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})
	h.google.eventsErr = errProvider
	res, _ = execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "provider_unavailable" {
		t.Fatalf("expected provider_unavailable error, got %+v", res)
	}
	if res.Data != nil {
		t.Fatalf("failure must not fabricate data: %+v", res)
	}
}

func TestModelCallsRequireContextConsentEvenForProfile(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}

	// Direct call without consent: allowed (user reading own manual profile).
	res, _ := execTool(t, h, id, "get_traveler_profile", "{}", false)
	if res.Status != "ok" {
		t.Fatalf("direct profile read must work: %+v", res)
	}
	// Same call for a model request: denied without consent.
	res, _ = execTool(t, h, id, "get_traveler_profile", "{}", true)
	if res.Error != "consent_required" {
		t.Fatalf("model read must require consent: %+v", res)
	}
}

func TestCalendarToolWindowIsServerOwned(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})
	h.google.events = []CalendarEvent{
		{ID: "1", Summary: "Train to Porto", Start: "2026-10-25T09:00:00Z", Provenance: "google_calendar"},
	}

	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	h.srv.now = func() time.Time { return now }

	res, err := execTool(t, h, id, "list_calendar_events", "{}", false)
	if err != nil {
		t.Fatal(err)
	}
	if res.Status != "ok" {
		t.Fatalf("unexpected %+v", res)
	}
	if !h.google.lastWindowFrom.Equal(now) {
		t.Fatalf("window start must be server clock: %v", h.google.lastWindowFrom)
	}
	if want := now.AddDate(0, 0, calendarWindowDays); !h.google.lastWindowTo.Equal(want) {
		t.Fatalf("window end must be +14d: %v", h.google.lastWindowTo)
	}
}

func TestMailToolBoundsAndSanitizesQuery(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeGmailReadonly})
	h.google.mail = []MailMessage{
		{ID: "m1", From: "airline@example.test", Subject: "Flight confirmed",
			Snippet: "Your flight...", Provenance: "google_mail"},
	}

	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	h.srv.now = func() time.Time { return now }

	res, err := execTool(t, h, id, "search_travel_mail", `{"query":"Porto FLIGHT"}`, false)
	if err != nil {
		t.Fatal(err)
	}
	if res.Status != "ok" {
		t.Fatalf("unexpected %+v", res)
	}
	if h.google.lastMailQuery != "porto flight" {
		t.Fatalf("query must be normalized: %q", h.google.lastMailQuery)
	}
	if want := now.AddDate(0, 0, -mailWindowDays); !h.google.lastMailAfter.Equal(want) {
		t.Fatalf("mail window must be server-owned -30d: %v", h.google.lastMailAfter)
	}
}

func TestGoogleClientBoundsProviderPayloads(t *testing.T) {
	// Fake Google endpoints returning oversized provider payloads: the client
	// must slice to the frozen bounds and truncate fields, never trust size.
	cal := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		items := make([]map[string]any, 50)
		for i := range items {
			items[i] = map[string]any{
				"id":      strings.Repeat("e", 300),
				"summary": strings.Repeat("s", 500),
				"start":   map[string]string{"dateTime": "2026-10-25T09:00:00Z"},
				"end":     map[string]string{"dateTime": "2026-10-25T10:00:00Z"},
			}
		}
		json.NewEncoder(w).Encode(map[string]any{"items": items})
	}))
	defer cal.Close()

	list := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		msgs := make([]map[string]string, 30)
		for i := range msgs {
			msgs[i] = map[string]string{"id": "m" + strings.Repeat("x", 200)}
		}
		json.NewEncoder(w).Encode(map[string]any{"messages": msgs})
	}))
	defer list.Close()

	get := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"id":      "m1",
			"snippet": strings.Repeat("body-ish snippet ", 100),
			"payload": map[string]any{"headers": []map[string]string{
				{"name": "From", "value": "Airline <a@example.test>"},
				{"name": "Subject", "value": strings.Repeat("S", 400)},
			}},
		})
	}))
	defer get.Close()

	g := &googleAPI{
		calendarURL:  cal.URL,
		gmailListURL: list.URL,
		gmailGetURL:  get.URL + "/",
		client:       noRedirectClient(5 * time.Second),
	}
	now := time.Now()
	events, err := g.ListCalendarEvents(context.Background(), TokenSet{AccessToken: "x"}, now, now.AddDate(0, 0, 14))
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != maxCalendarEvents {
		t.Fatalf("expected %d events, got %d", maxCalendarEvents, len(events))
	}
	for _, ev := range events {
		if len(ev.ID) > maxFieldLen || len(ev.Summary) > maxFieldLen {
			t.Fatal("event fields must be truncated")
		}
	}

	msgs, partial, err := g.SearchTravelMail(context.Background(), TokenSet{AccessToken: "x"}, "porto", now.AddDate(0, 0, -30))
	if err != nil {
		t.Fatal(err)
	}
	if partial {
		t.Fatal("all metadata fetches succeeded: partial must be false")
	}
	if len(msgs) != maxTravelMail {
		t.Fatalf("expected %d messages, got %d", maxTravelMail, len(msgs))
	}
	for _, m := range msgs {
		if len(m.Snippet) > maxSnippetLen {
			t.Fatal("snippet must be truncated")
		}
		if len(m.Subject) > maxFieldLen {
			t.Fatal("subject must be truncated")
		}
	}
}

// --- review regressions ---------------------------------------------------

// seedTokensExpiring installs a connection via ReplaceConnection with a
// caller-chosen expiry (for refresh tests).
func (h *testHarness) seedTokensExpiring(t *testing.T, userID string, scopes []string, expiry time.Time, refresh string) {
	t.Helper()
	access, err := h.srv.crypto.SealToken(userID, purposeAccess, []byte("access-token-value"))
	if err != nil {
		t.Fatal(err)
	}
	refreshEnc, err := h.srv.crypto.SealToken(userID, purposeRefresh, []byte(refresh))
	if err != nil {
		t.Fatal(err)
	}
	err = h.store.ReplaceConnection(context.Background(), userID, h.store.currentGen(userID), StoredTokens{
		AccessEnc: access, RefreshEnc: refreshEnc, TokenType: "Bearer",
		Scopes: scopes, GoogleEmail: "traveler@example.test",
		ExpiresAt: expiry,
	})
	if err != nil {
		t.Fatal(err)
	}
}

// P2-3: an expired access token with a usable refresh token is refreshed
// (rotation-aware) and the user's selected scope subset survives the refresh.
func TestTokenRefreshOnExpiryPreservesScopeSubsetAndRotation(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokensExpiring(t, "user-a", []string{"openid", "email", ScopeCalendarReadonly},
		time.Now().Add(-time.Hour), "old-refresh")

	// Refresh rotates the refresh token and returns a WIDER scope set that
	// this connection never selected (historic grant).
	h.google.refreshFn = func(tok TokenSet) (TokenSet, error) {
		if tok.RefreshToken != "old-refresh" {
			t.Fatalf("refresh must present the stored refresh token, got %q", tok.RefreshToken)
		}
		return TokenSet{
			AccessToken: "rotated-access", RefreshToken: "rotated-refresh",
			TokenType: "Bearer", Expiry: time.Now().Add(time.Hour),
			Scopes: []string{"openid", "email", ScopeCalendarReadonly, ScopeGmailReadonly},
		}, nil
	}

	res, err := execTool(t, h, id, "list_calendar_events", "{}", false)
	if err != nil {
		t.Fatal(err)
	}
	if res.Status != "ok" {
		t.Fatalf("refreshed token must work, got %+v", res)
	}
	if h.google.refreshCalls != 1 {
		t.Fatalf("expected exactly one refresh, got %d", h.google.refreshCalls)
	}

	st, err := h.store.GetTokens(context.Background(), "user-a")
	if err != nil {
		t.Fatal(err)
	}
	tok, err := h.srv.decryptTokens("user-a", st)
	if err != nil {
		t.Fatal(err)
	}
	if tok.AccessToken != "rotated-access" || tok.RefreshToken != "rotated-refresh" {
		t.Fatalf("rotation not persisted: %+v", tok)
	}
	for _, sc := range st.Scopes {
		if sc == ScopeGmailReadonly {
			t.Fatalf("refresh must not widen the selected scope subset: %v", st.Scopes)
		}
	}
	// Mail stays denied after refresh.
	res, _ = execTool(t, h, id, "search_travel_mail", "{}", false)
	if res.Error != "missing_scope" {
		t.Fatalf("mail must stay denied after refresh, got %+v", res)
	}
}

// P2-3: expired tokens without a usable refresh token surface
// reauthorization_required instead of silent empty data.
func TestExpiredWithoutRefreshRequiresReauthorization(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokensExpiring(t, "user-a", []string{ScopeCalendarReadonly},
		time.Now().Add(-time.Hour), "")

	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "reauthorization_required" {
		t.Fatalf("expected reauthorization_required, got %+v", res)
	}
	if res.Data != nil {
		t.Fatalf("must not fabricate empty data: %+v", res)
	}
}

// P2-3: a rejected refresh (invalid_grant) surfaces reauthorization_required.
func TestRejectedRefreshRequiresReauthorization(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokensExpiring(t, "user-a", []string{ScopeCalendarReadonly},
		time.Now().Add(-time.Hour), "old-refresh")
	h.google.refreshErr = errInvalidGrant

	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "reauthorization_required" {
		t.Fatalf("invalid_grant must demand reauthorization, got %+v", res)
	}
}

// P2-3/P1-2: a refresh in flight when the user disconnects must fail its
// generation commit and must not restore the revoked connection.
func TestRefreshDuringDisconnectIsBlocked(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokensExpiring(t, "user-a", []string{ScopeCalendarReadonly},
		time.Now().Add(-time.Hour), "old-refresh")

	h.google.refreshFn = func(tok TokenSet) (TokenSet, error) {
		// Disconnect while the refresh call is on the wire.
		if _, err := h.store.Disconnect(context.Background(), "user-a"); err != nil {
			t.Fatal(err)
		}
		return TokenSet{
			AccessToken: "late-access", RefreshToken: "late-refresh",
			TokenType: "Bearer", Expiry: time.Now().Add(time.Hour),
			Scopes: []string{ScopeCalendarReadonly},
		}, nil
	}

	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "google_not_connected" {
		t.Fatalf("refresh after disconnect must fail, got %+v", res)
	}
	if _, err := h.store.GetTokens(context.Background(), "user-a"); err == nil {
		t.Fatal("refresh must not restore a disconnected account")
	}
}

// P2-7: with Google unconfigured (nil interface from NewServer), saved tokens
// must produce a clear error, never a nil-pointer panic.
func TestGoogleNilConfigWithSavedTokensDoesNotPanic(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeCalendarReadonly})
	h.srv.google = nil

	res, _ := execTool(t, h, id, "list_calendar_events", "{}", false)
	if res.Status != "error" || res.Error != "google_not_configured" {
		t.Fatalf("expected google_not_configured, got %+v", res)
	}
	res, _ = execTool(t, h, id, "search_travel_mail", "{}", false)
	if res.Status != "error" || res.Error != "google_not_configured" {
		t.Fatalf("expected google_not_configured, got %+v", res)
	}
}

// P2-4: a real-client all-failed metadata path propagates the upstream error
// instead of returning status ok with empty messages.
func TestGoogleClientMailAllFailedPropagatesError(t *testing.T) {
	list := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"messages": []map[string]string{{"id": "m1"}, {"id": "m2"}},
		})
	}))
	defer list.Close()
	get := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer get.Close()

	g := &googleAPI{
		gmailListURL: list.URL,
		gmailGetURL:  get.URL + "/",
		client:       noRedirectClient(5 * time.Second),
	}
	msgs, partial, err := g.SearchTravelMail(context.Background(), TokenSet{AccessToken: "x"}, "", time.Now().AddDate(0, 0, -30))
	if err == nil {
		t.Fatalf("all-failed metadata must propagate an error, got %+v (partial=%v)", msgs, partial)
	}
	if msgs != nil {
		t.Fatalf("all-failed must not fabricate messages: %+v", msgs)
	}
}

// P2-4: mixed outcomes return bounded results explicitly labelled partial.
func TestGoogleClientMailMixedResultsAreLabelledPartial(t *testing.T) {
	list := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"messages": []map[string]string{{"id": "ok1"}, {"id": "bad"}, {"id": "ok2"}},
		})
	}))
	defer list.Close()
	get := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.Contains(r.URL.Path, "bad") {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{
			"id": "m", "snippet": "hi",
			"payload": map[string]any{"headers": []map[string]string{{"name": "Subject", "value": "Flight"}}},
		})
	}))
	defer get.Close()

	g := &googleAPI{
		gmailListURL: list.URL,
		gmailGetURL:  get.URL + "/",
		client:       noRedirectClient(5 * time.Second),
	}
	msgs, partial, err := g.SearchTravelMail(context.Background(), TokenSet{AccessToken: "x"}, "", time.Now().AddDate(0, 0, -30))
	if err != nil {
		t.Fatal(err)
	}
	if len(msgs) != 2 {
		t.Fatalf("expected 2 messages, got %d", len(msgs))
	}
	if !partial {
		t.Fatal("mixed results must be labelled partial")
	}
}

// P2-4: metadata fetches are attempted at most maxTravelMail times even when
// the provider lists more ids than the bound.
func TestGoogleClientMailAttemptsBounded(t *testing.T) {
	var calls int
	list := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		msgs := make([]map[string]string, 30)
		for i := range msgs {
			msgs[i] = map[string]string{"id": "m" + strconv.Itoa(i)}
		}
		json.NewEncoder(w).Encode(map[string]any{"messages": msgs})
	}))
	defer list.Close()
	get := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		json.NewEncoder(w).Encode(map[string]any{"id": "m", "snippet": "hi"})
	}))
	defer get.Close()

	g := &googleAPI{
		gmailListURL: list.URL,
		gmailGetURL:  get.URL + "/",
		client:       noRedirectClient(5 * time.Second),
	}
	msgs, partial, err := g.SearchTravelMail(context.Background(), TokenSet{AccessToken: "x"}, "", time.Now().AddDate(0, 0, -30))
	if err != nil {
		t.Fatal(err)
	}
	if partial {
		t.Fatal("all fetches succeeded: partial must be false")
	}
	if calls > maxTravelMail {
		t.Fatalf("metadata attempts %d exceed bound %d", calls, maxTravelMail)
	}
	if len(msgs) != maxTravelMail {
		t.Fatalf("expected %d messages, got %d", maxTravelMail, len(msgs))
	}
}

// P2-4: the tool result labels partial data explicitly.
func TestMailToolLabelsPartialResults(t *testing.T) {
	h := newTestHarness(t)
	h.auth("tok-a", "user-a", "a@example.test")
	id := Identity{ID: "user-a", Email: "a@example.test"}
	doJSON(t, h, "PUT", "/v1/harness/profile", "tok-a", map[string]any{
		"display_name": "Ada", "home_city": "Lisbon",
		"interests": []string{}, "ai_context_consent": true,
	})
	h.seedTokens(t, "user-a", []string{ScopeGmailReadonly})
	h.google.mail = []MailMessage{{ID: "m1", Provenance: "google_mail"}}
	h.google.mailPartial = true

	res, err := execTool(t, h, id, "search_travel_mail", "{}", false)
	if err != nil {
		t.Fatal(err)
	}
	if res.Status != "ok" {
		t.Fatalf("unexpected %+v", res)
	}
	data := res.Data.(map[string]any)
	if data["partial"] != true {
		t.Fatalf("partial results must be labelled: %+v", data)
	}
}
