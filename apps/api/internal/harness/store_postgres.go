package harness

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	_ "github.com/lib/pq"
)

// PostgresStore is the lib/pq-backed owner-scoped store. Every statement is
// parameterized and filtered by user_id (or the unguessable one-use state),
// and the disconnect-wins invariant is enforced with atomic SQL.
type PostgresStore struct {
	db *sql.DB
}

// NewPostgresStore wraps an open database handle.
func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

// OpenHarnessDB opens and pings the harness database. Empty DSN is a visible,
// non-fatal missing-config error.
func OpenHarnessDB(dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, errors.New("harness: HARNESS_DATABASE_URL not configured")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func (s *PostgresStore) GetProfile(ctx context.Context, userID string) (Profile, error) {
	var (
		p     = Profile{UserID: userID}
		intr  string
		email string
	)
	err := s.db.QueryRowContext(ctx, `
		SELECT email, display_name, home_city, interests::text, ai_context_consent
		FROM harness.profiles WHERE user_id = $1`, userID).
		Scan(&email, &p.DisplayName, &p.HomeCity, &intr, &p.AIContextConsent)
	if errors.Is(err, sql.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, fmt.Errorf("harness: get profile: %w", err)
	}
	p.Email = email
	if err := json.Unmarshal([]byte(intr), &p.Interests); err != nil {
		return Profile{}, fmt.Errorf("harness: decode interests: %w", err)
	}
	if p.Interests == nil {
		p.Interests = []string{}
	}
	return p, nil
}

func (s *PostgresStore) SaveProfile(ctx context.Context, p Profile) error {
	if p.Interests == nil {
		p.Interests = []string{}
	}
	intr, err := json.Marshal(p.Interests)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO harness.profiles (user_id, email, display_name, home_city, interests, ai_context_consent, updated_at)
		VALUES ($1, $2, $3, $4, $5::jsonb, $6, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			email = EXCLUDED.email,
			display_name = EXCLUDED.display_name,
			home_city = EXCLUDED.home_city,
			interests = EXCLUDED.interests,
			ai_context_consent = EXCLUDED.ai_context_consent,
			updated_at = NOW()`,
		p.UserID, p.Email, p.DisplayName, p.HomeCity, string(intr), p.AIContextConsent)
	if err != nil {
		return fmt.Errorf("harness: save profile: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetTokens(ctx context.Context, userID string) (StoredTokens, error) {
	var (
		t    StoredTokens
		sc   string
		tokT string
	)
	err := s.db.QueryRowContext(ctx, `
		SELECT access_enc, refresh_enc, token_type, scopes::text, google_email, expires_at, generation, updated_at
		FROM harness.google_tokens WHERE user_id = $1`, userID).
		Scan(&t.AccessEnc, &t.RefreshEnc, &tokT, &sc, &t.GoogleEmail, &t.ExpiresAt, &t.Generation, &t.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return StoredTokens{}, ErrNotFound
	}
	if err != nil {
		return StoredTokens{}, fmt.Errorf("harness: get tokens: %w", err)
	}
	t.TokenType = tokT
	if err := json.Unmarshal([]byte(sc), &t.Scopes); err != nil {
		return StoredTokens{}, fmt.Errorf("harness: decode scopes: %w", err)
	}
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	return t, nil
}

// withOwnerLock runs fn inside an explicit transaction: it first initializes
// the owner generation row (INSERT ... ON CONFLICT DO NOTHING), then takes
// `SELECT generation ... FOR UPDATE` on that same row so every connection
// mutation serializes on the owner row in the database itself. Any error
// rolls the transaction back; only success commits.
func (s *PostgresStore) withOwnerLock(ctx context.Context, userID string, fn func(tx *sql.Tx, epoch int64) error) (err error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("harness: begin: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()
	if _, err = tx.ExecContext(ctx,
		`INSERT INTO harness.user_generations (user_id, generation) VALUES ($1, 0) ON CONFLICT (user_id) DO NOTHING`,
		userID); err != nil {
		return fmt.Errorf("harness: init owner: %w", err)
	}
	var epoch int64
	if err = tx.QueryRowContext(ctx,
		`SELECT generation FROM harness.user_generations WHERE user_id = $1 FOR UPDATE`,
		userID).Scan(&epoch); err != nil {
		return fmt.Errorf("harness: lock owner: %w", err)
	}
	if err = fn(tx, epoch); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("harness: commit: %w", err)
	}
	return nil
}

// CommitTokens persists refreshed tokens for an existing connection only.
// Under the owner row lock the current epoch must equal the connection's
// token generation and the UPDATE targets only that connection row (no
// insert, no epoch change). Stale work yields ErrStaleConnection.
func (s *PostgresStore) CommitTokens(ctx context.Context, userID string, generation int64, t StoredTokens) error {
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	sc, err := json.Marshal(t.Scopes)
	if err != nil {
		return err
	}
	return s.withOwnerLock(ctx, userID, func(tx *sql.Tx, epoch int64) error {
		if epoch != generation {
			return ErrStaleConnection
		}
		res, err := tx.ExecContext(ctx, `
			UPDATE harness.google_tokens
			SET access_enc = $2, refresh_enc = $3, token_type = $4, scopes = $5::jsonb,
			    google_email = $6, expires_at = $7, updated_at = NOW()
			WHERE user_id = $1 AND generation = $8`,
			userID, t.AccessEnc, t.RefreshEnc, t.TokenType, string(sc), t.GoogleEmail, t.ExpiresAt, generation)
		if err != nil {
			return fmt.Errorf("harness: commit tokens: %w", err)
		}
		n, err := res.RowsAffected()
		if err != nil {
			return fmt.Errorf("harness: commit tokens: %w", err)
		}
		if n == 0 {
			return ErrStaleConnection
		}
		return nil
	})
}

// ReplaceConnection installs a fresh OAuth connection (callback path). Under
// the owner row lock the state's generation snapshot must equal the current
// epoch; the epoch then advances and the tokens are persisted under the NEW
// epoch. Every other pending state is cancelled in the same transaction, so a
// stale callback or an older in-flight refresh can never win afterwards.
func (s *PostgresStore) ReplaceConnection(ctx context.Context, userID string, stateGeneration int64, t StoredTokens) error {
	if t.Scopes == nil {
		t.Scopes = []string{}
	}
	sc, err := json.Marshal(t.Scopes)
	if err != nil {
		return err
	}
	return s.withOwnerLock(ctx, userID, func(tx *sql.Tx, epoch int64) error {
		if epoch != stateGeneration {
			return ErrStaleConnection
		}
		next := epoch + 1
		if _, err := tx.ExecContext(ctx,
			`UPDATE harness.user_generations SET generation = $2, updated_at = NOW() WHERE user_id = $1`,
			userID, next); err != nil {
			return fmt.Errorf("harness: replace connection: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO harness.google_tokens
				(user_id, access_enc, refresh_enc, token_type, scopes, google_email, expires_at, generation, updated_at)
			VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, NOW())
			ON CONFLICT (user_id) DO UPDATE SET
				access_enc = EXCLUDED.access_enc,
				refresh_enc = EXCLUDED.refresh_enc,
				token_type = EXCLUDED.token_type,
				scopes = EXCLUDED.scopes,
				google_email = EXCLUDED.google_email,
				expires_at = EXCLUDED.expires_at,
				generation = EXCLUDED.generation,
				updated_at = NOW()`,
			userID, t.AccessEnc, t.RefreshEnc, t.TokenType, string(sc), t.GoogleEmail, t.ExpiresAt, next); err != nil {
			return fmt.Errorf("harness: replace connection: %w", err)
		}
		// Cancel every other pending state: they were minted under older
		// epochs and must never commit against this connection.
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM harness.oauth_states WHERE user_id = $1 AND used_at IS NULL`,
			userID); err != nil {
			return fmt.Errorf("harness: replace connection: %w", err)
		}
		return nil
	})
}

// Disconnect locks the owner row, advances the epoch, erases local tokens and
// cancels every pending unused OAuth state in one transaction. In-flight
// exchanges/refreshes holding the old epoch fail their compare afterwards.
func (s *PostgresStore) Disconnect(ctx context.Context, userID string) (bool, error) {
	hadTokens := false
	err := s.withOwnerLock(ctx, userID, func(tx *sql.Tx, epoch int64) error {
		next := epoch + 1
		if _, err := tx.ExecContext(ctx,
			`UPDATE harness.user_generations SET generation = $2, updated_at = NOW() WHERE user_id = $1`,
			userID, next); err != nil {
			return fmt.Errorf("harness: disconnect: %w", err)
		}
		res, err := tx.ExecContext(ctx,
			`DELETE FROM harness.google_tokens WHERE user_id = $1`, userID)
		if err != nil {
			return fmt.Errorf("harness: disconnect: %w", err)
		}
		n, err := res.RowsAffected()
		if err != nil {
			return fmt.Errorf("harness: disconnect: %w", err)
		}
		hadTokens = n > 0
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM harness.oauth_states WHERE user_id = $1 AND used_at IS NULL`,
			userID); err != nil {
			return fmt.Errorf("harness: disconnect: %w", err)
		}
		return nil
	})
	if err != nil {
		return false, err
	}
	return hadTokens, nil
}

// CreateState stores a one-use state whose generation snapshot is read under
// the owner row lock, so it always reflects the epoch current at start.
func (s *PostgresStore) CreateState(ctx context.Context, st StateRecord) error {
	return s.withOwnerLock(ctx, st.UserID, func(tx *sql.Tx, epoch int64) error {
		// Opportunistic cleanup of long-expired states keeps the table bounded.
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM harness.oauth_states WHERE expires_at < NOW() - interval '1 day'`); err != nil {
			return fmt.Errorf("harness: purge oauth states: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO harness.oauth_states
				(state, user_id, generation, verifier_enc, want_calendar, want_mail, expires_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			st.State, st.UserID, epoch, st.VerifierEnc, st.WantCalendar, st.WantMail, st.ExpiresAt); err != nil {
			return fmt.Errorf("harness: create oauth state: %w", err)
		}
		return nil
	})
}

func (s *PostgresStore) ConsumeState(ctx context.Context, state string, now time.Time) (StateRecord, error) {
	var (
		rec StateRecord
		ver []byte
	)
	rec.State = state
	err := s.db.QueryRowContext(ctx, `
		UPDATE harness.oauth_states
		SET used_at = NOW()
		WHERE state = $1 AND used_at IS NULL AND expires_at > $2
		RETURNING user_id, generation, verifier_enc, want_calendar, want_mail, expires_at`,
		state, now).
		Scan(&rec.UserID, &rec.Generation, &ver, &rec.WantCalendar, &rec.WantMail, &rec.ExpiresAt)
	if err == nil {
		rec.VerifierEnc = ver
		return rec, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return StateRecord{}, fmt.Errorf("harness: consume oauth state: %w", err)
	}
	// Distinguish replay / expiry / unknown for honest error reporting.
	var usedAt sql.NullTime
	var expires time.Time
	err = s.db.QueryRowContext(ctx,
		`SELECT used_at, expires_at FROM harness.oauth_states WHERE state = $1`, state).
		Scan(&usedAt, &expires)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		return StateRecord{}, ErrStateUnknown
	case err != nil:
		return StateRecord{}, fmt.Errorf("harness: consume oauth state: %w", err)
	case usedAt.Valid:
		return StateRecord{}, ErrStateUsed
	case !expires.After(now):
		return StateRecord{}, ErrStateExpired
	default:
		return StateRecord{}, ErrStateUnknown
	}
}
