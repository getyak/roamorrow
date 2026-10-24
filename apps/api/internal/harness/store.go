package harness

import (
	"context"
	"errors"
	"time"
)

// Store errors. Handlers map these to sanitized responses; callers never see
// SQL details.
var (
	ErrNotFound     = errors.New("harness: not found")
	ErrStateUnknown = errors.New("harness: oauth state unknown")
	ErrStateUsed    = errors.New("harness: oauth state already used")
	ErrStateExpired = errors.New("harness: oauth state expired")
	// ErrStaleConnection means the connection generation moved on (the user
	// disconnected) while this operation was in flight: the write is refused
	// and revoked state can never be restored by a late callback or refresh.
	ErrStaleConnection = errors.New("harness: connection generation stale")
)

// Profile is the owner-scoped, user-editable profile. Email/UserID are always
// taken from verified auth, never from request bodies.
type Profile struct {
	UserID           string
	Email            string
	DisplayName      string
	HomeCity         string
	Interests        []string
	AIContextConsent bool
}

// StoredTokens holds AES-GCM ciphertext for Google tokens plus non-secret
// metadata. Plaintext tokens never reach the database layer. Generation is
// the connection generation the tokens belong to; commits with a stale
// generation are refused.
type StoredTokens struct {
	AccessEnc   []byte
	RefreshEnc  []byte
	TokenType   string
	Scopes      []string
	GoogleEmail string
	ExpiresAt   time.Time
	Generation  int64
	UpdatedAt   time.Time
}

// StateRecord is a one-use, expiring Google OAuth state bound to the user who
// started the flow (and to the PKCE verifier). Generation snapshots the
// connection epoch at start time; ReplaceConnection requires it to still be
// current when the callback lands.
type StateRecord struct {
	State        string
	UserID       string
	Generation   int64
	VerifierEnc  []byte
	WantCalendar bool
	WantMail     bool
	ExpiresAt    time.Time
}

// Store is the owner-scoped persistence interface. Every method is keyed by
// the verified user id; implementations must never widen that scope. All
// connection mutations (CreateState, CommitTokens, ReplaceConnection,
// Disconnect) run inside an explicit database transaction that initializes
// the owner row and takes `SELECT generation ... FOR UPDATE` on that same
// row, so concurrency is decided by the database — never process memory.
// The generation ("epoch") advances on every connect and disconnect; token
// commits are compare-and-set against it and roll back on every failure.
type Store interface {
	// GetProfile returns the stored profile or ErrNotFound (caller then uses
	// identity-derived defaults).
	GetProfile(ctx context.Context, userID string) (Profile, error)
	// SaveProfile fully replaces the editable fields for userID.
	SaveProfile(ctx context.Context, p Profile) error

	GetTokens(ctx context.Context, userID string) (StoredTokens, error)
	// CommitTokens persists REFRESHED tokens for an existing connection only:
	// under the owner row lock the current epoch must equal the connection's
	// token generation and the token row must still carry that generation.
	// It never inserts a new connection and never changes the epoch. A
	// reconnect or disconnect while the refresh was in flight yields
	// ErrStaleConnection and rolls back.
	CommitTokens(ctx context.Context, userID string, generation int64, t StoredTokens) error
	// ReplaceConnection installs a fresh OAuth connection (callback path).
	// Under the owner row lock the state's generation snapshot must equal the
	// current epoch; the epoch then ADVANCES and the tokens are persisted
	// under the NEW epoch. Every other pending OAuth state is cancelled in the
	// same transaction, so a stale callback or an older broad-scope refresh
	// can never overwrite this connection. Mismatch yields ErrStaleConnection.
	ReplaceConnection(ctx context.Context, userID string, stateGeneration int64, t StoredTokens) error
	// Disconnect locks the owner row, advances the epoch, erases local tokens
	// and cancels every pending (unused) OAuth state, all in one transaction.
	// Any in-flight exchange/refresh holding the old epoch fails its
	// compare afterwards. Reports whether tokens existed.
	Disconnect(ctx context.Context, userID string) (hadTokens bool, err error)

	// CreateState stores a one-use state whose generation snapshot is read
	// under the owner row lock.
	CreateState(ctx context.Context, s StateRecord) error
	// ConsumeState atomically marks the state used (one-use) and returns it
	// including its generation snapshot. Replay yields ErrStateUsed, age-out
	// yields ErrStateExpired.
	ConsumeState(ctx context.Context, state string, now time.Time) (StateRecord, error)
}
