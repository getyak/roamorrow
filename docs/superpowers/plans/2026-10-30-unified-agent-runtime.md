# Unified Agent Runtime Implementation Plan

> **For agentic workers:** implement the assigned component and its focused tests; use the shared design as the contract.

**Goal:** Safely recover map-tool execution through the same contracts used by the continuous companion.

**Architecture:** Shared Foundation-only models, journal executor, context and memory protocols. Existing screen/store adapters preserve UI and historical formats.

**Tech Stack:** Swift 5.10, iOS 17+, Foundation, SwiftData, XCTest; no new dependency.

**Spec:** `docs/architecture/unified-agent-runtime.md`

## Global Constraints

- Preserve unrelated work and GET-324 UI; latest origin/main base, dedicated GET-336 branch.
- No account Harness context/credentials in device chat; no new permissions.
- Plan/start must reach disk before dispatch; uncertain side effects are never blindly replayed.
- Stable session/turn/call/card identities; legacy JSON remains readable.
- One shared primary simulator session; host tests compile real production core.

## Review Focus

- Crash between side effect and receipt must not dispatch that effect twice.
- Cancel/rebind cannot let old work change the active map or memory scope.
- Failed storage cannot be reported as success or silently committed later.
- Tool message grouping and restored cards remain coherent and deduplicated.
- Forget/delete must remove newly introduced durable memory and journals.

## Task 1: Shared kernel and host regressions

- [ ] Add common identities/context/checkpoint models with backward-compatible decoding.
- [ ] Implement AgentExecutionJournal and AgentToolExecutor; test plan/start/result failures, identity conflicts, budgets, interrupted replay and cancellation using production code.
- [ ] Add standalone file journal for the map adapter, with atomic rollback and fail-closed corrupt/new-version handling.

## Task 2: Companion adapter

- [ ] Replace companion checkpoint structs with aliases; make HomeStore implement journal protocol while preserving atomic follow-up+receipt.
- [ ] Route tool execution through shared executor; use common session/context/memory, ingest only after durable final reply.
- [ ] Test old snapshot restore, deduplicated retry and failure windows.

## Task 3: Map adapter

- [ ] Integrate shared executor/file journal and stable user-turn identity into VoiceAgentOrchestrator.
- [ ] Save accepted/partial turns, restore receipts/cards without tool dispatch, normalize complete tool groups and protect scope invalidation.
- [ ] Add lifecycle/persistence/card recovery regressions and wire common memory/deletion.

## Task 4: Map policy and device memory

- [ ] Classify all tools, serialize/restore effects, make save-to-favorites explicit and idempotent, add dispatch validity checks.
- [ ] Implement bounded durable device memory/context interfaces with deduplicated ingest, scoped recall and delete/forget; wire router recall.
- [ ] Test memory restart/deletion and replay-safe map semantics.

## Task 5: Integration and delivery

- [ ] Regenerate Xcode project; run production-core host tests and focused native build/tests under shared session.
- [ ] Independent review of complete diff; fix confirmed P0/P1 and rerun affected checks.
- [ ] Commit, PR linked to GET-336, applicable latest-head CI; merge/close only after acceptance and readback.

## Execution record

2026-10-30: User explicitly requested deep design and implementation and authorized autonomous local work/PR delivery. Use separate ownership for parallel components; this design adopts incremental adapters rather than a simultaneous UI/storage rewrite. GET-324 is active and unmerged; anticipate integration after it lands, preserve its scope/time-budget improvements.
