package harness

// Opt-in real PostgreSQL acceptance. Never points at a shared/production DB:
// the parent runs this binary inside the dedicated harness Compose network.
import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"
)

func TestPostgresLiveHarness(t *testing.T) {
	dsn := os.Getenv("HARNESS_INTEGRATION_DATABASE_URL")
	if dsn == "" {
		t.Skip("requires the dedicated private harness test database")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal("invalid integration database configuration")
	}
	t.Cleanup(func() { _ = db.Close() })
	db.SetMaxOpenConns(6)
	if err := db.PingContext(ctx); err != nil {
		t.Fatal("integration database unavailable")
	}
	store := NewPostgresStore(db)
	prefix := fmt.Sprintf("harness-live-%d-", time.Now().UnixNano())
	owner := func(name string) string {
		id := prefix + name
		t.Cleanup(func() {
			cleanupCtx, done := context.WithTimeout(context.Background(), 5*time.Second)
			defer done()
			for _, table := range []string{"oauth_states", "google_tokens", "profiles", "user_generations"} {
				// table names are fixed above; the only fixture data is bound.
				if _, err := db.ExecContext(cleanupCtx, "DELETE FROM harness."+table+" WHERE user_id=$1", id); err != nil {
					t.Error("failed to remove this test's synthetic fixture")
				}
			}
		})
		return id
	}
	tokens := func(email string, scopes ...string) StoredTokens {
		return StoredTokens{AccessEnc: []byte("synthetic-ciphertext"), RefreshEnc: []byte("synthetic-refresh-ciphertext"),
			TokenType: "Bearer", Scopes: scopes, GoogleEmail: email, ExpiresAt: time.Now().Add(time.Hour)}
	}

	t.Run("profile_owner_isolation", func(t *testing.T) {
		a, b := owner("profile-a"), owner("profile-b' OR 1=1 --")
		for _, p := range []Profile{{UserID: a, Email: "a@example.invalid", DisplayName: "A", Interests: []string{"walk"}},
			{UserID: b, Email: "b@example.invalid", DisplayName: "B", Interests: []string{"food"}}} {
			if err := store.SaveProfile(ctx, p); err != nil {
				t.Fatal(err)
			}
		}
		for _, pair := range [][2]string{{a, "A"}, {b, "B"}} {
			got, err := store.GetProfile(ctx, pair[0])
			if err != nil || got.DisplayName != pair[1] || got.UserID != pair[0] {
				t.Fatal("profile crossed owner boundary", err)
			}
		}
		if _, err := store.GetProfile(ctx, prefix+"unknown"); !errors.Is(err, ErrNotFound) {
			t.Fatal("unknown owner saw profile", err)
		}
	})

	t.Run("state_one_use_and_real_disconnect", func(t *testing.T) {
		u := owner("disconnect")
		st := StateRecord{State: prefix + "one-use", UserID: u, VerifierEnc: []byte("synthetic-verifier"),
			WantCalendar: true, ExpiresAt: time.Now().Add(time.Minute)}
		if err := store.CreateState(ctx, st); err != nil {
			t.Fatal(err)
		}
		if _, err := store.ConsumeState(ctx, st.State, time.Now()); err != nil {
			t.Fatal(err)
		}
		if _, err := store.ConsumeState(ctx, st.State, time.Now()); !errors.Is(err, ErrStateUsed) {
			t.Fatal("state replay accepted", err)
		}
		if err := store.ReplaceConnection(ctx, u, 0, tokens("old@example.invalid", ScopeCalendarReadonly)); err != nil {
			t.Fatal(err)
		}
		old, err := store.GetTokens(ctx, u)
		if err != nil {
			t.Fatal(err)
		}
		st.State = prefix + "pending"
		if err := store.CreateState(ctx, st); err != nil {
			t.Fatal(err)
		}
		had, err := store.Disconnect(ctx, u)
		if err != nil || !had {
			t.Fatal("real SQL disconnect failed", err)
		}
		if _, err := store.GetTokens(ctx, u); !errors.Is(err, ErrNotFound) {
			t.Fatal("disconnect retained tokens", err)
		}
		if _, err := store.ConsumeState(ctx, st.State, time.Now()); !errors.Is(err, ErrStateUnknown) {
			t.Fatal("pending state survived disconnect", err)
		}
		if err := store.CommitTokens(ctx, u, old.Generation, old); !errors.Is(err, ErrStaleConnection) {
			t.Fatal("late refresh revived disconnected connection", err)
		}
	})

	t.Run("new_connection_rejects_old_broad_refresh", func(t *testing.T) {
		u := owner("reconnect")
		if err := store.ReplaceConnection(ctx, u, 0, tokens("old@example.invalid", ScopeCalendarReadonly, ScopeGmailReadonly)); err != nil {
			t.Fatal(err)
		}
		old, err := store.GetTokens(ctx, u)
		if err != nil {
			t.Fatal(err)
		}
		if err := store.ReplaceConnection(ctx, u, old.Generation, tokens("new@example.invalid", ScopeCalendarReadonly)); err != nil {
			t.Fatal(err)
		}
		if err := store.CommitTokens(ctx, u, old.Generation, old); !errors.Is(err, ErrStaleConnection) {
			t.Fatal("old refresh overwrote reconnect", err)
		}
		got, err := store.GetTokens(ctx, u)
		if err != nil || got.GoogleEmail != "new@example.invalid" || len(got.Scopes) != 1 || got.Scopes[0] != ScopeCalendarReadonly {
			t.Fatal("new connection widened or changed identity", err)
		}
	})

	t.Run("late_commit_waits_and_rechecks_revoked_epoch", func(t *testing.T) {
		u := owner("concurrent-revoke")
		if err := store.ReplaceConnection(ctx, u, 0, tokens("old@example.invalid", ScopeGmailReadonly)); err != nil {
			t.Fatal(err)
		}
		old, err := store.GetTokens(ctx, u)
		if err != nil {
			t.Fatal(err)
		}
		// Hold an uncommitted revocation while a stale writer arrives. This
		// reproduces the MVCC interleaving that fake stores cannot exercise.
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			t.Fatal(err)
		}
		defer tx.Rollback()
		if _, err := tx.ExecContext(ctx, "UPDATE harness.user_generations SET generation=generation+1 WHERE user_id=$1", u); err != nil {
			t.Fatal(err)
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM harness.google_tokens WHERE user_id=$1", u); err != nil {
			t.Fatal(err)
		}
		writer, err := sql.Open("postgres", dsn)
		if err != nil {
			t.Fatal(err)
		}
		defer writer.Close()
		writer.SetMaxOpenConns(1)
		var pid int
		if err := writer.QueryRowContext(ctx, "SELECT pg_backend_pid()").Scan(&pid); err != nil {
			t.Fatal(err)
		}
		result := make(chan error, 1)
		go func() { result <- NewPostgresStore(writer).CommitTokens(ctx, u, old.Generation, old) }()
		deadline := time.Now().Add(5 * time.Second)
		waiting := false
		for time.Now().Before(deadline) {
			var event sql.NullString
			if err := db.QueryRowContext(ctx, "SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1", pid).Scan(&event); err != nil {
				t.Fatal(err)
			}
			if event.String == "Lock" {
				waiting = true
				break
			}
			select {
			case err := <-result:
				t.Fatal("writer completed before revocation committed", err)
			default:
			}
			time.Sleep(10 * time.Millisecond)
		}
		if !waiting {
			t.Fatal("did not observe the intended concurrent database interleaving")
		}
		if err := tx.Commit(); err != nil {
			t.Fatal(err)
		}
		select {
		case err := <-result:
			if !errors.Is(err, ErrStaleConnection) {
				t.Fatal("stale writer persisted after revocation", err)
			}
		case <-ctx.Done():
			t.Fatal("late writer did not finish")
		}
		if _, err := store.GetTokens(ctx, u); !errors.Is(err, ErrNotFound) {
			t.Fatal("stale tokens reappeared", err)
		}
	})
}
