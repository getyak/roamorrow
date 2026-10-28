# City refresh and nearby lookup implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover truthful city-brief refresh receipts and correct nearby public experience selection before limiting results.

**Architecture:** Add one security-invoker PostGIS lookup RPC using existing geography indexes; keep repository/domain types stable through explicit GeoJSON output. Validate refresh responses as structured target outcomes and retain existing cooldown/authentication boundaries.

**Tech Stack:** PostgreSQL/PostGIS in the extensions schema, Supabase JS 2.118.0, TypeScript 5.9.3, Vitest 5.0.5, Deno Edge Functions, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-28-city-refresh-nearby-recovery.md`

## Global constraints

- No native UI, private user data, fake experiences, credential logging or unrelated checkout edits.
- Preserve current status/category/city filters and nearest-first result limits.
- No cron secret creation or rotation before the root confirms the concrete plan.
- Preserve normal required checks; only bounded public-data/provider actions.
- Coordinate heavy tests with the root; use lightweight focused checks first.

## Review focus

- More global active rows than the old cap must not hide nearby rows.
- Geography is GeoJSON longitude/latitude and works near the antimeridian and poles.
- Equal-distance ordering must be stable; optional city/category filters apply before limits.
- Public lookup remains under RLS and cannot grant writes or access private tables.
- HTTP 200 with failed/partial/missing target outcomes cannot satisfy refresh acceptance.

### Task 1: Isolate and establish service identity

**Files:** source preservation record outside the repository; this plan and spec.

- [x] Record the source checkout's path-only dirty status. Native cross-repository worktree creation was rejected; use the authorized exclusive Git worktree fallback.
- [x] Fetch current main and create `codex/city-refresh-geo-recovery-20261028`. One transient promisor fetch failed; an HTTP/1.1 retry completed.
- [x] Inspect linked Supabase metadata and only secret names. Root `.env` and linked project match. The local linked service has no deployed compiler or cron secret; its anonymous public active-experience count is zero. Production relation remains unverified.
- [ ] Confirm production Web service identity and existing deployment route before external writes.

### Task 2: Correct nearby selection with regression evidence

**Files:** `packages/data/src/experiences-repo.ts`, `packages/data/src/db.ts`, a focused repository test; one forward-only migration and rolled-back SQL acceptance test in `infra/supabase/`.

**Interfaces:** Preserve `findNearby(FindNearbyParams): Promise<Experience[]>`. Add a typed public RPC taking longitude, latitude, radius, limit and optional category/city. Return rows with explicit GeoJSON location.

- [x] Write the real-client HTTP-boundary regression for a nearby row after 120 unrelated rows and observe failure on the original repository.
- [x] Write isolated SQL acceptance for filter-before-limit, ordering/ties, city/category/status isolation and GeoJSON; observe the missing RPC failure.
- [x] Implement the smallest stable invoker RPC, parameter bounds, explicit grants and repository call. Do not add fallback global scans.
- [x] Run the focused regression and database acceptance, then relevant data/API suites and type checks.
- [x] Record why this fixes a reproducible query defect but does not by itself explain the empty production API response; production inventory remains unverified.

### Task 3: Truthful refresh outcomes and safe configuration

**Files:** `.github/workflows/city-brief-refresh.yml`, a small response validator plus tests, `infra/supabase/functions/compile-city-brief/README.md`, and relevant function response code only if needed.

**Interfaces:** Validator consumes the requested city/target and compiler JSON. It accepts complete `ok` target outcomes and explicit cooldown skips; rejects failed/partial/missing/duplicate or mismatched outcomes without printing response content or credential values.

- [x] Add failing validator tests for failed outcomes under HTTP 200 and missing/mismatched targets; include cooldown success.
- [x] Implement and wire the validator after the existing guarded request. Keep the secret guard, bounded invocation and cooldown.
- [ ] Confirm current consumers and rollback scope. Obtain root confirmation before creating the missing dedicated cron secret.
- [ ] Provision/deploy only on the confirmed service, using existing provider credentials, and run one `force=false` target.
- [ ] Retain safe per-target counts/status and run metadata; never claim a failed/partial result as success.

### Task 4: Review, delivery and live evidence

- [x] Produce a diff package and request independent review; root reviewed RPC, and the Capir reviewer closed the compiler persistence findings after targeted RED/GREEN.
- [ ] Run required checks at the coordinated resource slot, fix confirmed findings, push and create a PR; attach it to this chat.
- [ ] Ask the root to review the concrete PR, then merge normally after required checks.
- [ ] Apply only the forward migration and deploy affected existing services; record revisions and smoke checks separately.
- [ ] Validate real public Chiang Mai experience detail/navigation if authentic data exists. Otherwise report the exact remaining coverage blocker without inserting fixtures.
- [ ] Verify source dirty status preservation and write `/Users/xiongxinwei/.codex/artifacts/online-remediation-20261028/roamorrow-refresh-handoff.md`.

## Execution ledger

- 2026-10-28: Preflight authorizations carry into this implementation. The root supplied the selected scope and explicitly authorized normal deployment/configuration; missing new secret creation has a separate concrete-plan gate.

- 2026-10-28: Production Vercel binding is confirmed, but sensitive Supabase variable values are unreadable. The earlier empty-value comparison was invalid and retracted. Public `/` and `/app` plus their 17 observed same-host scripts expose no Supabase origin, and CSP provides no origin. The local Web `.env.local` contains placeholder configuration, so it is not deployment identity evidence. All production writes remain paused.
- 2026-10-28: The nearby regression failed with expected `[]` versus `[nearby]` on the original repository, then passed after the typed RPC call. The existing data package's controlled dependencies were reused for lightweight checks after fresh frozen installation timed out on package downloads; this is not frozen-lockfile/full-CI verification. Its full focused package suite passed 25/25.
- 2026-10-28: Cron authentication regression also caught acceptance of a service key without the Bearer scheme; the shared helper now requires an explicit bearer and passes all six contract tests.
- 2026-10-28 Ruling: The root deferred and then released the isolated PostGIS window. SQL acceptance was written before migration implementation; actual database RED/GREEN verification waits for the resource window/image. No hosted database will be used for fixtures.

- 2026-10-28 Ruling: Add the same isolated PostGIS acceptance as a normal CI job (no production credentials, network, or published ports) so the geographic/RLS behavior remains a required regression signal rather than a one-off local probe. The root CI test command also executes the pure refresh contract tests.

- 2026-10-28: Web authentication source inspection found no OAuth/GoTrue/JWKS/config initiation route. Only server-side validation of externally supplied bearer tokens exists; no guessed login endpoint was probed. Production identity remains unknown.

- 2026-10-28: Replaced provisional dependency reuse with links to the exact current-lock extracted data snapshots (Supabase 2.118.0, Vitest 5.0.5, TypeScript 5.9.3) and this worktree’s own core package. Re-ran the full data suite: 25/25. Full workspace frozen installation remains separately unverified after downloads timed out.

- 2026-10-28: Real PostgreSQL 16/PostGIS 3.4 acceptance passed after the expected missing-RPC RED, with the old global-cap omission reproduced. Nearest order/ties, exact radius, city/category/status, GeoJSON, antimeridian/poles and invoker/no-write checks passed. All 129 synthetic rows rolled back; table count returned zero. The owned 0.5-CPU/256-MiB network-isolated container and its anonymous volume were removed.

- 2026-10-28: CI uses the same validated PostGIS image digest `sha256:44126d872ac91993766c341e369c539e8196614321765d36a6f1bab0419a5fa5`; no mutable-image change can silently alter the SQL acceptance environment.

- 2026-10-28: Root review found that successful accounting could hide failed content writes. The real registered handler plus the real locked SDK reproduced 11 failures, including event/kit write errors, zero-row kit writes, ignored reads and downgrade errors. Fixes now require matching returned rows, propagate failed/partial status, retain known successful counts and count successful stale sweeps. Additional handler controls reject bad auth/input before any HTTP I/O. No provider request leaves the controlled boundary.
- 2026-10-28 Ruling: The per-function JWT gateway must admit the existing custom cron-header protocol, while the handler retains fail-closed authentication. The runbook now uses an explicit verified project ref and the function-scoped `--no-verify-jwt` flag; activation still waits for production identity and root review, and no other function setting is changed.

- 2026-10-28: A follow-up handler regression showed the new event-dedup read failure lost already-known search/model usage in the outer catch. The local failure result now preserves three performed search calls and the measured model tokens; RED/GREEN records retained.

- 2026-10-28: Independent Capir reviewer confirmed the scoped persistence changes and found one Important edge: a failed stale sweep after an empty search lost four already-performed Tavily calls. A real-handler no-candidates regression failed first; the branch now returns failed locally and preserves calls with zero model tokens/confirmed writes. Other review scope was explicitly limited to compiler persistence, not production identity/deployment.

- 2026-10-28: Independent scoped persistence re-review read the final empty-search failure branch and handler test, closed its Important finding and found no remaining blocker in that scope. Production identity, actual migration and activation are explicitly outside this passing code-review conclusion. Deliver a draft PR and keep merge/deployment paused.
