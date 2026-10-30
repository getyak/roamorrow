# Unified device Agent runtime

GET-336 · 2026-10-30 · Implementation design

## Outcome

CompanionHome and the legacy map conversation use the same session/turn identity,
context value, execution journal contract, recovery executor and device-memory
interface. Their UI state and historical stores remain adapters. A model reply
failure must not repeat an already completed tool. An interrupted side effect
must remain explicitly uncertain rather than being dispatched again.

## Approach and alternatives

Extract a small Foundation-only execution kernel and adapt both existing callers.
Replacing both screens and their history storage at once would mix UI migration
with recovery correctness. Moving everything into the Go account Harness would
change offline and consent boundaries. Neither is necessary for this task.

This is an iOS device-domain runtime. Account Harness profile, mail, calendar and
credentials never enter this memory. The independent map MCP is not migrated.

## Common contracts

All core types live in `Services/AgentRuntime/` and use Foundation only.

```swift
struct AgentSessionDescriptor: Codable, Equatable, Sendable {
    var id: String
    var scope: String // "global" or "experience:<stable-id>"
}
struct AgentTurnIdentity: Codable, Equatable, Sendable {
    var session: AgentSessionDescriptor
    var turnID: UUID // original persisted user-message id, including on retry
}
struct AgentTurnContext: Codable, Equatable, Sendable {
    var capturedAt: Date
    var scope: String
    var facts: String // bounded, explicitly attributed, untrusted evidence
}
enum AgentToolExecutionState: String, Codable, Sendable {
    case planned, started, completed, uncertain
}
```

`AgentToolCheckpoint` retains the existing id/name/argumentsJSON/resultJSON,
sourceTitles/placeID fields and adds state, resolvedArgumentsJSON, effectJSON,
stable cardID and implementationVersion. `AgentToolBatch` retains id,
assistantContent/calls and adds optional context. Missing state in old JSON means
completed when resultJSON exists and planned otherwise. Old companion names are
typealiases. Unknown/new checkpoint versions must not execute silently.

```swift
@MainActor protocol AgentExecutionJournal: AnyObject {
    func toolBatches(for turn: AgentTurnIdentity) -> [AgentToolBatch]
    func savePlan(_ batch: AgentToolBatch, for turn: AgentTurnIdentity) -> Bool
    func saveStarted(callID: String, for turn: AgentTurnIdentity) -> Bool
    func saveResult(_ result: AgentToolCheckpoint, for turn: AgentTurnIdentity) -> Bool
}
@MainActor final class AgentToolExecutor {
    func execute(
        _ batch: AgentToolBatch,
        for turn: AgentTurnIdentity,
        journal: any AgentExecutionJournal,
        allowedTools: Set<String>,
        isCurrent: () -> Bool,
        perform: (AgentToolCheckpoint) async throws -> AgentToolCheckpoint
    ) async throws -> [AgentToolCheckpoint]
}
```

The executor owns validation, canonical JSON identity checks, five-call total
budget, durable plan/start/result ordering, reuse and conservative recovery.
The caller owns transport/streaming/UI. The exact same executor is used by both
callers; neither duplicates the journal dispatch rules.

## Execution and recovery rules

1. Persist accepted user input before model/side effects. Use stable conversation
   and user-message IDs. Store contextual facts once per turn; retries retain the
   original tool arguments and resolved coordinates rather than new UI state.
2. Persist the entire assistant batch before dispatch; persist `started` before
   each call. If either write fails, dispatch nothing further.
3. Persist each actual result before returning it to the model. Completed means a
   result was observed, not that its domain outcome was successful.
4. Repeated call ID with identical canonical name/arguments reuses its result;
   changed payload conflicts. Unsafe operations additionally deduplicate their
   canonical resolved operation within the same turn, even under a new call ID.
   A finished tool is never executed to restore a card. `saveStarted` is an atomic
   planned-to-started claim; an existing claim cannot dispatch a second call.
5. A started call without a saved result produces a durable uncertain result and
   asks for a new explicit action. This first implementation conservatively
   applies that rule to reads too: the journal has a strict planned-to-started
   claim, without a read-reset lease. Never re-open external navigation on restore.
6. A stale/cancelled invocation cannot dispatch a new call or update active UI.
   An observed result may still be recorded under its original identity so that
   cancellation cannot erase evidence of a side effect. Session deletion/Forget
   Me takes precedence: tombstones reject late receipts, and memory admission
   epochs reject late ingestion. Fresh explicit turns can learn after Forget Me
   in the same conversation; retries retain their original epoch. A cleared
   companion rotates its persisted session UUID. The map router checks
   cancellation/validity at action boundaries as well as its caller.
7. Local follow-up mutation and its receipt remain in the same atomic HomeStore
   write. Never split this existing transaction across stores.
8. Route/place/source cards persist their effect and stable identity. Restore
   hydrates presentation only; it does not trigger map/network actions.
9. Resolved arguments are persisted before dispatch and batch context scope must
   match the turn scope. Restore normalizes complete assistant/tool groups. Compaction cannot create
   dangling tool rows or split a tool batch. Visible history is never compacted.

## Tool adapter

One policy registry covers all 22 map tools plus local follow-up. Read-only
memory/details/web and factual reads are explicitly classified. Exploration,
filters, relative radius expansion, local writes and navigation are not blindly
replayed after `started`. `save_to_favorites` becomes explicit set-to-saved;
repeating a save cannot remove a favorite. Tool effects are Codable snapshots.
The default Companion allowlist stays scoped to its supported UI; the legacy
map caller receives the full map catalog through the shared executor.

## Context and memory

`AgentContextProviding.snapshot(for:)` returns `AgentTurnContext`; each caller
supplies its authorized facts without granting new location/provider access.
The frozen scope and current facts use the same rendering in both callers.

`AgentMemoryProviding` exposes `context(for:)`, `recordCompletedTurn(_:)`,
`recall(query:scope:limit:)` and `forget(sessionID:)`/`forgetAll()`. A shared
device-local store records bounded conversational evidence with provenance and
stable turn IDs. It ingests only successfully persisted final user/assistant
turns, never system prompts/tool blobs. Replay is idempotent. Retrieval labels
dialogue as past statements, not verified travel facts. Scope matching prevents
an unrelated place conversation from silently becoming current context.

Existing SwiftData summaries remain compatible; both callers gain the common
memory provider rather than copying private account context. Existing deletion
and Forget Me paths clear the corresponding new records. No embeddings, new
model request, background agent or schema migration is required.

The accepted turn retains its memory admission epoch before the first await.
The map journal persists original context even for turns with no tools. Memory
deletion rotates the relevant epoch, so a late old turn cannot recreate forgotten
data, while the next explicit turn can acquire a fresh token. Legacy digest work
also carries a deletion generation and ingests only the current durable pair.

## Acceptance

- Production-core host tests: persistence failures at plan/start/result; canonical
  argument conflict; complete/started/planned replay; cancellation; total budget;
  on-disk reopen; legacy JSON decode and corrupt/unknown-version fail-closed.
- Adapter XCTest: both entry points use the executor; final-model retry preserves
  tool results; scope/rebind invalidates old work; favorite save is idempotent;
  restored cards keep IDs; unknown navigation is not reopened; memory writes are
  durable, deduplicated, scope-limited and deletable.
- Shared primary simulator only, one registered build reused for focused tests.
  Independent review and applicable latest-head CI before merge. Live model,
  provider, physical-device and production results remain separate evidence.

## Runtime semantics references

- Swift Task cancellation is cooperative: https://docs.swift.org/latest/documentation/swift/task/cancel%28%29/
- Foundation atomic writing replaces the destination after writing an auxiliary file: https://developer.apple.com/documentation/foundation/data/writingoptions

These establish cancellation and file replacement behavior; they do not promise
exactly-once completion of arbitrary external actions. The journal's uncertainty
state is the application-level boundary for that gap.
