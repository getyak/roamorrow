package harness

import (
	"encoding/base64"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	// ChatModel is the server-owned DeepSeek model for the harness chat loop.
	// Clients can never select a model; the wire contract freezes this id.
	ChatModel = "deepseek-flash"

	defaultDeepSeekBaseURL = "https://api.deepseek.com/v1"

	// MaxChatRounds bounds DeepSeek model rounds in one /chat request.
	MaxChatRounds = 4
	// MaxToolCallsPerChat bounds total tool executions in one /chat request.
	MaxToolCallsPerChat = 6

	googleAuthURL      = "https://accounts.google.com/o/oauth2/v2/auth"
	googleTokenURL     = "https://oauth2.googleapis.com/token"
	googleRevokeURL    = "https://oauth2.googleapis.com/revoke"
	googleUserInfoURL  = "https://openidconnect.googleapis.com/v1/userinfo"
	googleCalendarURL  = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
	googleGmailListURL = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
	googleGmailGetURL  = "https://gmail.googleapis.com/gmail/v1/users/me/messages/"

	// stateTTL bounds the one-use Google OAuth state lifetime.
	stateTTL = 10 * time.Minute

	maxBodyJSON = int64(32 << 10) // 32 KiB for JSON request bodies
)

// Config is the harness runtime configuration. Optional sections stay
// disabled (visible via GET /v1/harness/capabilities) instead of failing
// startup when their environment variables are missing.
type Config struct {
	SupabaseURL        string
	SupabaseAnonKey    string
	GoogleClientID     string
	GoogleClientSecret string
	GoogleRedirectURI  string
	TokenKey           []byte // AES-256 key for provider token encryption
	DeepSeekAPIKey     string
	DeepSeekBaseURL    string
	DatabaseDSN        string
	MigrationsDir      string
	AllowedOrigins     []string
	RatePerMin         int
	MaxConcurrentUser  int
	MaxConcurrentTotal int

	// Upstream endpoints (overridable in tests; fixed in production).
	GoogleAuthURL     string
	GoogleTokenURL    string
	GoogleRevokeURL   string
	GoogleUserInfoURL string
	GoogleCalendarURL string
	GoogleGmailList   string
	GoogleGmailGet    string
}

// LoadConfig reads the harness configuration from the environment.
// HARNESS_TOKEN_KEY must be a base64-encoded 32-byte AES key when present;
// malformed values are a hard startup error (never silently ignored).
func LoadConfig() (Config, error) {
	cfg := Config{
		SupabaseURL:        strings.TrimSpace(os.Getenv("SUPABASE_URL")),
		SupabaseAnonKey:    strings.TrimSpace(os.Getenv("SUPABASE_ANON_KEY")),
		GoogleClientID:     strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID")),
		GoogleClientSecret: strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_SECRET")),
		GoogleRedirectURI:  strings.TrimSpace(os.Getenv("GOOGLE_REDIRECT_URI")),
		DeepSeekAPIKey:     strings.TrimSpace(os.Getenv("DEEPSEEK_API_KEY")),
		DeepSeekBaseURL:    strings.TrimSpace(os.Getenv("DEEPSEEK_BASE_URL")),
		DatabaseDSN:        strings.TrimSpace(os.Getenv("HARNESS_DATABASE_URL")),
		MigrationsDir:      getenvDefault("HARNESS_MIGRATIONS_DIR", "migrations/harness"),
		RatePerMin:         getenvInt("HARNESS_RATE_LIMIT_PER_MIN", 6),
		MaxConcurrentUser:  getenvInt("HARNESS_MAX_CONCURRENT_PER_USER", 2),
		MaxConcurrentTotal: getenvInt("HARNESS_MAX_CONCURRENT_TOTAL", 8),

		GoogleAuthURL:     googleAuthURL,
		GoogleTokenURL:    googleTokenURL,
		GoogleRevokeURL:   googleRevokeURL,
		GoogleUserInfoURL: googleUserInfoURL,
		GoogleCalendarURL: googleCalendarURL,
		GoogleGmailList:   googleGmailListURL,
		GoogleGmailGet:    googleGmailGetURL,
	}
	if cfg.DeepSeekBaseURL == "" {
		cfg.DeepSeekBaseURL = defaultDeepSeekBaseURL
	}
	for _, o := range strings.Split(os.Getenv("HARNESS_ALLOWED_ORIGINS"), ",") {
		o = strings.TrimSpace(o)
		if o != "" {
			cfg.AllowedOrigins = append(cfg.AllowedOrigins, o)
		}
	}
	if raw := strings.TrimSpace(os.Getenv("HARNESS_TOKEN_KEY")); raw != "" {
		key, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			return Config{}, fmt.Errorf("harness: HARNESS_TOKEN_KEY must be base64: %w", err)
		}
		if len(key) != 32 {
			return Config{}, fmt.Errorf("harness: HARNESS_TOKEN_KEY must decode to 32 bytes, got %d", len(key))
		}
		cfg.TokenKey = key
	}
	return cfg, nil
}

// Capabilities reports which optional sections are configured. Database
// reflects actual store readiness, not just the presence of a DSN.
type Capabilities struct {
	EmailAuth bool `json:"email_auth"`
	Google    bool `json:"google"`
	DeepSeek  bool `json:"deepseek"`
	Database  bool `json:"database"`
}

// Capabilities returns the /v1/harness/capabilities payload. It never exposes
// credentials or partial configuration details.
func (c Config) Capabilities(dbReady bool) Capabilities {
	return Capabilities{
		EmailAuth: c.SupabaseURL != "" && c.SupabaseAnonKey != "",
		Google:    c.googleConfigured(),
		DeepSeek:  c.DeepSeekAPIKey != "",
		Database:  dbReady,
	}
}

func (c Config) googleConfigured() bool {
	return c.GoogleClientID != "" && c.GoogleClientSecret != "" &&
		c.GoogleRedirectURI != "" && len(c.TokenKey) == 32
}

func (c Config) deepseekConfigured() bool { return c.DeepSeekAPIKey != "" }

func getenvDefault(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return def
	}
	return n
}
