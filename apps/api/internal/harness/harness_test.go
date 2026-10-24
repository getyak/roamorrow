package harness

import (
	"context"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// memStore is an in-memory Store mirroring PostgresStore semantics (including
// one-use OAuth states and the connection-generation disconnect invariant) so
// tests never need a database, network or secrets.
type memStore struct {
	mu         sync.Mutex
	profiles   map[string]Profile
	tokens     map[string]StoredTokens
	states     map[string]stateRow
	generation map[string]int64
	now        func() time.Time
}

type stateRow struct {
	rec    StateRecord
	used   bool
	usedAt time.Time
}

func newMemStore() *memStore {
	return &memStore{
		profiles:   map[string]Profile{},
		tokens:     map[string]StoredTokens{},
		states:     map[string]stateRow{},
		generation: map[string]int64{},
		now:        time.Now,
	}
}

func (m *memStore) currentGen(userID string) int64 { return m.generation[userID] }

func (m *memStore) GetProfile(_ context.Context, userID string) (Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[userID]
	if !ok {
		return Profile{}, ErrNotFound
	}
	if p.Interests == nil {
		p.Interests = []string{}
	}
	return p, nil
}

func (m *memStore) SaveProfile(_ context.Context, p Profile) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if p.Interests == nil {
		p.Interests = []string{}
	}
	m.profiles[p.UserID] = p
	return nil
}

func (m *memStore) GetTokens(_ context.Context, userID string) (StoredTokens, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, ok := m.tokens[userID]
	if !ok {
		return StoredTokens{}, ErrNotFound
	}
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	return t, nil
}

func (m *memStore) CommitTokens(_ context.Context, userID string, generation int64, t StoredTokens) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	// Mirror SQL: owner row lock + require epoch == connection generation;
	// update only the existing connection row, never insert or advance.
	if m.generation[userID] != generation {
		return ErrStaleConnection
	}
	cur, ok := m.tokens[userID]
	if !ok || cur.Generation != generation {
		return ErrStaleConnection
	}
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	t.Generation = generation
	t.UpdatedAt = time.Now()
	m.tokens[userID] = t
	return nil
}

func (m *memStore) ReplaceConnection(_ context.Context, userID string, stateGeneration int64, t StoredTokens) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	// Mirror SQL: require state snapshot == current epoch, then advance the
	// epoch, persist tokens under the NEW epoch and cancel pending states.
	if m.generation[userID] != stateGeneration {
		return ErrStaleConnection
	}
	next := m.generation[userID] + 1
	m.generation[userID] = next
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	t.Generation = next
	t.UpdatedAt = time.Now()
	m.tokens[userID] = t
	for k, row := range m.states {
		if row.rec.UserID == userID && !row.used {
			delete(m.states, k)
		}
	}
	return nil
}

func (m *memStore) Disconnect(_ context.Context, userID string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.generation[userID] = m.generation[userID] + 1
	_, had := m.tokens[userID]
	delete(m.tokens, userID)
	for k, row := range m.states {
		if row.rec.UserID == userID && !row.used {
			delete(m.states, k)
		}
	}
	return had, nil
}

func (m *memStore) CreateState(_ context.Context, s StateRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	s.Generation = m.generation[s.UserID]
	m.states[s.State] = stateRow{rec: s}
	return nil
}

func (m *memStore) ConsumeState(_ context.Context, state string, now time.Time) (StateRecord, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	row, ok := m.states[state]
	if !ok {
		return StateRecord{}, ErrStateUnknown
	}
	if row.used {
		return StateRecord{}, ErrStateUsed
	}
	if !row.rec.ExpiresAt.After(now) {
		return StateRecord{}, ErrStateExpired
	}
	row.used = true
	row.usedAt = now
	m.states[state] = row
	return row.rec, nil
}

// --- fakes ----------------------------------------------------------------

type fakeVerifier struct {
	// tokens maps bearer token -> identity; anything else is rejected.
	tokens map[string]Identity
	calls  int
}

func (f *fakeVerifier) Verify(_ context.Context, bearer string) (Identity, error) {
	f.calls++
	id, ok := f.tokens[bearer]
	if !ok {
		return Identity{}, errFakeAuth
	}
	return id, nil
}

var errFakeAuth = errString("harness: auth verification failed")

type errString string

func (e errString) Error() string { return string(e) }

type fakeGoogle struct {
	mu sync.Mutex

	authURL  string
	exchange func(code, verifier string) (TokenSet, error)

	refreshFn    func(tok TokenSet) (TokenSet, error)
	refreshErr   error
	refreshCalls int

	email       string
	revokeOK    bool
	revokeCalls int

	events    []CalendarEvent
	eventsErr error

	mail          []MailMessage
	mailPartial   bool
	mailErr       error
	mailAttempts  int
	lastMailQuery string
	lastMailAfter time.Time

	lastWindowFrom, lastWindowTo time.Time
}

func (f *fakeGoogle) AuthorizationURL(state, challenge string, wantCalendar, wantMail bool) string {
	if f.authURL != "" {
		return f.authURL
	}
	scopes := []string{"openid", "email"}
	if wantCalendar {
		scopes = append(scopes, ScopeCalendarReadonly)
	}
	if wantMail {
		scopes = append(scopes, ScopeGmailReadonly)
	}
	q := url.Values{}
	q.Set("state", state)
	q.Set("code_challenge", challenge)
	q.Set("code_challenge_method", "S256")
	q.Set("scope", strings.Join(scopes, " "))
	return "https://accounts.example.test/auth?" + q.Encode()
}

func (f *fakeGoogle) ExchangeCode(_ context.Context, code, verifier string) (TokenSet, error) {
	f.mu.Lock()
	ex := f.exchange
	f.mu.Unlock()
	if ex != nil {
		return ex(code, verifier)
	}
	if code != "good-code" || verifier == "" {
		return TokenSet{}, errProvider
	}
	return TokenSet{
		AccessToken:  "access-" + code,
		RefreshToken: "refresh-" + code,
		TokenType:    "Bearer",
		Expiry:       time.Now().Add(time.Hour),
		Scopes:       []string{ScopeCalendarReadonly, ScopeGmailReadonly},
	}, nil
}

func (f *fakeGoogle) Refresh(_ context.Context, tok TokenSet) (TokenSet, error) {
	f.mu.Lock()
	f.refreshCalls++
	refresh, refreshErr := f.refreshFn, f.refreshErr
	f.mu.Unlock()
	// Hooks intentionally interleave another OAuth request. Holding the fake's
	// mutex here would deadlock that callback, unlike the real HTTP client.
	if refresh != nil {
		return refresh(tok)
	}
	if refreshErr != nil {
		return TokenSet{}, refreshErr
	}
	return TokenSet{
		AccessToken:  "refreshed-access",
		RefreshToken: tok.RefreshToken,
		TokenType:    "Bearer",
		Expiry:       time.Now().Add(time.Hour),
		Scopes:       []string{ScopeCalendarReadonly, ScopeGmailReadonly},
	}, nil
}

func (f *fakeGoogle) FetchGoogleEmail(_ context.Context, _ TokenSet) string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.email
}

func (f *fakeGoogle) Revoke(_ context.Context, _ TokenSet) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.revokeCalls++
	return f.revokeOK
}

func (f *fakeGoogle) ListCalendarEvents(_ context.Context, _ TokenSet, from, to time.Time) ([]CalendarEvent, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lastWindowFrom, f.lastWindowTo = from, to
	return f.events, f.eventsErr
}

func (f *fakeGoogle) SearchTravelMail(_ context.Context, _ TokenSet, query string, after time.Time) ([]MailMessage, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lastMailQuery = query
	f.lastMailAfter = after
	return f.mail, f.mailPartial, f.mailErr
}

// fakeDeepSeek scripts model rounds; each Chat call consumes one step.
type fakeDeepSeek struct {
	mu    sync.Mutex
	steps []ChatResponse
	calls int
	err   error
	reqs  []ChatRequest
}

func (f *fakeDeepSeek) Chat(_ context.Context, req ChatRequest) (ChatResponse, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.reqs = append(f.reqs, req)
	f.calls++
	if f.err != nil {
		return ChatResponse{}, f.err
	}
	if len(f.steps) == 0 {
		return ChatResponse{Content: "fallback reply"}, nil
	}
	step := f.steps[0]
	f.steps = f.steps[1:]
	return step, nil
}

// --- harness construction -------------------------------------------------

type testHarness struct {
	srv    *Server
	engine *gin.Engine
	store  *memStore
	verify *fakeVerifier
	google *fakeGoogle
	model  *fakeDeepSeek
	logs   *syncBuffer
}

type syncBuffer struct {
	mu sync.Mutex
	b  []byte
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.b = append(s.b, p...)
	return len(p), nil
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return string(s.b)
}

var testKey = []byte("0123456789abcdef0123456789abcdef")

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	gin.SetMode(gin.TestMode)
	cfg := Config{
		SupabaseURL:        "https://supabase.example.test",
		SupabaseAnonKey:    "anon-key",
		GoogleClientID:     "client-id",
		GoogleClientSecret: "client-secret",
		GoogleRedirectURI:  "https://harness.example.test/v1/harness/google/callback",
		TokenKey:           testKey,
		DeepSeekAPIKey:     "ds-key",
		DeepSeekBaseURL:    "https://deepseek.example.test/v1",
		AllowedOrigins:     []string{"https://smile-m4-minimac-mini.tail25e61f.ts.net:18443"},
		RatePerMin:         60,
		MaxConcurrentUser:  4,
		MaxConcurrentTotal: 16,
	}
	store := newMemStore()
	srv := NewServer(cfg, store)
	fv := &fakeVerifier{tokens: map[string]Identity{}}
	fg := &fakeGoogle{}
	fd := &fakeDeepSeek{}
	srv.verifier = fv
	srv.google = fg
	srv.deepseek = fd

	engine := gin.New()
	logs := &syncBuffer{}
	engine.Use(NewLogger(logs), NewRecovery(logs))
	srv.Register(engine)

	return &testHarness{
		srv: srv, engine: engine, store: store,
		verify: fv, google: fg, model: fd, logs: logs,
	}
}

// auth adds a verified identity behind a bearer token.
func (h *testHarness) auth(token, userID, email string) {
	h.verify.tokens[token] = Identity{ID: userID, Email: email}
}

// seedTokens installs an OAuth connection via ReplaceConnection (the same
// path the callback uses), leaving the owner at the resulting epoch.
func (h *testHarness) seedTokens(t *testing.T, userID string, scopes []string) {
	t.Helper()
	access, err := h.srv.crypto.SealToken(userID, purposeAccess, []byte("access-token-value"))
	if err != nil {
		t.Fatal(err)
	}
	refresh, err := h.srv.crypto.SealToken(userID, purposeRefresh, []byte("refresh-token-value"))
	if err != nil {
		t.Fatal(err)
	}
	err = h.store.ReplaceConnection(context.Background(), userID, h.store.currentGen(userID), StoredTokens{
		AccessEnc: access, RefreshEnc: refresh, TokenType: "Bearer",
		Scopes: scopes, GoogleEmail: "traveler@example.test",
		ExpiresAt: time.Now().Add(time.Hour),
	})
	if err != nil {
		t.Fatal(err)
	}
}
