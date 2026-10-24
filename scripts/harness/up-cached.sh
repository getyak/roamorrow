#!/usr/bin/env bash
# Reuse a cached image, with no Docker build or image pull. Supply a Linux arm64
# static binary compiled from the reviewed source, in a registered artifact dir.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_ACCEPTANCE_BINARY="${1:?Pass the absolute path to the Linux arm64 static API binary}"
[[ "$HARNESS_ACCEPTANCE_BINARY" == /* && -f "$HARNESS_ACCEPTANCE_BINARY" ]] \
    || { echo 'The prebuilt static API binary does not exist.' >&2; exit 2; }
ARTIFACT_PARENT="$(cd "$(dirname "$HARNESS_ACCEPTANCE_BINARY")" && pwd -P)"
grep -Fxq "$ARTIFACT_PARENT" "$HOME/.local/state/dev-storage-guard/artifacts.list" \
    || { echo 'The binary must be in a registered test artifact directory.' >&2; exit 2; }
docker image inspect postgres:18-alpine >/dev/null
STAGING="$(mktemp -d "$ARTIFACT_PARENT/runtime-payload.XXXXXX")"
PAYLOAD="$STAGING/app"
mkdir -p "$PAYLOAD"
cp "$HARNESS_ACCEPTANCE_BINARY" "$PAYLOAD/api-server"
cp -R "$ROOT/apps/api/migrations" "$PAYLOAD/"
find "$PAYLOAD" -type d -exec chmod 755 {} +
find "$PAYLOAD/migrations" -type f -exec chmod 644 {} +
chmod 755 "$PAYLOAD/api-server"
COMPOSE=(docker compose --env-file "$ROOT/deploy/harness.runtime-env"
    -f "$ROOT/deploy/compose.harness.yml" -f "$ROOT/deploy/compose.harness.cached.yml"
    --project-name roamorrow-harness-local)
# Inspect the merged shape without printing interpolated secrets. A cached
# override must clear build, preventing accidental retagging of the DB image.
"${COMPOSE[@]}" config --format json | python3 -c '
import json,sys
d=json.load(sys.stdin); api=d["services"]["api"]; db=d["services"]["db"]
assert not api.get("build"), "cached runtime must never build an image"
assert api["ports"][0]["host_ip"]=="127.0.0.1"
assert not db.get("ports")
assert not {"DEEPSEEK_API_KEY","HARNESS_TOKEN_KEY","SUPABASE_ANON_KEY"} & db["environment"].keys()
print("Cached runtime boundary validated; no image build or pull.")'
"${COMPOSE[@]}" up -d --no-build --pull never db
"${COMPOSE[@]}" stop api
# The API is stateless. Recreate this project's API container so deleted or
# renamed migrations from a prior build cannot survive a directory merge.
"${COMPOSE[@]}" rm --force --volumes api
"${COMPOSE[@]}" create --no-build --pull never api
API_ID="$("${COMPOSE[@]}" ps -aq api)"
[[ -n "$API_ID" ]]
docker cp "$PAYLOAD" "$API_ID:/"
"${COMPOSE[@]}" up -d --no-build --pull never --no-recreate --wait --wait-timeout 30 api
