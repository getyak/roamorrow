-- Harness private schema: owner-scoped onboarding + Google OAuth state + AES-GCM
-- encrypted provider tokens. Idempotent (see apps/api/migrate: every file is
-- re-run on start, so DDL must be CREATE ... IF NOT EXISTS).
--
-- Security invariants enforced at this layer:
--   * every row is keyed by the verified auth subject (user_id); application
--     code only ever passes the identity obtained from Supabase /auth/v1/user,
--     never a client-supplied identifier;
--   * provider tokens are stored as AES-GCM ciphertext (nonce-prefixed) whose
--     AAD binds owner + provider + purpose, never plaintext;
--   * OAuth state rows are one-use (used_at) and short-lived (expires_at);
--   * user_generations is a monotonically increasing connection generation:
--     token commits compare-and-commit against it, so a disconnect always
--     wins over in-flight OAuth exchanges or token refreshes (enforced in
--     Postgres, not just in process memory).

CREATE SCHEMA IF NOT EXISTS harness;

CREATE TABLE IF NOT EXISTS harness.user_generations (
    user_id    TEXT PRIMARY KEY,
    generation BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS harness.profiles (
    user_id            TEXT PRIMARY KEY,
    email              TEXT NOT NULL DEFAULT '',
    display_name       TEXT NOT NULL DEFAULT '',
    home_city          TEXT NOT NULL DEFAULT '',
    interests          JSONB NOT NULL DEFAULT '[]',
    ai_context_consent BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS harness.google_tokens (
    user_id      TEXT PRIMARY KEY,
    access_enc   BYTEA NOT NULL,
    refresh_enc  BYTEA NOT NULL,
    token_type   TEXT NOT NULL DEFAULT 'Bearer',
    scopes       JSONB NOT NULL DEFAULT '[]',
    google_email TEXT NOT NULL DEFAULT '',
    expires_at   TIMESTAMPTZ NOT NULL,
    generation   BIGINT NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS harness.oauth_states (
    state         TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL,
    generation    BIGINT NOT NULL DEFAULT 0,
    verifier_enc  BYTEA NOT NULL,
    want_calendar BOOLEAN NOT NULL DEFAULT FALSE,
    want_mail     BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at    TIMESTAMPTZ NOT NULL,
    used_at       TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_harness_oauth_states_expires
    ON harness.oauth_states (expires_at);
