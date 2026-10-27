#!/usr/bin/env bash
# Apply the idempotent harness migrations inside the runtime image
# (also applied automatically at API startup).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docker compose --env-file "$ROOT/deploy/harness.runtime-env" -f "$ROOT/deploy/compose.harness.yml" --project-name roamorrow-harness-local \
  exec -T api /app/api-server migrate
echo "harness migrations applied (idempotent)."
