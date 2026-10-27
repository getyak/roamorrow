package harness

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// captureDriver is a minimal database/sql driver that records every query,
// its bound arguments and transaction control (Begin/Commit/Rollback) so tests
// can prove: user-supplied values never enter SQL text, connection mutations
// run inside explicit transactions with a FOR UPDATE owner-row lock, and any
// failure rolls back instead of committing.
type captureDriver struct {
	mu        sync.Mutex
	calls     []capturedCall
	events    []string
	failMatch string // when non-empty, statements containing this fail
}

type capturedCall struct {
	query string
	args  []driver.NamedValue
}

func (d *captureDriver) record(query string, args []driver.NamedValue) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.calls = append(d.calls, capturedCall{query: query, args: args})
}

func (d *captureDriver) event(e string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.events = append(d.events, e)
}

func (d *captureDriver) shouldFail(query string) bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.failMatch != "" && strings.Contains(query, d.failMatch)
}

func (d *captureDriver) eventCount(e string) int {
	d.mu.Lock()
	defer d.mu.Unlock()
	n := 0
	for _, v := range d.events {
		if v == e {
			n++
		}
	}
	return n
}

type captureConn struct{ d *captureDriver }

func (c *captureConn) Prepare(q string) (driver.Stmt, error) { return &captureStmt{q: q, d: c.d}, nil }
func (c *captureConn) Close() error                          { return nil }
func (c *captureConn) Begin() (driver.Tx, error)             { return c.begin() }
func (c *captureConn) BeginTx(context.Context, driver.TxOptions) (driver.Tx, error) {
	return c.begin()
}

func (c *captureConn) begin() (driver.Tx, error) {
	c.d.event("begin")
	return &captureTx{d: c.d}, nil
}

func (c *captureConn) QueryContext(_ context.Context, q string, args []driver.NamedValue) (driver.Rows, error) {
	if c.d.shouldFail(q) {
		return nil, errors.New("capture: injected query failure")
	}
	c.d.record(q, args)
	// The owner-row lock read returns epoch 0 so mutations proceed.
	if strings.Contains(q, "SELECT generation FROM harness.user_generations") {
		return &fakeRows{cols: []string{"generation"}, rows: [][]driver.Value{{int64(0)}}}, nil
	}
	return &fakeRows{}, nil
}

func (c *captureConn) ExecContext(_ context.Context, q string, args []driver.NamedValue) (driver.Result, error) {
	if c.d.shouldFail(q) {
		return nil, errors.New("capture: injected exec failure")
	}
	c.d.record(q, args)
	return driver.RowsAffected(1), nil
}

type captureTx struct{ d *captureDriver }

func (t *captureTx) Commit() error {
	t.d.event("commit")
	return nil
}

func (t *captureTx) Rollback() error {
	t.d.event("rollback")
	return nil
}

type captureStmt struct {
	q string
	d *captureDriver
}

func (s *captureStmt) Close() error  { return nil }
func (s *captureStmt) NumInput() int { return -1 }
func (s *captureStmt) Exec(args []driver.Value) (driver.Result, error) {
	s.d.record(s.q, nil)
	return driver.RowsAffected(1), nil
}
func (s *captureStmt) Query(args []driver.Value) (driver.Rows, error) {
	s.d.record(s.q, nil)
	return &fakeRows{}, nil
}

type fakeRows struct {
	cols []string
	rows [][]driver.Value
	idx  int
}

func (r *fakeRows) Columns() []string { return r.cols }
func (r *fakeRows) Close() error      { return nil }
func (r *fakeRows) Next(dest []driver.Value) error {
	if r.idx >= len(r.rows) {
		return io.EOF
	}
	copy(dest, r.rows[r.idx])
	r.idx++
	return nil
}

type captureDriverFactory struct{ d *captureDriver }

func (f captureDriverFactory) Open(string) (driver.Conn, error) { return &captureConn{d: f.d}, nil }

func newCaptureDB(t *testing.T) (*captureDriver, *PostgresStore) {
	t.Helper()
	d := &captureDriver{}
	name := "harness-capture-" + strings.ReplaceAll(t.Name(), "/", "_")
	sql.Register(name, captureDriverFactory{d: d})
	db, err := sql.Open(name, "ignored")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return d, NewPostgresStore(db)
}

func TestPostgresStoreParameterizesAndScopesOwner(t *testing.T) {
	d, store := newCaptureDB(t)

	// Hostile-looking owner ids and state values must only ever travel as
	// bound arguments, never inside SQL text.
	hostileID := "user-1' OR '1'='1"
	hostileState := "state-1'; DROP TABLE harness.profiles;--"
	ctx := context.Background()

	_, _ = store.GetProfile(ctx, hostileID)
	_ = store.SaveProfile(ctx, Profile{UserID: hostileID, Email: "e@x.test", DisplayName: "N", HomeCity: "C"})
	_, _ = store.GetTokens(ctx, hostileID)
	_ = store.CommitTokens(ctx, hostileID, 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
	_ = store.ReplaceConnection(ctx, hostileID, 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
	_, _ = store.Disconnect(ctx, hostileID)
	_ = store.CreateState(ctx, StateRecord{State: hostileState, UserID: hostileID, VerifierEnc: []byte("v"), ExpiresAt: time.Now()})
	_, _ = store.ConsumeState(ctx, hostileState, time.Now())

	if len(d.calls) == 0 {
		t.Fatal("no queries captured")
	}
	for _, call := range d.calls {
		if strings.Contains(call.query, hostileID) || strings.Contains(call.query, hostileState) {
			t.Fatalf("user value embedded in SQL text: %q", call.query)
		}
		if strings.Contains(call.query, "e@x.test") {
			t.Fatalf("email embedded in SQL text: %q", call.query)
		}
		// Owner/state scoping: every statement filters by user_id or state.
		if !strings.Contains(call.query, "user_id") && !strings.Contains(call.query, "oauth_states") {
			t.Fatalf("statement not owner scoped: %q", call.query)
		}
		// Parameterized style.
		if strings.Contains(call.query, "'"+hostileID) || strings.Contains(call.query, "\""+hostileID) {
			t.Fatalf("quoting injection found: %q", call.query)
		}
	}
}

// TestPostgresStoreConnectionMutationsLockOwnerRow (B02/B01): every
// connection mutation is an explicit transaction that initializes the owner
// row and locks it FOR UPDATE; the broken data-modifying CTE is gone.
func TestPostgresStoreConnectionMutationsLockOwnerRow(t *testing.T) {
	d, store := newCaptureDB(t)
	ctx := context.Background()

	if err := store.CommitTokens(ctx, "user-a", 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()}); err != nil {
		t.Fatal(err)
	}
	if err := store.ReplaceConnection(ctx, "user-a", 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()}); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Disconnect(ctx, "user-a"); err != nil {
		t.Fatal(err)
	}
	if err := store.CreateState(ctx, StateRecord{State: "state-abcdefghijklmnop", UserID: "user-a", VerifierEnc: []byte("v"), ExpiresAt: time.Now()}); err != nil {
		t.Fatal(err)
	}

	begins, commits := d.eventCount("begin"), d.eventCount("commit")
	if begins != 4 || commits != 4 {
		t.Fatalf("expected 4 begin/commit pairs, got begin=%d commit=%d events=%v", begins, commits, d.events)
	}
	if d.eventCount("rollback") != 0 {
		t.Fatalf("successful mutations must not roll back: %v", d.events)
	}

	var sawLock, sawInitOwner, sawCTE bool
	var sawEpochAdvance, sawTokenDelete, sawStateCancel int
	for _, call := range d.calls {
		q := call.query
		if strings.Contains(q, "FOR UPDATE") {
			sawLock = true
		}
		if strings.Contains(q, "INSERT INTO harness.user_generations") && strings.Contains(q, "ON CONFLICT (user_id) DO NOTHING") {
			sawInitOwner = true
		}
		if strings.Contains(q, "WITH ") {
			sawCTE = true
		}
		if strings.Contains(q, "UPDATE harness.user_generations SET generation") {
			sawEpochAdvance++
		}
		if strings.Contains(q, "DELETE FROM harness.google_tokens") {
			sawTokenDelete++
		}
		if strings.Contains(q, "DELETE FROM harness.oauth_states") && strings.Contains(q, "used_at IS NULL") {
			sawStateCancel++
		}
	}
	if !sawInitOwner {
		t.Fatal("owner row must be initialized before locking")
	}
	if !sawLock {
		t.Fatal("connection mutations must lock the owner row FOR UPDATE")
	}
	if sawCTE {
		t.Fatal("data-modifying CTEs must be eliminated")
	}
	if sawEpochAdvance != 2 {
		t.Fatalf("ReplaceConnection and Disconnect must each advance the epoch once, got %d", sawEpochAdvance)
	}
	if sawTokenDelete != 1 {
		t.Fatalf("only Disconnect deletes tokens, got %d", sawTokenDelete)
	}
	if sawStateCancel < 2 {
		t.Fatalf("ReplaceConnection and Disconnect must cancel pending states, got %d", sawStateCancel)
	}
}

// TestPostgresStoreRollsBackOnFailure (B02): a failing statement inside the
// transaction rolls back and never commits.
func TestPostgresStoreRollsBackOnFailure(t *testing.T) {
	ctx := context.Background()

	t.Run("disconnect token delete fails", func(t *testing.T) {
		d, store := newCaptureDB(t)
		d.failMatch = "DELETE FROM harness.google_tokens"
		if _, err := store.Disconnect(ctx, "user-a"); err == nil {
			t.Fatal("injected failure must surface")
		}
		if d.eventCount("rollback") != 1 {
			t.Fatalf("expected rollback, events=%v", d.events)
		}
		if d.eventCount("commit") != 0 {
			t.Fatalf("failed transaction must not commit, events=%v", d.events)
		}
	})

	t.Run("replace connection insert fails", func(t *testing.T) {
		d, store := newCaptureDB(t)
		d.failMatch = "INSERT INTO harness.google_tokens"
		err := store.ReplaceConnection(ctx, "user-a", 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
		if err == nil {
			t.Fatal("injected failure must surface")
		}
		if d.eventCount("rollback") != 1 || d.eventCount("commit") != 0 {
			t.Fatalf("expected rollback without commit, events=%v", d.events)
		}
	})

	t.Run("owner lock fails", func(t *testing.T) {
		d, store := newCaptureDB(t)
		d.failMatch = "SELECT generation FROM harness.user_generations"
		err := store.CommitTokens(ctx, "user-a", 0, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
		if err == nil {
			t.Fatal("injected failure must surface")
		}
		if d.eventCount("rollback") != 1 || d.eventCount("commit") != 0 {
			t.Fatalf("expected rollback without commit, events=%v", d.events)
		}
	})
}

// TestPostgresStoreComparesEpochInTransaction (B01/B02): CommitTokens is an
// update-only CAS against the locked epoch and the connection row; a stale or
// missing connection is refused without writing.
func TestPostgresStoreComparesEpochInTransaction(t *testing.T) {
	d, store := newCaptureDB(t)
	ctx := context.Background()

	// Stale epoch (0) while the lock read reports epoch 0 -> succeeds only
	// because they match; force the mismatch by expecting epoch 7.
	err := store.CommitTokens(ctx, "user-a", 7, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
	if !errors.Is(err, ErrStaleConnection) {
		t.Fatalf("epoch mismatch must be ErrStaleConnection, got %v", err)
	}
	for _, call := range d.calls {
		if strings.Contains(call.query, "UPDATE harness.google_tokens") {
			t.Fatal("stale CommitTokens must not reach the token UPDATE")
		}
	}
	// ReplaceConnection with a stale state snapshot is refused too.
	err = store.ReplaceConnection(ctx, "user-a", 5, StoredTokens{AccessEnc: []byte("a"), RefreshEnc: []byte("r"), ExpiresAt: time.Now()})
	if !errors.Is(err, ErrStaleConnection) {
		t.Fatalf("stale ReplaceConnection must be ErrStaleConnection, got %v", err)
	}
}

// TestHarnessMigrationsAreIdempotent guards the migrate.Run contract: the
// runner re-executes every file on start, so all DDL must be IF NOT EXISTS
// and confined to the private harness schema.
func TestHarnessMigrationsAreIdempotent(t *testing.T) {
	dir := filepath.Join("..", "..", "migrations", "harness")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	files := 0
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		files++
		b, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			t.Fatal(err)
		}
		for _, line := range strings.Split(string(b), "\n") {
			up := strings.ToUpper(strings.TrimSpace(line))
			if strings.HasPrefix(up, "CREATE TABLE") && !strings.Contains(up, "IF NOT EXISTS") {
				t.Fatalf("%s: non-idempotent DDL: %s", e.Name(), line)
			}
			if strings.HasPrefix(up, "CREATE SCHEMA") && !strings.Contains(up, "IF NOT EXISTS") {
				t.Fatalf("%s: non-idempotent DDL: %s", e.Name(), line)
			}
			if strings.Contains(up, "CREATE TABLE") && !strings.Contains(strings.ToLower(line), "harness.") {
				t.Fatalf("%s: table outside private harness schema: %s", e.Name(), line)
			}
		}
	}
	if files == 0 {
		t.Fatal("no harness migrations found")
	}
}
