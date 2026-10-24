package harness

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Read-only Google scopes requested by the harness. There is no send, booking
// or mutation scope anywhere in this service.
const (
	ScopeCalendarReadonly = "https://www.googleapis.com/auth/calendar.readonly"
	ScopeGmailReadonly    = "https://www.googleapis.com/auth/gmail.readonly"
)

// Bounds for Google read tools (frozen wire contract).
const (
	maxCalendarEvents  = 20
	calendarWindowDays = 14
	maxTravelMail      = 10
	mailWindowDays     = 30
	maxSnippetLen      = 300
	maxFieldLen        = 200
)

// errProvider is a sanitized upstream failure: it never carries provider
// response bodies, tokens or mail text.
var errProvider = errors.New("harness: provider request failed")

// errInvalidGrant marks an OAuth grant rejection (invalid_grant): the
// refresh/authorization grant is no longer usable and the user must
// reauthorize. It is distinct from transient provider failures.
var errInvalidGrant = errors.New("harness: oauth grant rejected")

// TokenSet is the decrypted Google token payload held only in memory.
type TokenSet struct {
	AccessToken  string
	RefreshToken string
	TokenType    string
	Expiry       time.Time
	Scopes       []string
	GoogleEmail  string
}

// HasScope reports whether the granted scope string includes want.
func (t TokenSet) HasScope(want string) bool {
	for _, s := range t.Scopes {
		if strings.EqualFold(strings.TrimSpace(s), want) {
			return true
		}
	}
	return false
}

// intersectScopes keeps only granted scopes the flow is authorized for.
// Google may return historic grants (include_granted_scopes=true) that were
// not selected in THIS OAuth flow; the user's selection wins, so a
// calendar-only state can never enable mail.
func intersectScopes(granted, allowed []string) []string {
	out := make([]string, 0, len(granted))
	for _, g := range granted {
		g = strings.TrimSpace(g)
		if g == "" {
			continue
		}
		for _, a := range allowed {
			if strings.EqualFold(g, a) {
				out = append(out, g)
				break
			}
		}
	}
	return out
}

// CalendarEvent is one bounded, read-only calendar entry.
type CalendarEvent struct {
	ID         string `json:"id"`
	Summary    string `json:"summary"`
	Start      string `json:"start"`
	End        string `json:"end"`
	Location   string `json:"location"`
	Provenance string `json:"provenance"`
}

// MailMessage is one bounded, read-only mail header + snippet view. Bodies and
// attachments are never fetched.
type MailMessage struct {
	ID         string `json:"id"`
	From       string `json:"from"`
	Subject    string `json:"subject"`
	Date       string `json:"date"`
	Snippet    string `json:"snippet"`
	Provenance string `json:"provenance"`
}

// GoogleReader is the only Google surface the tools may use. Tests substitute
// a fake; production uses googleAPI.
type GoogleReader interface {
	AuthorizationURL(state, codeChallenge string, wantCalendar, wantMail bool) string
	ExchangeCode(ctx context.Context, code, codeVerifier string) (TokenSet, error)
	Refresh(ctx context.Context, tok TokenSet) (TokenSet, error)
	FetchGoogleEmail(ctx context.Context, tok TokenSet) string
	Revoke(ctx context.Context, tok TokenSet) bool
	ListCalendarEvents(ctx context.Context, tok TokenSet, from, to time.Time) ([]CalendarEvent, error)
	// SearchTravelMail returns bounded results plus a partial flag: true when
	// some messages failed metadata fetch, so callers can label incomplete
	// data instead of pretending completeness.
	SearchTravelMail(ctx context.Context, tok TokenSet, query string, after time.Time) ([]MailMessage, bool, error)
}

// googleAPI talks to Google's OAuth and read-only REST APIs. Every client
// disables redirects so token-bearing requests can never leave the intended
// endpoint.
type googleAPI struct {
	clientID     string
	clientSecret string
	redirectURI  string
	authURL      string
	tokenURL     string
	revokeURL    string
	userInfoURL  string
	calendarURL  string
	gmailListURL string
	gmailGetURL  string
	client       *http.Client
}

func newGoogleAPI(cfg Config) *googleAPI {
	if !cfg.googleConfigured() {
		return nil
	}
	return &googleAPI{
		clientID:     cfg.GoogleClientID,
		clientSecret: cfg.GoogleClientSecret,
		redirectURI:  cfg.GoogleRedirectURI,
		authURL:      cfg.GoogleAuthURL,
		tokenURL:     cfg.GoogleTokenURL,
		revokeURL:    cfg.GoogleRevokeURL,
		userInfoURL:  cfg.GoogleUserInfoURL,
		calendarURL:  cfg.GoogleCalendarURL,
		gmailListURL: cfg.GoogleGmailList,
		gmailGetURL:  cfg.GoogleGmailGet,
		client:       noRedirectClient(15 * time.Second),
	}
}

// AuthorizationURL builds the Google consent URL for the requested read
// scopes with PKCE (S256) and offline access.
func (g *googleAPI) AuthorizationURL(state, codeChallenge string, wantCalendar, wantMail bool) string {
	scopes := []string{"openid", "email"}
	if wantCalendar {
		scopes = append(scopes, ScopeCalendarReadonly)
	}
	if wantMail {
		scopes = append(scopes, ScopeGmailReadonly)
	}
	q := url.Values{}
	q.Set("client_id", g.clientID)
	q.Set("redirect_uri", g.redirectURI)
	q.Set("response_type", "code")
	q.Set("scope", strings.Join(scopes, " "))
	q.Set("state", state)
	q.Set("code_challenge", codeChallenge)
	q.Set("code_challenge_method", "S256")
	q.Set("access_type", "offline")
	q.Set("include_granted_scopes", "true")
	q.Set("prompt", "consent")
	return g.authURL + "?" + q.Encode()
}

// ExchangeCode trades the one-use authorization code + PKCE verifier for
// tokens. Redirects are disabled; provider errors are sanitized.
func (g *googleAPI) ExchangeCode(ctx context.Context, code, codeVerifier string) (TokenSet, error) {
	form := url.Values{}
	form.Set("grant_type", "authorization_code")
	form.Set("code", code)
	form.Set("client_id", g.clientID)
	form.Set("client_secret", g.clientSecret)
	form.Set("redirect_uri", g.redirectURI)
	form.Set("code_verifier", codeVerifier)
	tok, err := g.tokenRequest(ctx, g.tokenURL, form)
	if err != nil {
		return TokenSet{}, err
	}
	return tok, nil
}

// Refresh exchanges a refresh token for a fresh access token (rotation-aware:
// a rotated refresh token is returned, otherwise the old one is kept).
// Redirects are disabled; invalid_grant is surfaced as errInvalidGrant so
// callers can demand reauthorization instead of fabricating data.
func (g *googleAPI) Refresh(ctx context.Context, tok TokenSet) (TokenSet, error) {
	if tok.RefreshToken == "" {
		return TokenSet{}, errInvalidGrant
	}
	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", tok.RefreshToken)
	form.Set("client_id", g.clientID)
	form.Set("client_secret", g.clientSecret)
	fresh, err := g.tokenRequest(ctx, g.tokenURL, form)
	if err != nil {
		return TokenSet{}, err
	}
	if fresh.RefreshToken == "" {
		fresh.RefreshToken = tok.RefreshToken
	}
	return fresh, nil
}

func (g *googleAPI) tokenRequest(ctx context.Context, endpoint string, form url.Values) (TokenSet, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return TokenSet{}, errProvider
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	resp, err := g.client.Do(req)
	if err != nil {
		return TokenSet{}, errProvider
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxAuthBody))
	if err != nil {
		return TokenSet{}, errProvider
	}
	if resp.StatusCode != http.StatusOK {
		var ebody struct {
			Error string `json:"error"`
		}
		if json.Unmarshal(body, &ebody) == nil && ebody.Error == "invalid_grant" {
			return TokenSet{}, errInvalidGrant
		}
		return TokenSet{}, errProvider
	}
	var raw struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		TokenType    string `json:"token_type"`
		ExpiresIn    int    `json:"expires_in"`
		Scope        string `json:"scope"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return TokenSet{}, errProvider
	}
	if raw.AccessToken == "" {
		return TokenSet{}, errProvider
	}
	scopes := strings.Fields(raw.Scope)
	return TokenSet{
		AccessToken:  raw.AccessToken,
		RefreshToken: raw.RefreshToken,
		TokenType:    raw.TokenType,
		Expiry:       time.Now().Add(time.Duration(raw.ExpiresIn) * time.Second),
		Scopes:       scopes,
	}, nil
}

// FetchGoogleEmail resolves the connected account email for display in
// account settings. Failures degrade to "" (never a fabricated address).
func (g *googleAPI) FetchGoogleEmail(ctx context.Context, tok TokenSet) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.userInfoURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Accept", "application/json")
	resp, err := g.client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ""
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxAuthBody))
	if err != nil {
		return ""
	}
	var info struct {
		Email string `json:"email"`
	}
	if err := json.Unmarshal(body, &info); err != nil {
		return ""
	}
	return truncate(strings.TrimSpace(info.Email), maxFieldLen)
}

// Revoke attempts provider-side revocation. It reports honestly whether the
// provider confirmed revocation (HTTP 200); any failure yields false.
func (g *googleAPI) Revoke(ctx context.Context, tok TokenSet) bool {
	token := tok.RefreshToken
	hint := "refresh_token"
	if token == "" {
		token = tok.AccessToken
		hint = "access_token"
	}
	if token == "" {
		return false
	}
	form := url.Values{}
	form.Set("token", token)
	form.Set("token_type_hint", hint)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, g.revokeURL, strings.NewReader(form.Encode()))
	if err != nil {
		return false
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := g.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, io.LimitReader(resp.Body, maxAuthBody))
	return resp.StatusCode == http.StatusOK
}

// ListCalendarEvents reads at most 20 events from the primary calendar within
// [from, to] (server-owned 14-day window).
func (g *googleAPI) ListCalendarEvents(ctx context.Context, tok TokenSet, from, to time.Time) ([]CalendarEvent, error) {
	q := url.Values{}
	q.Set("timeMin", from.UTC().Format(time.RFC3339))
	q.Set("timeMax", to.UTC().Format(time.RFC3339))
	q.Set("singleEvents", "true")
	q.Set("orderBy", "startTime")
	q.Set("maxResults", strconv.Itoa(maxCalendarEvents))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.calendarURL+"?"+q.Encode(), nil)
	if err != nil {
		return nil, errProvider
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Accept", "application/json")
	resp, err := g.client.Do(req)
	if err != nil {
		return nil, errProvider
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errProvider
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 512<<10))
	if err != nil {
		return nil, errProvider
	}
	var raw struct {
		Items []struct {
			ID      string `json:"id"`
			Summary string `json:"summary"`
			Start   struct {
				DateTime string `json:"dateTime"`
				Date     string `json:"date"`
			} `json:"start"`
			End struct {
				DateTime string `json:"dateTime"`
				Date     string `json:"date"`
			} `json:"end"`
			Location string `json:"location"`
		} `json:"items"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, errProvider
	}
	events := make([]CalendarEvent, 0, len(raw.Items))
	for _, it := range raw.Items {
		if len(events) >= maxCalendarEvents {
			break
		}
		start := it.Start.DateTime
		if start == "" {
			start = it.Start.Date
		}
		end := it.End.DateTime
		if end == "" {
			end = it.End.Date
		}
		events = append(events, CalendarEvent{
			ID:         truncate(it.ID, maxFieldLen),
			Summary:    truncate(it.Summary, maxFieldLen),
			Start:      truncate(start, maxFieldLen),
			End:        truncate(end, maxFieldLen),
			Location:   truncate(it.Location, maxFieldLen),
			Provenance: "google_calendar",
		})
	}
	return events, nil
}

// travelMailTerms are the server-owned terms that make a message
// travel-related. Callers cannot widen or replace them.
var travelMailTerms = []string{
	"travel", "flight", "hotel", "booking", "reservation", "itinerary",
	"trip", "train", "airport", "airline", "airbnb", "visa", "boarding pass",
}

// SearchTravelMail reads at most 10 travel-related messages from the last 30
// days: selected headers and snippets only. The date window and mailbox are
// server-owned; the optional caller query is sanitized to a keyword filter.
// Metadata fetches are attempted at most maxTravelMail times. If every fetch
// fails the upstream error is propagated (never an invented empty success);
// mixed outcomes return results with partial=true so callers can label the
// data as incomplete.
func (g *googleAPI) SearchTravelMail(ctx context.Context, tok TokenSet, query string, after time.Time) ([]MailMessage, bool, error) {
	terms := make([]string, 0, len(travelMailTerms))
	for _, t := range travelMailTerms {
		terms = append(terms, t)
	}
	q := fmt.Sprintf("after:%d (%s)", after.Unix(), strings.Join(terms, " OR "))
	if query != "" {
		// Words such as OR are Gmail operators even without punctuation. Keep
		// the caller's validated keyword phrase inside a literal so it cannot
		// widen the server-owned date and travel filters.
		q += " " + strconv.Quote(query)
	}
	list := url.Values{}
	list.Set("q", q)
	list.Set("maxResults", strconv.Itoa(maxTravelMail))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.gmailListURL+"?"+list.Encode(), nil)
	if err != nil {
		return nil, false, errProvider
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Accept", "application/json")
	resp, err := g.client.Do(req)
	if err != nil {
		return nil, false, errProvider
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, false, errProvider
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256<<10))
	if err != nil {
		return nil, false, errProvider
	}
	var raw struct {
		Messages []struct {
			ID string `json:"id"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, false, errProvider
	}

	msgs := make([]MailMessage, 0, maxTravelMail)
	attempts := 0
	failed := 0
	for _, m := range raw.Messages {
		if attempts >= maxTravelMail {
			break
		}
		attempts++
		msg, ok := g.fetchMailMetadata(ctx, tok, m.ID)
		if ok {
			msgs = append(msgs, msg)
		} else {
			failed++
		}
	}
	if attempts > 0 && len(msgs) == 0 {
		// Every metadata fetch failed: propagate the upstream failure instead
		// of reporting an invented empty success.
		return nil, false, errProvider
	}
	return msgs, failed > 0, nil
}

// fetchMailMetadata reads format=metadata only (From/Subject/Date headers plus
// the provider snippet). Message bodies and attachments are never requested.
func (g *googleAPI) fetchMailMetadata(ctx context.Context, tok TokenSet, id string) (MailMessage, bool) {
	if id == "" {
		return MailMessage{}, false
	}
	u := g.gmailGetURL + url.PathEscape(id) +
		"?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return MailMessage{}, false
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Accept", "application/json")
	resp, err := g.client.Do(req)
	if err != nil {
		return MailMessage{}, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return MailMessage{}, false
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 128<<10))
	if err != nil {
		return MailMessage{}, false
	}
	var raw struct {
		ID      string `json:"id"`
		Snippet string `json:"snippet"`
		Payload struct {
			Headers []struct {
				Name  string `json:"name"`
				Value string `json:"value"`
			} `json:"headers"`
		} `json:"payload"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return MailMessage{}, false
	}
	msg := MailMessage{
		ID:         truncate(raw.ID, maxFieldLen),
		Snippet:    truncate(raw.Snippet, maxSnippetLen),
		Provenance: "google_mail",
	}
	for _, h := range raw.Payload.Headers {
		switch strings.ToLower(h.Name) {
		case "from":
			msg.From = truncate(h.Value, maxFieldLen)
		case "subject":
			msg.Subject = truncate(h.Value, maxFieldLen)
		case "date":
			msg.Date = truncate(h.Value, maxFieldLen)
		}
	}
	return msg, true
}

func truncate(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) <= n {
		return s
	}
	return s[:n]
}
