# DeepSeek onboarding harness — Go backend

Implementation and live acceptance have separate evidence. Real private
PostgreSQL and DeepSeek checks passed; remaining identity, native and endpoint
acceptance is listed in the [acceptance record](../qa/harness-ios-20261024/README.md).
The frozen wire contract lives in
[docs/architecture/deepseek-onboarding-harness.md](../architecture/deepseek-onboarding-harness.md);
this document records the concrete backend configuration, response shapes and
runtime contract that were implemented against it.

## Scope

- Code: `apps/api/internal/harness/**`, wired into `apps/api/main.go`.
- Migrations: `apps/api/migrations/harness/**` (private `harness` schema,
  separate from `DATABASE_URL` / `reviews_extracted`).
- Runtime: `deploy/compose.harness.yml`, `deploy/harness.runtime-env.example`
  (the real file `deploy/harness.runtime-env` is git-ignored and must never be committed),
  `scripts/harness/**`.

## Runtime contract

Project `roamorrow-harness-local` (`deploy/compose.harness.yml`):

| Property   | Value                                                                                                             |
| ---------- | ----------------------------------------------------------------------------------------------------------------- |
| API        | `http://127.0.0.1:4437` (loopback bind only)                                                                      |
| PostgreSQL | `postgres:18-alpine`, **no host ports**, compose network only                                                     |
| restart    | `no` on every service (test runtime, never a daemon)                                                              |
| Migrations | inside the runtime image (`/app/migrations/harness`), applied idempotently at startup or via `api-server migrate` |
| Secrets    | `deploy/harness.runtime-env` (never committed, provided outside source)                                           |

Lifecycle/probe commands: `scripts/harness/up.sh`, `status.sh`, `probe.sh`,
`migrate.sh`, `down.sh` (tears down volumes too). See
`scripts/harness/README.md`.

## Configuration (all optional sections degrade visibly, never silently)

| Variable                                                                                          | Missing behavior                                                                   |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`                                                               | `email_auth=false`; protected routes return 503 `auth not configured`              |
| `HARNESS_DATABASE_URL`                                                                            | `database=false`; DB-backed routes return 503                                      |
| `HARNESS_MIGRATIONS_DIR`                                                                          | default `migrations/harness` (compose sets `/app/migrations/harness`)              |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`                                 | `google=false`; `POST /google/start` returns 503                                   |
| `HARNESS_TOKEN_KEY` (base64, 32 bytes; `openssl rand -base64 32`)                                 | `google=false`; no Google tokens can be stored                                     |
| `DEEPSEEK_API_KEY`                                                                                | `deepseek=false`; `POST /chat` returns 503                                         |
| `DEEPSEEK_BASE_URL`                                                                               | default `https://api.deepseek.com/v1`                                              |
| `HARNESS_ALLOWED_ORIGINS` (comma separated)                                                       | `/mcp` rejects every `Origin` (fail closed); absent `Origin` (non-browser) allowed |
| `HARNESS_RATE_LIMIT_PER_MIN` / `HARNESS_MAX_CONCURRENT_PER_USER` / `HARNESS_MAX_CONCURRENT_TOTAL` | defaults `6` / `2` / `8`                                                           |

A malformed `HARNESS_TOKEN_KEY` is a hard startup error.

The Compose sample `HARNESS_DATABASE_URL` in
`deploy/harness.runtime-env.example` pins `?sslmode=disable`: the private
Compose Postgres has no TLS and lib/pq would otherwise default to
`sslmode=require`.

## Native account configuration

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the same project as the server,
and `SOLO_HARNESS_BASE_URL` to the accepted HTTPS origin. The origin cannot be
loopback HTTP or contain `/v1/harness`; the client adds endpoint paths itself.
Resolution is process environment, then bundled `Secrets.plist`, then generated
values from the repository-root private `.env`. Keep provider/model secrets on
the server; the native account flow does not need a DeepSeek key.

The current TestFlight workflow does not inject these three account settings.
Its build/upload success alone does not verify that an installed release can
use this flow. Configure and accept a release separately before claiming it.

`scripts/ios/account-acceptance.sh <registered-artifact>` builds the focused
`AccountAcceptance` scheme inside the shared iOS session, then executes the
account regression and onboarding UI tests. Reuse an existing matching
`.xctestrun` with `xcodebuild test-without-building` inside `dev-ios-session`
for follow-up runs; use a new result-bundle path in that registered directory.

## Wire contract (as implemented)

All JSON snake_case. Protected routes require the project's Supabase bearer
token verified via `GET /auth/v1/user`; **anonymous and unverified-email
identities are rejected**. The verified subject (`sub`) is the only owner key —
no client-supplied id or metadata ever authorizes access (bodies containing
`user_id`/`email` are rejected as unknown fields).

| Route                             | Response fields                                                                                                                                    |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /v1/harness/capabilities`    | exactly `{email_auth,google,deepseek,database}` booleans                                                                                           |
| `GET /v1/harness/profile`         | `{user_id,email,display_name,home_city,interests,ai_context_consent,google:{connected,email,scopes}}`                                              |
| `PUT /v1/harness/profile`         | accepts only `{display_name,home_city,interests,ai_context_consent}` (all four required; full replacement), returns the profile                    |
| `POST /v1/harness/google/start`   | `{calendar,mail}` booleans, ≥1 true → `{authorization_url,expires_at}`; 503 when unconfigured                                                      |
| `GET /v1/harness/google/callback` | one-use expiring PKCE state → 302 to `solocompass://google-connected?status=connected\|error` (never tokens/PII)                                   |
| `DELETE /v1/harness/google`       | `{disconnected,provider_revocation_confirmed}` (local erasure first, provider revocation attempted, flag honest)                                   |
| `GET /v1/harness/context`         | `{items:[{kind,value,provenance,confirmed}]}` — manual/confirmed context + Google connection scopes; no raw mail or tokens                         |
| `POST /v1/harness/tools/call`     | `{name,arguments}` → `{name,status,result,error,provenance}` (`status` is `ok`\|`error`)                                                           |
| `POST /v1/harness/chat`           | `{message}` (1–4000 runes) → `{reply,tool_calls:[{name,status}],sources:[string]}` (`sources` = provenance labels, e.g. `google_calendar`)         |
| `POST /mcp`                       | MCP Streamable HTTP stateless JSON (2025-11-25): `initialize`, `ping`, `tools/list`, `tools/call`; notifications → 202 empty; `GET`/`DELETE` → 405 |

Tool trace `status` values in `/chat`: `ok`, `error`, `limit_reached`.

### MCP endpoint details

- `Content-Type: application/json` required (415 otherwise); `Accept` must
  include `application/json` (406 otherwise).
- `MCP-Protocol-Version` header, when present, must be `2025-11-25` (400).
- JSON-RPC errors: `-32700` parse, `-32600` invalid request (incl. rejected
  batches and bad `id` types), `-32601` method not found, `-32602` invalid
  params (unknown tool, bad arguments), `-32603` internal.
- `initialize` returns `protocolVersion:"2025-11-25"`,
  `capabilities:{tools:{listChanged:false}}`,
  `serverInfo:{name:"roamorrow-harness",version:"1.0.0"}`.
- `tools/list` returns exactly the three read tools with `inputSchema` and
  read-only annotations; no pagination (non-null `cursor` → `-32602`).
- `tools/call` execution failures return `{isError:true}` with a clear code
  (`consent_required`, `google_not_connected`, `google_not_configured`,
  `missing_scope`, `reauthorization_required`, `token_unavailable`,
  `store_unavailable`, `provider_unavailable`, `rate limit exceeded`) — never
  an invented empty success.
- Origin validated before auth against `HARNESS_ALLOWED_ORIGINS` on **every**
  method including `GET`/`DELETE` (validated before the 405); mismatch → 403
  (DNS-rebinding protection).
- Messages must be exactly one complete JSON value: a second `Decode` must
  return `io.EOF`, so trailing `]`/`}`, second objects and oversized tails
  are `-32700` parse errors. A notification gets 202 only as a valid complete
  single JSON-RPC message.

### Read tools and bounds (server-owned)

| Tool                   | Arguments                                                     | Bounds                                                                                                        |
| ---------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `get_traveler_profile` | none (any field rejected)                                     | confirmed/manual fields only, **no email**                                                                    |
| `list_calendar_events` | none                                                          | primary calendar, ≤20 events, next 14 days                                                                    |
| `search_travel_mail`   | optional `query` (≤80 chars, `a-z0-9 ,.'@` only, lower-cased) | ≤10 messages, ≤10 metadata attempts, last 30 days, headers + snippet (≤300 chars) only; no bodies/attachments |

Arguments can never select a user, endpoint, date window or mailbox. Unknown
fields, non-object arguments, oversized or present-but-blank values fail.
Mail results carry an explicit `partial` flag: mixed metadata outcomes are
labelled incomplete and all-failed metadata fetches propagate an error — never
an invented empty success.

### Consent matrix

| Caller                      | `get_traveler_profile`        | Google tools                                                           |
| --------------------------- | ----------------------------- | ---------------------------------------------------------------------- |
| Direct (`/tools/call`, MCP) | allowed (own manual profile)  | requires `ai_context_consent` **and** connected **and** provider scope |
| Model (`/chat` tool loop)   | requires `ai_context_consent` | same as direct                                                         |

Without `ai_context_consent`, `/chat` offers the model **no tools at all** and
no account context reaches DeepSeek.

## Security invariants

- **Auth**: Supabase `GET /auth/v1/user`, redirects disabled, bounded body,
  generic failures. Anonymous (`is_anonymous`, empty identities) and
  unverified-email users rejected. No synthetic-auth bypass exists.
- **Owner scoping**: every SQL statement filters on the verified subject or
  the unguessable one-use state; all values are bound parameters
  (`store_postgres_test.go` asserts both).
- **Token encryption**: Google tokens AES-256-GCM at rest (nonce-prefixed
  ciphertext), key in `HARNESS_TOKEN_KEY`, plaintext only in memory. Ciphertext
  is AAD-bound to owner + provider + purpose (`google-access`,
  `google-refresh`, `google-pkce-verifier`): cross-user or cross-slot swaps
  fail to decrypt.
- **OAuth**: PKCE S256, one-use state (atomic `used_at`), 10-minute expiry,
  replay/expiry/unknown all fail closed with an error redirect. A denied
  callback consumes its state exactly once. Stored scopes are intersected with
  **this** flow's `calendar`/`mail` selection, so historic grants returned via
  `include_granted_scopes=true` can never enable an unselected source.
- **Connection replacement and disconnect win**: all connection mutations use
  a transaction locking the same owner generation row with `FOR UPDATE`.
  `ReplaceConnection` compares the OAuth state's epoch, advances it, saves the
  new connection and cancels pending states. Disconnect advances that epoch and
  deletes tokens/states. Refresh only updates an existing row with the same
  epoch. Old callbacks or broad-scope/old-account refreshes cannot restore a
  revoked or replaced connection. This is enforced in PostgreSQL.
- **Token refresh**: expired access tokens are refreshed (bounded,
  no redirects) when a usable refresh token exists; rotation is persisted and
  the user's selected scope subset is preserved. A missing/rejected refresh
  (`invalid_grant`) surfaces `reauthorization_required` explicitly — never
  silent empty data. Refresh persistence re-checks the disconnect generation.
- **Upstream HTTP**: every token/code-bearing client (Supabase, Google
  token/revoke/userinfo/APIs, DeepSeek) aborts on redirects; bounded timeouts
  and response sizes.
- **Logging**: access log prints method + URL _path_ + status + duration only
  (never query strings, so OAuth `code`/`state` never leak); recovery logs
  method + path only (no request dump); codes, tokens, mail text and prompt
  text are never logged. Provider/model errors are sanitized.
- **Input**: strict JSON — bodies must be exactly one complete JSON value
  (second `Decode` must return `io.EOF`; trailing `]`/`}`, second objects and
  oversized tails fail), unknown fields rejected, 32 KiB body cap enforced on
  the whole request including trailing whitespace (256 KiB for `/mcp`, 413 on
  overflow), blank/oversized fields rejected.
- **Paid ops** (`/chat`, `/tools/call`, MCP `tools/call`): per-verified-user
  token bucket + per-user and global concurrency caps → 429.
- **Model loop**: server-owned model `deepseek-flash` with
  `thinking:{type:"disabled"}`; ≤4 model rounds and ≤6 tool calls per `/chat`;
  tool output capped at 8 KB per call and treated strictly as untrusted
  evidence (never instructions); traces carry tool names/status only.
- **No writes**: no send/booking/calendar-mutation/shell/arbitrary MCP tools;
  Google scopes are read-only (`calendar.readonly`, `gmail.readonly`) plus
  `openid email` for account display.

## Tests (no secrets, no external network)

```bash
cd apps/api
GOMAXPROCS=2 go test -p 2 ./...
```

Coverage highlights: Supabase verification (unverified/anonymous/redirect
leak), bearer enforcement and 503 missing-config states, profile round trip +
spoofed-identity rejection + validation + strict trailing-JSON rejection,
owner isolation across users, context provenance, strict tool arguments and
consent/scope/consent-for-model gates, server-owned windows and query
sanitization, Google payload bounds (truncation/limits), PKCE start shape,
OAuth happy path with encrypted-at-rest assertions, denial-consumes-state,
replay/expiry/bad-state, calendar-only state never enabling mail, disconnect +
honest revocation flags, disconnect cancelling pending states and blocking
in-flight exchange/refresh (generation compare-and-commit), token refresh
(rotation, subset preservation, `reauthorization_required`, disconnect race),
mail metadata attempt bounds + partial/all-failed labelling, nil-config tool
guards and real `NewServer` wiring (no typed-nil interfaces), bounded chat
rounds/calls, no-tools-without-consent, per-user rate limiting, sanitized
model failure, MCP lifecycle/validation/notifications/405/Origin (incl.
GET/DELETE)/auth/oversize/trailing-garbage, limiter budgets/concurrency, SQL
parameterization + owner scoping + generation compare in SQL, AES-GCM AAD
owner/purpose binding, migration idempotency.

## Live acceptance and remaining gaps

The default test command above uses synthetic providers. Two additional tests
are opt-in: `TestPostgresLiveHarness` needs
`HARNESS_INTEGRATION_DATABASE_URL` pointing only to the dedicated disposable
harness database; `TestDeepSeekLiveHarness` needs `HARNESS_LIVE_DEEPSEEK=1` and
the server's private key environment. The latter makes bounded paid calls with
synthetic identity/profile data. Neither adds an authentication bypass to the
production executable. Never aim these fixtures at an existing user database.

On 2026-10-24 the parent verified real private PostgreSQL migrations, owner
isolation, disconnect/reconnect and a deterministic concurrent revocation test;
the actual Go DeepSeek tool loop also passed. Full evidence and boundaries are
in [the acceptance record](../qa/harness-ios-20261024/README.md).

- Real Supabase email login/OTP, Google consent and native launch acceptance
  remain incomplete. Default account credentials were rejected; Google OAuth
  configuration is absent. No real calendar or mail was read.
- Tailscale dry-run passed; applying the exact endpoint remains pending human
  confirmation. No TestFlight release or physical-device claim is made.
- `deploy/harness.runtime-env` is ignored and mode `0600`; DB only receives
  `POSTGRES_*`, never the API's encryption/model/provider keys.
- The resource-limited cached runtime clears Compose `build` and uses
  `--no-build --pull never`. `up-cached.sh` stages reviewed code in a fresh
  registered artifact directory and copies it through Docker to a recreated
  project API container, without extending host/VM mounts. DB is retained
  during an API update. Final `down.sh` removes this disposable test stack and
  its volumes. Normal Dockerfile image build was not run for this acceptance.
- Google account email display uses the OpenID userinfo endpoint and degrades
  to empty string (never fabricated) when unavailable.

Gmail keywords are quoted as a literal phrase so caller text such as `OR inbox`
cannot broaden the fixed date/travel filters. Operator and phrase behavior:
https://support.google.com/mail/answer/7190?hl=en
