#!/usr/bin/env bash
# Bring up the private local harness runtime (project: roamorrow-harness-local).
# Test runtime only: restart=no everywhere, DB has no host port, API binds
# 127.0.0.1:4437. Real secrets come from deploy/harness.runtime-env which is
# git-ignored and provided outside source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT/deploy/harness.runtime-env"
COMPOSE=(docker compose --env-file "$ROOT/deploy/harness.runtime-env" -f "$ROOT/deploy/compose.harness.yml" --project-name roamorrow-harness-local)

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE" >&2
  echo "copy deploy/harness.runtime-env.example and fill in real values" >&2
  exit 1
fi

# Validate required keys are present (names only — never print values).
required=(POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB HARNESS_DATABASE_URL SUPABASE_URL SUPABASE_ANON_KEY)
missing=0
for key in "${required[@]}"; do
  if ! grep -qE "^${key}=.+" "$ENV_FILE"; then
    echo "missing required key in deploy/harness.runtime-env: $key" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

# Optional sections are reported by name only (no values).
for key in GOOGLE_CLIENT_ID HARNESS_TOKEN_KEY DEEPSEEK_API_KEY HARNESS_ALLOWED_ORIGINS; do
  if grep -qE "^${key}=.+" "$ENV_FILE"; then
    echo "optional configured: $key"
  else
    echo "optional missing (capability disabled): $key"
  fi
done

"${COMPOSE[@]}" up -d --build
echo "stack up. API: http://127.0.0.1:4437 (loopback). Run scripts/harness/probe.sh next."
