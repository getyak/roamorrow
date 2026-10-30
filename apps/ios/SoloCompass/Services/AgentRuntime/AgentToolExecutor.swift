import Foundation

/// Dispatch ordering and recovery are shared by every device conversation adapter.
@MainActor
final class AgentToolExecutor {
    private struct Lease: Hashable {
        var journal: String
        var turn: AgentTurnIdentity
    }

    private static var activeTurns: Set<Lease> = []

    static func canonicalArguments(_ json: String) throws -> String {
        try AgentToolCheckpoint.canonicalArguments(json)
    }

    func execute(
        _ batch: AgentToolBatch,
        for turn: AgentTurnIdentity,
        journal: any AgentExecutionJournal,
        allowedTools: Set<String>,
        isCurrent: () -> Bool,
        perform: (AgentToolCheckpoint) async throws -> AgentToolCheckpoint
    ) async throws -> [AgentToolCheckpoint] {
        try checkCurrent(isCurrent)
        let journalKey = (journal as? FileAgentExecutionJournal)?.url.standardizedFileURL.resolvingSymlinksInPath().path
            ?? String(describing: ObjectIdentifier(journal))
        let lease = Lease(journal: journalKey, turn: turn)
        guard Self.activeTurns.insert(lease).inserted else { throw AgentRuntimeError.executionInProgress }
        defer { Self.activeTurns.remove(lease) }

        guard batch.context == nil || batch.context?.scope == turn.session.scope else {
            throw AgentRuntimeError.identityConflict
        }
        let history = journal.toolBatches(for: turn)
        var known: [String: AgentToolCheckpoint] = [:]
        for previous in history.flatMap(\.calls) {
            try validate(previous)
            if let existing = known[previous.id] {
                guard try existing.hasSameIdentity(as: previous) else { throw AgentRuntimeError.identityConflict }
            }
            known[previous.id] = previous
        }
        var incomingIDs: Set<String> = []
        for call in batch.calls {
            try validate(call)
            guard allowedTools.contains(call.name), AgentToolPolicy.knownTools.contains(call.name) else {
                throw AgentRuntimeError.toolNotAllowed
            }
            guard incomingIDs.insert(call.id).inserted else { throw AgentRuntimeError.identityConflict }
            if let previous = known[call.id] {
                guard try previous.hasSameIdentity(as: call) else { throw AgentRuntimeError.identityConflict }
            } else {
                // A caller cannot manufacture an already-completed receipt to bypass dispatch.
                guard call.state == .planned, call.resultJSON == nil else { throw AgentRuntimeError.invalidResult }
                known[call.id] = call
            }
        }
        guard known.count <= 5 else { throw AgentRuntimeError.budgetExceeded }
        if let previousBatch = history.first(where: { $0.id == batch.id }) {
            guard previousBatch.calls.map(\.id) == batch.calls.map(\.id) else {
                throw AgentRuntimeError.identityConflict
            }
        }
        var durableBatch = batch
        for index in durableBatch.calls.indices {
            var call = durableBatch.calls[index]
            call.resolvedArgumentsJSON = call.resolvedArgumentsJSON ?? call.argumentsJSON
            if let previous = known[call.id], history.flatMap(\.calls).contains(where: { $0.id == call.id }) {
                call = previous
            } else if AgentToolPolicy.recovery(for: call.name) == .neverReplayStarted,
                      let previous = (history.flatMap(\.calls) + Array(durableBatch.calls.prefix(index)))
                        .first(where: { $0.id != call.id && sameAction($0, call) }) {
                call.cardID = previous.cardID
                call.resolvedOrigin = previous.resolvedOrigin
            }
            durableBatch.calls[index] = call
        }
        try checkCurrent(isCurrent)
        guard journal.savePlan(durableBatch, for: turn) else { throw AgentRuntimeError.persistenceFailed }

        var results: [AgentToolCheckpoint] = []
        for requested in batch.calls {
            try checkCurrent(isCurrent)
            guard let planned = journal.toolBatches(for: turn).flatMap(\.calls).first(where: { $0.id == requested.id }) else {
                throw AgentRuntimeError.persistenceFailed
            }
            try validate(planned)
            guard try planned.hasSameIdentity(as: requested) else { throw AgentRuntimeError.identityConflict }
            if (planned.state == .planned || planned.state == .started),
               AgentToolPolicy.recovery(for: planned.name) == .neverReplayStarted,
               let previous = journal.toolBatches(for: turn).flatMap(\.calls).first(where: {
                   $0.id != planned.id && $0.state != .planned && sameAction($0, planned)
               }) {
                var reused = previous.state == .started ? uncertainResult(previous) : previous
                reused.id = planned.id
                reused.name = planned.name
                reused.argumentsJSON = planned.argumentsJSON
                reused.resolvedArgumentsJSON = planned.resolvedArgumentsJSON
                guard journal.saveResult(reused, for: turn) else { throw AgentRuntimeError.persistenceFailed }
                results.append(reused)
                continue
            }
            switch planned.state {
            case .completed, .uncertain:
                results.append(planned)
                continue
            case .started:
                let uncertain = uncertainResult(planned)
                guard journal.saveResult(uncertain, for: turn) else { throw AgentRuntimeError.persistenceFailed }
                results.append(uncertain)
                continue
            case .planned:
                break
            }
            guard journal.saveStarted(callID: planned.id, for: turn) else {
                throw AgentRuntimeError.persistenceFailed
            }
            try checkCurrent(isCurrent)
            var started = planned
            started.state = .started
            var observed = try await perform(started)
            // Do not check cancellation before recording an observed side effect under its original turn.
            guard try observed.hasSameIdentity(as: planned), observed.resultJSON != nil,
                  observed.implementationVersion == AgentToolCheckpoint.currentImplementationVersion else {
                throw AgentRuntimeError.invalidResult
            }
            guard observed.resolvedOrigin == planned.resolvedOrigin else { throw AgentRuntimeError.identityConflict }
            let resolved = observed.resolvedArgumentsJSON ?? planned.resolvedArgumentsJSON ?? planned.argumentsJSON
            guard try AgentToolCheckpoint.canonicalArguments(resolved)
                == AgentToolCheckpoint.canonicalArguments(planned.resolvedArgumentsJSON ?? planned.argumentsJSON) else {
                throw AgentRuntimeError.identityConflict
            }
            observed.state = .completed
            observed.cardID = planned.cardID
            observed.resolvedArgumentsJSON = observed.resolvedArgumentsJSON ?? planned.resolvedArgumentsJSON
            guard journal.saveResult(observed, for: turn) else { throw AgentRuntimeError.persistenceFailed }
            try checkCurrent(isCurrent)
            results.append(observed)
        }
        try checkCurrent(isCurrent)
        return results
    }

    private func sameAction(_ lhs: AgentToolCheckpoint, _ rhs: AgentToolCheckpoint) -> Bool {
        guard lhs.name == rhs.name else { return false }
        let left = try? AgentToolCheckpoint.canonicalArguments(lhs.resolvedArgumentsJSON ?? lhs.argumentsJSON)
        let right = try? AgentToolCheckpoint.canonicalArguments(rhs.resolvedArgumentsJSON ?? rhs.argumentsJSON)
        return left != nil && left == right
    }

    private func uncertainResult(_ call: AgentToolCheckpoint) -> AgentToolCheckpoint {
        var uncertain = call
        uncertain.state = .uncertain
        uncertain.resultJSON = #"{"success":false,"uncertain":true,"error":"The previous action was interrupted and may have happened. Ask for a new explicit action in a new turn instead of retrying it."}"#
        return uncertain
    }

    private func validate(_ call: AgentToolCheckpoint) throws {
        guard call.implementationVersion == AgentToolCheckpoint.currentImplementationVersion else {
            throw AgentRuntimeError.unsupportedVersion
        }
        guard !call.id.isEmpty, !call.name.isEmpty else { throw AgentRuntimeError.invalidArguments }
        _ = try AgentToolCheckpoint.canonicalArguments(call.argumentsJSON)
        if let resolved = call.resolvedArgumentsJSON { _ = try AgentToolCheckpoint.canonicalArguments(resolved) }
        switch call.state {
        case .completed, .uncertain:
            guard call.resultJSON != nil else { throw AgentRuntimeError.invalidResult }
        case .planned, .started:
            guard call.resultJSON == nil else { throw AgentRuntimeError.invalidResult }
        }
    }

    private func checkCurrent(_ isCurrent: () -> Bool) throws {
        guard !Task.isCancelled, isCurrent() else { throw CancellationError() }
    }
}
