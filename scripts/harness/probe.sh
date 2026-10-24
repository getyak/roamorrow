#!/usr/bin/env bash
# Readiness probes for the private harness runtime. No secrets are printed.
#
# Checks: loopback API readiness, exact capabilities booleans, unauthorized
# rejection on protected routes, /mcp method + protocol behavior, and a real
# private-database readiness query over the compose network (the DB publishes
# no host port).
#
# Optional: export HARNESS_PROBE_TOKEN with a Supabase access token for a
# verified-email test identity to exercise authenticated round trips. The
# token is used in headers only and never echoed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="http://127.0.0.1:4437"
COMPOSE=(docker compose --env-file "$ROOT/deploy/harness.runtime-env" -f "$ROOT/deploy/compose.harness.yml" --project-name roamorrow-harness-local)

pass=0
fail=0

check() {
  local name="$1" ok="$2"
  if [[ "$ok" == "1" ]]; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name"
    fail=$((fail + 1))
  fi
}

# 1. Loopback API readiness.
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/healthz" || true)
check "loopback GET /healthz -> 200 (got $code)" "$([[ "$code" == "200" ]] && echo 1 || echo 0)"

# 2. Capabilities: exactly the four documented booleans, no credentials.
caps=$(curl -s "$BASE/v1/harness/capabilities" || true)
ok=1
for key in email_auth google deepseek database; do
  echo "$caps" | grep -q "\"$key\":\(true\|false\)" || ok=0
done
echo "$caps" | grep -q "client_secret\|api_key\|SUPABASE" && ok=0
check "GET /v1/harness/capabilities booleans only" "$ok"
check "API reports private database ready" "$(echo "$caps" | grep -q '"database":true' && echo 1 || echo 0)"

# 3. Unauthorized rejection (no synthetic-auth bypass).
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"ping"}' || true)
check "POST /mcp without token -> 401 (got $code)" "$([[ "$code" == "401" ]] && echo 1 || echo 0)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/harness/tools/call" \
  -H 'Content-Type: application/json' \
  -d '{"name":"get_traveler_profile","arguments":{}}' || true)
check "POST /v1/harness/tools/call without token -> 401 (got $code)" "$([[ "$code" == "401" ]] && echo 1 || echo 0)"

# 4. /mcp GET (SSE) must be 405.
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/mcp" || true)
check "GET /mcp -> 405 (no SSE) (got $code)" "$([[ "$code" == "405" ]] && echo 1 || echo 0)"

# 5. Private DB: readiness query over the compose network + no host port.
if "${COMPOSE[@]}" exec -T db pg_isready -U "${POSTGRES_USER:-harness}" >/dev/null 2>&1; then
  check "db pg_isready over compose network" 1
else
  check "db pg_isready over compose network" 0
fi
rows=$("${COMPOSE[@]}" exec -T db \
  psql -U "${POSTGRES_USER:-harness}" -d "${POSTGRES_DB:-harness}" -tAc \
  "SELECT count(*) FROM harness.profiles" 2>/dev/null || echo "err")
check "harness.profiles readiness query (got: $rows)" "$([[ "$rows" != "err" ]] && echo 1 || echo 0)"
ports=$(docker port "$("${COMPOSE[@]}" ps -q db)" 2>/dev/null || true)
check "db publishes no host port" "$([[ -z "$ports" ]] && echo 1 || echo 0)"

# 6. Optional authenticated round trip with a verified Supabase token.
if [[ -n "${HARNESS_PROBE_TOKEN:-}" ]]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/v1/harness/profile" \
    -H "Authorization: Bearer $HARNESS_PROBE_TOKEN" || true)
  check "GET /v1/harness/profile with token -> 200 (got $code)" "$([[ "$code" == "200" ]] && echo 1 || echo 0)"

  mcp=$(curl -s -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H "Authorization: Bearer $HARNESS_PROBE_TOKEN" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}')
  check "authorized MCP initialize -> 2025-11-25" "$(echo "$mcp" | grep -q '"protocolVersion":"2025-11-25"' && echo 1 || echo 0)"
else
  echo "SKIP  authenticated round trip (export HARNESS_PROBE_TOKEN to enable)"
fi

echo "---"
echo "probe summary: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
