# Roamorrow API

Go service that provides the RAG (retrieval-augmented generation) pipeline for Roamorrow. It aggregates real user reviews into Solo Score calculations and exposes them to the mobile app.

## Purpose

- Persist and query per-experience reviews from a PostgreSQL database.
- Compute aggregate Solo Scores from real review data.
- Extract structured solo metrics from review text via DeepSeek's
  OpenAI-compatible chat/completions API (`internal/reviews/extractor.go`).

## Endpoints

| Method | Path                             | Description                                                                                                        |
| ------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| GET    | `/healthz`                       | Health check — always returns `{"status":"ok"}`, no DB dependency.                                                 |
| GET    | `/v1/experiences/:id/solo-score` | Returns the aggregate solo score and review count for an experience. Returns 503 when the database is unavailable. |

## DeepSeek onboarding harness

The same binary serves the onboarding harness (frozen wire contract):
`/v1/harness/*` and `/mcp` (MCP Streamable HTTP, 2025-11-25). It uses a
**separate private database** (`HARNESS_DATABASE_URL`, schema `harness`,
migrations in `migrations/harness`) and verified Supabase bearer auth.

- Backend config + runtime contract: [docs/development/harness-backend.md](../../docs/development/harness-backend.md)
- Local private runtime: `deploy/compose.harness.yml` (project
  `roamorrow-harness-local`, API `127.0.0.1:4437`, no DB host ports,
  `restart: no`) with `scripts/harness/{up,status,probe,migrate,down}.sh`
- `api-server migrate` applies the idempotent harness migrations and exits
  (they also run automatically at startup).

## Environment variables

| Variable            | Default                       | Description                                                                                                            |
| ------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `DATABASE_URL`      | _(none)_                      | PostgreSQL DSN (`postgres://user:pass@host/db`). When absent, `/v1` endpoints return 503.                              |
| `PORT`              | `8080`                        | TCP port the server listens on.                                                                                        |
| `DEEPSEEK_API_KEY`  | _(none)_                      | DeepSeek key for review extraction. Without it, `Extract` returns an error and callers degrade gracefully.             |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com/v1` | OpenAI-compatible base URL; the extractor appends `/chat/completions`.                                                 |
| `DEEPSEEK_MODEL`    | `deepseek-flash`              | Model id. Legacy ids (`deepseek-chat`, `deepseek-reasoner`, `deepseek-v4-pro`, `deepseek-v4-flash`) normalize forward. |
| `HARNESS_DATABASE_URL` | _(none)_                   | Private harness database DSN. When absent, harness DB endpoints return 503 (`database` capability false).             |
| `HARNESS_TOKEN_KEY` | _(none)_                     | Base64 AES-256 key encrypting Google tokens at rest. Missing config disables the `google` capability.                 |

## Running locally

```bash
# From the repo root:
make -C apps/api api-run

# Or from apps/api/:
make api-run
```

## Docker

```bash
docker build -t solo-compass-api apps/api
docker run -p 8080:8080 -e DATABASE_URL=postgres://... solo-compass-api
```

## Tests

```bash
cd apps/api
go test ./...
```
