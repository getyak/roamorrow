#!/usr/bin/env bash
# Tear down the harness test runtime including its volumes. Per the local
# testing policy this stack must never be left running or auto-restarting.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docker compose --env-file "$ROOT/deploy/harness.runtime-env" -f "$ROOT/deploy/compose.harness.yml" --project-name roamorrow-harness-local \
  down -v --remove-orphans
echo "harness stack removed (volumes included)."
