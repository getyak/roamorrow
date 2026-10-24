#!/usr/bin/env bash
# Show harness stack status and hit the loopback readiness endpoints.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE=(docker compose --env-file "$ROOT/deploy/harness.runtime-env" -f "$ROOT/deploy/compose.harness.yml" --project-name roamorrow-harness-local)

"${COMPOSE[@]}" ps
echo "---"
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4437/healthz || true)
echo "GET /healthz -> HTTP $code"
curl -s http://127.0.0.1:4437/v1/harness/capabilities || true
echo
