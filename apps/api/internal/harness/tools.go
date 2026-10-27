package harness

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"strings"
	"time"
)

// ToolResult is the uniform outcome of one bounded read tool. Execution
// failures carry a clear sanitized error code — never an invented empty
// success.
type ToolResult struct {
	Status     string   `json:"status"` // "ok" | "error"
	Data       any      `json:"data,omitempty"`
	Error      string   `json:"error,omitempty"`
	Provenance []string `json:"provenance,omitempty"`
}

func toolOK(data any, provenance ...string) ToolResult {
	return ToolResult{Status: "ok", Data: data, Provenance: provenance}
}

func toolErr(code string) ToolResult {
	return ToolResult{Status: "error", Error: code}
}

// errInvalidArgs marks strict argument-validation failures (malformed JSON,
// unknown fields, blank or oversized values). Handlers surface these as
// errors; they never fall back to defaults.
var errInvalidArgs = errors.New("harness: invalid tool arguments")

// toolEnv carries the verified caller and execution mode into a tool.
type toolEnv struct {
	s        *Server
	ident    Identity
	forModel bool // true when results feed a DeepSeek model request
}

type toolDef struct {
	name        string
	description string
	inputSchema map[string]any
	run         func(ctx context.Context, e *toolEnv, args json.RawMessage) (ToolResult, error)
}

// toolRegistry is the single authenticated registry shared by POST
// /v1/harness/tools/call, the MCP endpoint and the server DeepSeek loop.
var toolRegistry = map[string]*toolDef{
	"get_traveler_profile": toolGetTravelerProfile,
	"list_calendar_events": toolListCalendarEvents,
	"search_travel_mail":   toolSearchTravelMail,
}

// noArgSchema rejects any tool argument for tools that take none.
var noArgSchema = map[string]any{
	"type":                 "object",
	"properties":           map[string]any{},
	"additionalProperties": false,
}

var mailArgSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"query": map[string]any{
			"type":        "string",
			"description": "Optional keyword filter (letters, digits, spaces and ,.'@ only). The mailbox and the last-30-days travel window are fixed by the server.",
			"maxLength":   80,
		},
	},
	"additionalProperties": false,
}

// decodeToolArgs strictly validates raw arguments against dst. Arguments must
// be a single complete JSON object; unknown fields, trailing values (`]`, `}`,
// a second object), non-object JSON and oversized payloads fail.
func decodeToolArgs(raw json.RawMessage, dst any) error {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 {
		trimmed = []byte("{}")
	}
	if trimmed[0] != '{' {
		return errInvalidArgs
	}
	if len(trimmed) > 4<<10 {
		return errInvalidArgs
	}
	dec := json.NewDecoder(bytes.NewReader(trimmed))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return errInvalidArgs
	}
	if err := dec.Decode(new(any)); !errors.Is(err, io.EOF) {
		return errInvalidArgs
	}
	return nil
}

var mailQueryPattern = regexp.MustCompile(`^[A-Za-z0-9 ,.'@]+$`)

// sanitizeMailQuery enforces a keyword-only filter so callers cannot alter the
// mailbox, date window or search operators (no `:`, `-`, braces or parens).
// A present-but-blank query is rejected; an absent query is allowed.
func sanitizeMailQuery(q string) (string, error) {
	q = strings.TrimSpace(q)
	if q == "" {
		return "", nil
	}
	if len(q) > 80 || !mailQueryPattern.MatchString(q) {
		return "", errInvalidArgs
	}
	if strings.ContainsAny(q, "{}():") {
		return "", errInvalidArgs
	}
	// Lower-case removes Gmail operator semantics (e.g. uppercase OR).
	q = strings.ToLower(q)
	return strings.Join(strings.Fields(q), " "), nil
}

// --- get_traveler_profile -------------------------------------------------

var toolGetTravelerProfile = &toolDef{
	name:        "get_traveler_profile",
	description: "Return the traveler's confirmed/manual profile fields (display name, home city, interests). No email. Manual fields only; suggestions are never auto-saved.",
	inputSchema: noArgSchema,
	run: func(ctx context.Context, e *toolEnv, args json.RawMessage) (ToolResult, error) {
		var empty struct{}
		if err := decodeToolArgs(args, &empty); err != nil {
			return ToolResult{}, err
		}
		profile, err := e.s.store.GetProfile(ctx, e.ident.ID)
		if errors.Is(err, ErrNotFound) {
			// No stored profile means no recorded model-context consent: a
			// model-bound read must fail rather than fall through.
			if e.forModel {
				return toolErr("consent_required"), nil
			}
			// Not invented data: an empty manual profile is an honest state.
			return toolOK(map[string]any{
				"display_name": "",
				"home_city":    "",
				"interests":    []string{},
				"provenance":   "manual",
			}, "traveler_profile"), nil
		}
		if err != nil {
			return toolErr("store_unavailable"), nil
		}
		// Model-bound calls may only read account context with explicit
		// model-context consent.
		if e.forModel && !profile.AIContextConsent {
			return toolErr("consent_required"), nil
		}
		return toolOK(map[string]any{
			"display_name": profile.DisplayName,
			"home_city":    profile.HomeCity,
			"interests":    profile.Interests,
			"provenance":   "manual",
		}, "traveler_profile"), nil
	},
}

// --- list_calendar_events -------------------------------------------------

var toolListCalendarEvents = &toolDef{
	name:        "list_calendar_events",
	description: "List at most 20 events from the traveler's primary Google calendar over the next 14 days (read-only). No arguments.",
	inputSchema: noArgSchema,
	run: func(ctx context.Context, e *toolEnv, args json.RawMessage) (ToolResult, error) {
		var empty struct{}
		if err := decodeToolArgs(args, &empty); err != nil {
			return ToolResult{}, err
		}
		tok, err := e.googleReady(ctx, ScopeCalendarReadonly)
		if err != nil {
			return toolErr(err.Error()), nil
		}
		from := e.s.now().UTC()
		to := from.AddDate(0, 0, calendarWindowDays)
		events, err := e.s.google.ListCalendarEvents(ctx, tok, from, to)
		if err != nil {
			return toolErr("provider_unavailable"), nil
		}
		return toolOK(map[string]any{
			"window_start": from.Format(time.RFC3339),
			"window_end":   to.Format(time.RFC3339),
			"events":       events,
		}, "google_calendar"), nil
	},
}

// --- search_travel_mail ---------------------------------------------------

var toolSearchTravelMail = &toolDef{
	name:        "search_travel_mail",
	description: "Search at most 10 travel-related messages from the last 30 days (selected headers and snippets only; no bodies or attachments). Optional keyword filter only.",
	inputSchema: mailArgSchema,
	run: func(ctx context.Context, e *toolEnv, args json.RawMessage) (ToolResult, error) {
		var a struct {
			Query *string `json:"query"`
		}
		if err := decodeToolArgs(args, &a); err != nil {
			return ToolResult{}, err
		}
		query := ""
		if a.Query != nil {
			// Present-but-blank is an invalid input, never a silent default.
			if strings.TrimSpace(*a.Query) == "" {
				return ToolResult{}, errInvalidArgs
			}
			q, err := sanitizeMailQuery(*a.Query)
			if err != nil {
				return ToolResult{}, err
			}
			query = q
		}
		tok, err := e.googleReady(ctx, ScopeGmailReadonly)
		if err != nil {
			return toolErr(err.Error()), nil
		}
		after := e.s.now().UTC().AddDate(0, 0, -mailWindowDays)
		msgs, partial, err := e.s.google.SearchTravelMail(ctx, tok, query, after)
		if err != nil {
			return toolErr("provider_unavailable"), nil
		}
		// Partial results are labelled explicitly so the model never mistakes
		// incomplete data for an exhaustive answer.
		return toolOK(map[string]any{
			"after":    after.Format(time.RFC3339),
			"messages": msgs,
			"partial":  partial,
		}, "google_mail"), nil
	},
}

// googleReady enforces the consent + connection + scope gate shared by the
// Google read tools and returns a usable token set. Expired access tokens are
// refreshed (bounded, no redirects) when a usable refresh token exists; a
// rejected or impossible refresh surfaces reauthorization_required instead of
// silently returning empty data.
func (e *toolEnv) googleReady(ctx context.Context, scope string) (TokenSet, error) {
	if e.s.google == nil {
		return TokenSet{}, errors.New("google_not_configured")
	}
	profile, err := e.s.store.GetProfile(ctx, e.ident.ID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return TokenSet{}, errors.New("store_unavailable")
	}
	if !profile.AIContextConsent {
		return TokenSet{}, errors.New("consent_required")
	}
	st, err := e.s.store.GetTokens(ctx, e.ident.ID)
	if errors.Is(err, ErrNotFound) {
		return TokenSet{}, errors.New("google_not_connected")
	}
	if err != nil {
		return TokenSet{}, errors.New("store_unavailable")
	}
	tok, err := e.s.decryptTokens(e.ident.ID, st)
	if err != nil {
		return TokenSet{}, errors.New("token_unavailable")
	}
	if e.s.now().Add(time.Minute).After(tok.Expiry) {
		tok, err = e.refreshTokens(ctx, st, tok)
		if err != nil {
			return TokenSet{}, err
		}
	}
	if !tok.HasScope(scope) {
		return TokenSet{}, errors.New("missing_scope")
	}
	return tok, nil
}

// refreshTokens exchanges the refresh token and persists the result with a
// generation compare-and-commit so a racing disconnect can never be undone.
// The user's selected scope subset is preserved across rotation.
func (e *toolEnv) refreshTokens(ctx context.Context, st StoredTokens, tok TokenSet) (TokenSet, error) {
	if tok.RefreshToken == "" {
		return TokenSet{}, errors.New("reauthorization_required")
	}
	fresh, err := e.s.google.Refresh(ctx, tok)
	if err != nil {
		if errors.Is(err, errInvalidGrant) {
			return TokenSet{}, errors.New("reauthorization_required")
		}
		return TokenSet{}, errors.New("provider_unavailable")
	}
	if len(fresh.Scopes) == 0 {
		fresh.Scopes = tok.Scopes
	} else {
		fresh.Scopes = intersectScopes(fresh.Scopes, tok.Scopes)
	}
	fresh.GoogleEmail = tok.GoogleEmail
	accessEnc, err := e.s.crypto.SealToken(e.ident.ID, purposeAccess, []byte(fresh.AccessToken))
	if err != nil {
		return TokenSet{}, errors.New("token_unavailable")
	}
	refreshEnc, err := e.s.crypto.SealToken(e.ident.ID, purposeRefresh, []byte(fresh.RefreshToken))
	if err != nil {
		return TokenSet{}, errors.New("token_unavailable")
	}
	next := StoredTokens{
		AccessEnc:   accessEnc,
		RefreshEnc:  refreshEnc,
		TokenType:   tok.TokenType,
		Scopes:      fresh.Scopes,
		GoogleEmail: fresh.GoogleEmail,
		ExpiresAt:   fresh.Expiry,
		Generation:  st.Generation,
	}
	if next.TokenType == "" {
		next.TokenType = "Bearer"
	}
	if err := e.s.store.CommitTokens(ctx, e.ident.ID, st.Generation, next); err != nil {
		if errors.Is(err, ErrStaleConnection) {
			// The connection moved on while this refresh was in flight.
			if _, gerr := e.s.store.GetTokens(ctx, e.ident.ID); errors.Is(gerr, ErrNotFound) {
				return TokenSet{}, errors.New("google_not_connected")
			}
			// A reconnect (new OAuth connection) owns the tokens now; the
			// caller must retry against it. Never serve this stale refresh.
			return TokenSet{}, errors.New("connection_changed")
		}
		return TokenSet{}, errors.New("store_unavailable")
	}
	return fresh, nil
}

// ExecuteTool runs one registry tool for a verified identity. The error
// return is reserved for strict argument failures and unknown tool names;
// execution failures come back as ToolResult{status:"error"} with a clear
// sanitized code.
func (s *Server) ExecuteTool(ctx context.Context, ident Identity, name string, args json.RawMessage, forModel bool) (ToolResult, error) {
	t, ok := toolRegistry[name]
	if !ok {
		return ToolResult{}, errInvalidArgs
	}
	if s.store == nil {
		return toolErr("not_configured"), nil
	}
	e := &toolEnv{s: s, ident: ident, forModel: forModel}
	return t.run(ctx, e, args)
}
