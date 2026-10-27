package harness

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// maxAuthBody bounds the Supabase /auth/v1/user response we will read.
const maxAuthBody = int64(64 << 10)

// Identity is the verified auth subject. ID is the Supabase user id (JWT
// `sub`); every owner-scoped query uses it. Nothing a client sends in a body
// or query can override it.
type Identity struct {
	ID    string
	Email string
}

// ErrAuthUnavailable marks missing auth configuration (visible as 503, not
// an opaque 401).
var ErrAuthUnavailable = errors.New("harness: auth not configured")

// Verifier validates Supabase bearer tokens.
type Verifier interface {
	Verify(ctx context.Context, bearer string) (Identity, error)
}

// SupabaseVerifier verifies bearer tokens with GET /auth/v1/user against the
// project's own Supabase Auth instance. Anonymous and unverified-email users
// are rejected. Redirects are disabled on this token-bearing client.
type SupabaseVerifier struct {
	baseURL string
	anonKey string
	client  *http.Client
}

// NewSupabaseVerifier builds a verifier; it returns nil when unconfigured.
func NewSupabaseVerifier(baseURL, anonKey string) *SupabaseVerifier {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" || strings.TrimSpace(anonKey) == "" {
		return nil
	}
	return &SupabaseVerifier{
		baseURL: baseURL,
		anonKey: anonKey,
		client:  noRedirectClient(8 * time.Second),
	}
}

// supabaseUser is the subset of the GoTrue /auth/v1/user payload we consume.
type supabaseUser struct {
	ID               string `json:"id"`
	Email            string `json:"email"`
	EmailConfirmedAt string `json:"email_confirmed_at"`
	IsAnonymous      bool   `json:"is_anonymous"`
	Identities       []struct {
		Provider string `json:"provider"`
	} `json:"identities"`
}

// Verify resolves the bearer token to a verified, non-anonymous identity.
// All failures return a generic error; tokens and upstream bodies are never
// echoed into errors or logs.
func (v *SupabaseVerifier) Verify(ctx context.Context, bearer string) (Identity, error) {
	if v == nil {
		return Identity{}, ErrAuthUnavailable
	}
	bearer = strings.TrimSpace(bearer)
	if bearer == "" {
		return Identity{}, errors.New("harness: empty bearer token")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.baseURL+"/auth/v1/user", nil)
	if err != nil {
		return Identity{}, errors.New("harness: auth request build failed")
	}
	req.Header.Set("Authorization", "Bearer "+bearer)
	req.Header.Set("apikey", v.anonKey)
	req.Header.Set("Accept", "application/json")

	resp, err := v.client.Do(req)
	if err != nil {
		return Identity{}, errors.New("harness: auth verification failed")
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxAuthBody))
	if err != nil {
		return Identity{}, errors.New("harness: auth verification failed")
	}
	if resp.StatusCode != http.StatusOK {
		return Identity{}, errors.New("harness: auth verification failed")
	}
	var u supabaseUser
	if err := json.Unmarshal(body, &u); err != nil {
		return Identity{}, errors.New("harness: auth verification failed")
	}
	if u.ID == "" || u.Email == "" || u.EmailConfirmedAt == "" {
		return Identity{}, errors.New("harness: identity not verified")
	}
	if u.IsAnonymous {
		return Identity{}, errors.New("harness: anonymous identity rejected")
	}
	linked := false
	for _, id := range u.Identities {
		if id.Provider != "" && id.Provider != "anonymous" {
			linked = true
			break
		}
	}
	if !linked {
		return Identity{}, errors.New("harness: anonymous identity rejected")
	}
	return Identity{ID: u.ID, Email: u.Email}, nil
}

const identityKey = "harness.identity"

// IdentityFrom returns the verified identity stored by AuthMiddleware.
func IdentityFrom(c *gin.Context) (Identity, bool) {
	v, ok := c.Get(identityKey)
	if !ok {
		return Identity{}, false
	}
	id, ok := v.(Identity)
	return id, ok
}

// AuthMiddleware enforces a verified Supabase identity on protected routes.
func (s *Server) AuthMiddleware(c *gin.Context) {
	if s.verifier == nil {
		// Missing auth config is a visible 503, never a panic on a nil
		// interface and never a silent bypass.
		c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "auth not configured"})
		return
	}
	h := c.GetHeader("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(h, prefix) || len(strings.TrimSpace(h[len(prefix):])) == 0 {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	tok := strings.TrimSpace(h[len(prefix):])
	ident, err := s.verifier.Verify(c.Request.Context(), tok)
	if err != nil {
		if errors.Is(err, ErrAuthUnavailable) {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "auth not configured"})
			return
		}
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	c.Set(identityKey, ident)
	c.Next()
}

// noRedirectClient returns an HTTP client that aborts on any redirect so a
// bearer token / auth code can never be forwarded to another host.
func noRedirectClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return fmt.Errorf("harness: redirects disabled")
		},
	}
}
