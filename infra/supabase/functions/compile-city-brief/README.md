# compile-city-brief

Server-side curation of a city's **landing kit** (落地包: net / money / visa /
safety) and **live/在地 events**. Content is city-level and shared across all
users, so this function is NOT user-triggered — a user "refresh" in the app is
just a re-read of the `city_kits` / `city_events` tables. It is driven by the
`city-brief-refresh` GitHub Actions cron, or invoked with the service-role key.

Pipeline: Tavily search (advanced, ≤6 results/query) → normalize to candidates
(dedup by URL, cap 18 / ~15k chars) → DeepSeek curation (`json_object`, one
retry on invalid JSON) → quality gates in `../_shared/city-brief-core.ts` →
upsert. Every run is accounted in `city_brief_runs` (search calls, token usage,
items written, status `ok|partial|failed`).

## Secrets

```bash
# from infra/supabase
supabase link --project-ref <ref>
supabase secrets set TAVILY_API_KEY=<tvly-…>
supabase secrets set CITY_BRIEF_CRON_SECRET=<random-long-string>
# DEEPSEEK_API_KEY is already set (shared with chat-proxy);
# optional overrides — defaults shown:
supabase secrets set DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
supabase secrets set DEEPSEEK_MODEL=deepseek-flash
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically by the
Supabase runtime.

## Deploy

```bash
supabase functions deploy compile-city-brief --project-ref <verified-production-project-ref> --no-verify-jwt
```

## Contract

`POST /functions/v1/compile-city-brief`

Auth (either one):

- `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`, or
- `x-cron-secret: <CITY_BRIEF_CRON_SECRET>` (what the GitHub cron uses — it does
  not hold the service-role key).

Request body:

```json
{ "city_code": "vte", "target": "both", "force": false }
```

- `city_code` — lowercase; the city must exist in `sc_cities` with
  `brief_enabled = true`.
- `target` — `"kit"`, `"events"`, or `"both"`.
- `force` — optional; bypasses the cooldown (events 72h, kit 240h).

| Status | Meaning                                             |
| ------ | --------------------------------------------------- |
| 200    | Compiled (see `outcomes[]` for per-target results)  |
| 400    | Bad input (missing city_code / invalid target)      |
| 401    | Missing / wrong service-role bearer AND cron secret |
| 404    | City not found                                      |
| 409    | `brief_enabled = false` for the city                |
| 500    | Missing TAVILY_API_KEY / DEEPSEEK_API_KEY           |

A `200` with `outcomes[].error = "cooldown"` means the target was skipped
because a successful run happened inside the cooldown window.

## Invoke examples

Service-role (local/admin):

```bash
curl -s -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"city_code":"vte","target":"both","force":true}' \
  https://<project-ref>.functions.supabase.co/compile-city-brief | python3 -m json.tool
```

Cron secret (what the workflow sends):

```bash
curl -s -X POST \
  -H "x-cron-secret: $CITY_BRIEF_CRON_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"city_code":"vte","target":"events"}' \
  https://<project-ref>.functions.supabase.co/compile-city-brief
```

## Local

```bash
supabase functions serve compile-city-brief --env-file infra/supabase/.env.local
# then run ./test.sh
```

See `test.sh` — it curls twice; the second call should hit the cooldown.

## Recovery and verification

Before any secret, function or schema change, bind the production domain's
Vercel project and current deployment to a nonempty Supabase origin fingerprint
from supported public runtime evidence or an existing protected operator record.
A local `.env` or CLI linked project alone is not production identity. Sensitive
Vercel variable metadata contains no readable value: absence must remain unknown,
never be compared as an empty URL. Stop external writes if identity is unproved.

The compiler now admits only the existing `vte` city, a `kit` / `events` / `both`
target and a boolean `force`. It rejects unauthorized or invalid requests before
provider work. Missing/wrong cron secrets fail closed; a valid service-role
bearer remains the existing administrative authentication option. Never give the
service-role key to the GitHub schedule.

Recover the existing cron secret from an authorized protected source. If no
credential exists, inventory the current function and consumers, obtain approval
of the concrete provisioning/rollback plan, then create a dedicated random value
only in memory and send it over standard input to the confirmed backend and
GitHub secret stores. Never save plaintext credentials in a file, command log,
source, evidence artifact or PR. Restore the existing value on rollback when one
existed; do not rotate unrelated provider/service credentials.

Check existing `sc_cities`, `city_kits`, `city_events` and `city_brief_runs`
metadata, RLS and service-role grants before activating the function. Their
source is migration `0013_city_brief.sql`; inspect any missing object and its
forward-only dependency separately. Do not blindly push every pending migration.
The nearby lookup's additive `0020_nearby_experiences.sql` is a separate change;
apply it before the new Web repository call, after confirming that the existing PostGIS geography type is in `extensions` and its GiST index is present. Stop if that prerequisite differs; never relocate an extension or rebuild a populated geography column as part of this recovery.
The function introduces no table write grants or definer privilege.

Every compiled target returns its persisted `city_brief_runs` receipt. A missing
accounting write fails the request. Cooldown responses reference a completed,
error-free `ok` run within the target's 72-hour / 240-hour freshness window.
Failed/partial runs never satisfy cooldown. An HTTP 200 alone proves neither a
completed refresh nor a persisted result.

The workflow validates the structured response without printing raw provider
content. It rejects failed/partial outcomes, missing or mismatched targets,
missing persistence receipts and stale cooldowns. It distinguishes `refreshed`
from `cooldown` in its safe summary. The normal repository test command and
workflow both run the contract tests:

```bash
node --experimental-strip-types --test scripts/tests/city-brief-contract.test.mjs
node --experimental-strip-types scripts/city-brief-refresh.mjs request vte events false
node --experimental-strip-types scripts/city-brief-refresh.mjs verify <response-file> vte events
```

After review and normal CI/merge, activate only the confirmed existing service
and invoke one bounded `force=false` target. Read back the same shared run's
status, completed timestamp and item count. Keep real refresh, fresh cooldown,
provider failure and missing data separate. The nearby `experiences` list is a
different data product from `city_kits` / `city_events`; successful city-brief
refresh cannot establish Chiang Mai experience coverage.

## Confirm content writes before accounting success

A successful `city_brief_runs` insert alone does not establish content persistence.
Event upserts and kit confirm/update operations now request returned rows and count
only exactly matching row receipts. Errors or a zero-row kit update make the target
failed/partial and preserve counts from earlier confirmed writes. Failed event
identity/dedup reads and kit reads stop the target. Stale-kit sweeps also return and
count changed rows; a failed sweep cannot erase prior successful counts or leave
an `ok` target.

`packages/data/src/city-brief-handler.test.ts` invokes the actual registered Deno
handler with the real locked Supabase SDK and controlled HTTP responses. All model
and search responses are local fixtures, and unexpected network requests are
blocked. It covers content-write failures, zero rows, partial success, read/sweep
errors, accounting failure, and authentication/input rejection before I/O.

The compiler's existing custom authentication contract uses `x-cron-secret`, not
a user JWT. After confirming the actual per-function gateway setting, deploy this
function only with `verify_jwt=false` (the CLI flag above), while retaining the
handler's strict service-role-bearer/cron-secret authentication. Do not change the
JWT setting of another function. Before any valid provider invocation, confirm
missing/wrong credentials return 401 and invalid city/target/force returns 400 with
no provider work. Production identity and review gates still apply.
