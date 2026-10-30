import Foundation

private enum Failure: Error { case expected, assertion(String) }
@MainActor private var assertionCount = 0

@MainActor
private func check(_ value: Bool, _ message: String) throws {
    assertionCount += 1
    if !value { throw Failure.assertion(message) }
}

@main
struct AgentRuntimeHost {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let turn = AgentTurnIdentity(session: .init(id: "session", scope: "global"), turnID: UUID())
        let executor = AgentToolExecutor()
        let call = AgentToolCheckpoint(id: "save", name: "save_to_favorites", argumentsJSON: #"{"place_id":"p"}"#)
        let batch = AgentToolBatch(calls: [call])
        var dispatched = 0
        func result(_ call: AgentToolCheckpoint) -> AgentToolCheckpoint {
            var receipt = call
            receipt.resultJSON = #"{"success":true}"#
            return receipt
        }
        // A side effect can succeed while its receipt write fails. Reopen must not repeat it.
        var writes = 0
        let failedURL = root.appendingPathComponent("failed-result.json")
        let failingJournal = FileAgentExecutionJournal(url: failedURL) { data, url in
            writes += 1
            if writes == 3 { throw Failure.expected }
            try data.write(to: url, options: .atomic)
        }
        do {
            _ = try await executor.execute(batch, for: turn, journal: failingJournal,
                allowedTools: [call.name], isCurrent: { true }) { call in
                dispatched += 1
                return result(call)
            }
            throw Failure.assertion("result failure must throw")
        } catch AgentRuntimeError.persistenceFailed { }
        try check(dispatched == 1, "first side effect executed once")
        let reopened = FileAgentExecutionJournal(url: failedURL)
        let recovered = try await executor.execute(batch, for: turn, journal: reopened,
            allowedTools: [call.name], isCurrent: { true }) { call in
            dispatched += 1
            return result(call)
        }
        try check(dispatched == 1 && recovered.first?.state == .uncertain,
                  "started mutation must become durable uncertainty")
        try check(FileAgentExecutionJournal(url: failedURL).toolBatches(for: turn).first?.calls.first?.state == .uncertain,
                  "uncertain result survives reopen")

        // Both pre-dispatch persistence boundaries must fail closed.
        for failedWrite in [1, 2] {
            var count = 0
            let journal = FileAgentExecutionJournal(url: root.appendingPathComponent("fail-\(failedWrite).json")) { data, url in
                count += 1
                if count == failedWrite { throw Failure.expected }
                try data.write(to: url, options: .atomic)
            }
            do {
                _ = try await executor.execute(batch, for: turn, journal: journal,
                    allowedTools: [call.name], isCurrent: { true }) { call in
                    dispatched += 1
                    return result(call)
                }
                throw Failure.assertion("plan/start failure must throw")
            } catch AgentRuntimeError.persistenceFailed { }
            try check(dispatched == 1, "failed durable boundary cannot dispatch")
        }

        let identityJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("identity.json"))
        let read = AgentToolCheckpoint(id: "read", name: "web_search", argumentsJSON: #"{"query":"a","nested":{"x":1,"y":2}}"#)
        let readBatch = AgentToolBatch(calls: [read])
        _ = try await executor.execute(readBatch, for: turn, journal: identityJournal,
            allowedTools: [read.name], isCurrent: { true }) { call in
            dispatched += 1
            return result(call)
        }
        var reordered = read
        reordered.argumentsJSON = #"{ "nested": {"y":2,"x":1}, "query":"a" }"#
        let replay = try await executor.execute(AgentToolBatch(calls: [reordered]), for: turn,
            journal: identityJournal, allowedTools: [read.name], isCurrent: { true }) { call in
            dispatched += 1
            return result(call)
        }
        try check(dispatched == 2 && replay.first?.cardID == read.cardID, "canonical replay reuses receipt and card")
        var conflict = read
        conflict.argumentsJSON = #"{"query":"different"}"#
        do {
            _ = try await executor.execute(AgentToolBatch(calls: [conflict]), for: turn,
                journal: identityJournal, allowedTools: [read.name], isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("changed call identity must conflict")
        } catch AgentRuntimeError.identityConflict { }

        let budgetJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("budget.json"))
        for index in 0..<5 {
            let item = AgentToolCheckpoint(id: "b\(index)", name: read.name, argumentsJSON: "{}")
            _ = try await executor.execute(.init(calls: [item]), for: turn, journal: budgetJournal,
                allowedTools: [read.name], isCurrent: { true }, perform: { result($0) })
        }
        do {
            _ = try await executor.execute(.init(calls: [.init(id: "six", name: read.name, argumentsJSON: "{}")]),
                for: turn, journal: FileAgentExecutionJournal(url: root.appendingPathComponent("budget.json")),
                allowedTools: [read.name], isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("sixth call must fail across batches and reopen")
        } catch AgentRuntimeError.budgetExceeded { }

        // Cancellation after an observed result cannot erase its durable receipt or dispatch next call.
        let cancelJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("cancel.json"))
        var active = true
        var cancelledDispatches = 0
        let second = AgentToolCheckpoint(id: "second", name: read.name, argumentsJSON: "{}")
        do {
            _ = try await executor.execute(.init(calls: [read, second]), for: turn, journal: cancelJournal,
                allowedTools: [read.name], isCurrent: { active }) { call in
                cancelledDispatches += 1
                active = false
                return result(call)
            }
            throw Failure.assertion("stale execution must throw cancellation")
        } catch is CancellationError { }
        try check(cancelledDispatches == 1, "stale invocation stops before next dispatch")
        let cancelReload = FileAgentExecutionJournal(url: root.appendingPathComponent("cancel.json"))
        try check(cancelReload.toolBatches(for: turn).first?.calls.first?.state == .completed,
                  "observed result survives stale invocation")

        let plannedJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("planned.json"))
        try check(plannedJournal.savePlan(readBatch, for: turn), "planned batch durable")
        try check(plannedJournal.saveStarted(callID: read.id, for: turn), "read started durable")
        var readRetries = 0
        _ = try await executor.execute(readBatch, for: turn, journal: plannedJournal,
            allowedTools: [read.name], isCurrent: { true }) { call in
            readRetries += 1
            return result(call)
        }
        try check(readRetries == 0, "interrupted reads require a fresh turn without an atomic retry claim")

        let claimJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("claim.json"))
        try check(claimJournal.savePlan(batch, for: turn), "claim plan durable")
        try check(claimJournal.saveStarted(callID: call.id, for: turn), "first claimant owns dispatch")
        try check(!FileAgentExecutionJournal(url: root.appendingPathComponent("claim.json"))
            .saveStarted(callID: call.id, for: turn), "second claimant cannot claim started action")

        let actionJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("action.json"))
        var effects = 0
        let saved = try await executor.execute(batch, for: turn, journal: actionJournal,
            allowedTools: [call.name], isCurrent: { true }) { call in
            effects += 1
            return result(call)
        }
        var alias = call
        alias.id = "new-call-id-same-action"
        alias.argumentsJSON = #"{ "place_id" : "p" }"#
        let aliased = try await executor.execute(.init(calls: [alias]), for: turn, journal: actionJournal,
            allowedTools: [call.name], isCurrent: { true }) { call in
            effects += 1
            return result(call)
        }
        try check(effects == 1 && aliased.first?.id == alias.id && aliased.first?.cardID == saved.first?.cardID,
                  "new call ID cannot repeat the same resolved side effect")

        let aliasReplay = try await executor.execute(.init(calls: [alias]), for: turn, journal: actionJournal,
            allowedTools: [call.name], isCurrent: { true }) { call in
            effects += 1
            return result(call)
        }
        try check(effects == 1 && aliasReplay.first?.cardID == saved.first?.cardID,
                  "replaying an aliased completed call remains read-only")

        let deletionJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("deleted.json"))
        try check(deletionJournal.savePlan(batch, for: turn), "deletion fixture planned")
        try check(deletionJournal.saveStarted(callID: call.id, for: turn), "deletion fixture started")
        try check(deletionJournal.forget(sessionID: turn.session.id), "forget writes tombstone")
        var late = result(call)
        late.state = .completed
        try check(!deletionJournal.saveResult(late, for: turn), "late result cannot resurrect deleted conversation")
        let deletedReload = FileAgentExecutionJournal(url: root.appendingPathComponent("deleted.json"))
        try check(deletedReload.isForgotten(sessionID: turn.session.id) && !deletedReload.savePlan(batch, for: turn),
                  "deletion tombstone survives reopen")

        let badScope = AgentToolBatch(calls: [read], context: .init(capturedAt: Date(), scope: "experience:other", facts: "x"))
        do {
            _ = try await executor.execute(badScope, for: turn, journal: identityJournal,
                allowedTools: [read.name], isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("cross-scope context must reject")
        } catch AgentRuntimeError.identityConflict { }

        let allURL = root.appendingPathComponent("forget-all.json")
        let allJournal = FileAgentExecutionJournal(url: allURL)
        try check(allJournal.savePlan(batch, for: turn), "forget-all fixture planned")
        try check(allJournal.saveStarted(callID: call.id, for: turn), "forget-all fixture started")
        try check(allJournal.forgetAll(), "forget-all tombstones existing sessions")
        try check(!allJournal.saveResult(late, for: turn) && FileAgentExecutionJournal(url: allURL)
            .isForgotten(sessionID: turn.session.id), "forget-all rejects late results after reopen")
        let freshTurn = AgentTurnIdentity(session: .init(id: UUID().uuidString, scope: "global"), turnID: UUID())
        try check(allJournal.savePlan(batch, for: freshTurn), "fresh session can start after forget-all")

        let taskURL = root.appendingPathComponent("task-cancel.json")
        let taskJournal = FileAgentExecutionJournal(url: taskURL)
        let cancelledTask = Task { @MainActor in
            try await AgentToolExecutor().execute(batch, for: turn, journal: taskJournal,
                allowedTools: [call.name], isCurrent: { true }) { call in
                withUnsafeCurrentTask { $0?.cancel() }
                return result(call)
            }
        }
        do {
            _ = try await cancelledTask.value
            throw Failure.assertion("cancelled Task cannot return active UI results")
        } catch is CancellationError { }
        try check(FileAgentExecutionJournal(url: taskURL).toolBatches(for: turn).first?.calls.first?.state == .completed,
                  "Task cancellation still records observed receipt")

        let concurrentURL = root.appendingPathComponent("concurrent.json")
        let concurrentJournal = FileAgentExecutionJournal(url: concurrentURL)
        var release: CheckedContinuation<Void, Never>?
        var concurrentEffects = 0
        let runningTask = Task { @MainActor in
            try await AgentToolExecutor().execute(batch, for: turn, journal: concurrentJournal,
                allowedTools: [call.name], isCurrent: { true }) { call in
                concurrentEffects += 1
                await withCheckedContinuation { release = $0 }
                return result(call)
            }
        }
        while release == nil { await Task.yield() }
        let concurrentAliasURL = root.appendingPathComponent("concurrent-alias.json")
        try FileManager.default.createSymbolicLink(at: concurrentAliasURL, withDestinationURL: concurrentURL)
        do {
            _ = try await AgentToolExecutor().execute(batch, for: turn,
                journal: FileAgentExecutionJournal(url: concurrentAliasURL), allowedTools: [call.name],
                isCurrent: { true }) { call in
                concurrentEffects += 1
                return result(call)
            }
            throw Failure.assertion("concurrent claimant cannot dispatch")
        } catch AgentRuntimeError.executionInProgress { }
        release?.resume()
        _ = try await runningTask.value
        try check(concurrentEffects == 1, "independent executors cannot dispatch same active action twice")
        try check(FileAgentExecutionJournal(url: concurrentURL).toolBatches(for: turn).first?.calls.first?.state == .completed,
                  "second claimant cannot overwrite first observed result")

        let resolvedJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("resolved.json"))
        var resolvedFirst = call
        resolvedFirst.resolvedArgumentsJSON = #"{"place_id":"resolved"}"#
        _ = try await executor.execute(.init(calls: [resolvedFirst]), for: turn, journal: resolvedJournal,
            allowedTools: [call.name], isCurrent: { true }) { call in
            try check(resolvedJournal.toolBatches(for: turn).first?.calls.first?.resolvedArgumentsJSON == #"{"place_id":"resolved"}"#,
                      "resolved arguments are durable before dispatch")
            return result(call)
        }
        var resolvedAlias = resolvedFirst
        resolvedAlias.id = "different-resolved-call-id"
        resolvedAlias.argumentsJSON = #"{"place_id":"other-original"}"#
        var resolvedEffects = 0
        _ = try await executor.execute(.init(calls: [resolvedAlias]), for: turn, journal: resolvedJournal,
            allowedTools: [call.name], isCurrent: { true }) { call in
            resolvedEffects += 1
            return result(call)
        }
        try check(resolvedEffects == 0, "side-effect alias compares resolved rather than model arguments")

        let contextURL = root.appendingPathComponent("context.json")
        let contextJournal = FileAgentExecutionJournal(url: contextURL)
        let frozenContext = AgentTurnContext(capturedAt: Date(timeIntervalSince1970: 123), scope: "global",
            facts: "Original facts", memoryEpoch: UUID())
        try check(contextJournal.saveContext(frozenContext, for: turn), "text-only context persists before model")
        let contextReload = FileAgentExecutionJournal(url: contextURL)
        try check(contextReload.context(for: turn) == frozenContext && contextReload.toolBatches(for: turn).isEmpty,
                  "text-only context and memory epoch survive reopen without tool batches")
        var changedContext = frozenContext
        changedContext.memoryEpoch = UUID()
        try check(!contextReload.saveContext(changedContext, for: turn)
            && contextReload.context(for: turn) == frozenContext, "context first write stays frozen")
        var wrongContext = frozenContext
        wrongContext.scope = "experience:other"
        try check(!contextReload.saveContext(wrongContext, for: turn), "cross-scope context cannot persist")
        let failedContextURL = root.appendingPathComponent("context-failed.json")
        let failedContext = FileAgentExecutionJournal(url: failedContextURL) { _, _ in throw Failure.expected }
        try check(!failedContext.saveContext(frozenContext, for: turn) && failedContext.context(for: turn) == nil,
                  "context write failure never advances memory or disk")
        try check(contextReload.forget(sessionID: turn.session.id)
            && contextReload.context(for: turn) == nil && !contextReload.saveContext(frozenContext, for: turn),
                  "context tombstone blocks late model context")

        let importURL = root.appendingPathComponent("import.json")
        var failImport = true
        let importJournal = FileAgentExecutionJournal(url: importURL) { data, url in
            if failImport { throw Failure.expected }
            try data.write(to: url, options: .atomic)
        }
        var oldObserved = read
        oldObserved.resultJSON = "{}"
        oldObserved.state = .completed
        let oldPending = AgentToolCheckpoint(id: "old-missing", name: call.name, argumentsJSON: "{}")
        let oldBatch = AgentToolBatch(calls: [oldObserved, oldPending])
        try check(!importJournal.importObservedBatch(oldBatch, for: turn)
            && importJournal.toolBatches(for: turn).isEmpty, "failed legacy import cannot leave dispatchable partial plan")
        failImport = false
        try check(importJournal.importObservedBatch(oldBatch, for: turn), "legacy import commits atomically")
        let imported = FileAgentExecutionJournal(url: importURL).toolBatches(for: turn).first?.calls
        try check(imported?.first?.state == .completed && imported?.last?.state == .started,
                  "legacy import preserves observed result and makes missing result conservative")
        var importedDispatches = 0
        let importedResults = try await executor.execute(oldBatch, for: turn, journal: importJournal,
            allowedTools: [read.name, call.name], isCurrent: { true }) { call in
            importedDispatches += 1
            return result(call)
        }
        try check(importedDispatches == 0 && importedResults.last?.state == .uncertain,
                  "legacy recovery never dispatches historical missing side effect")

        let legacy = Data(#"{"id":"legacy","name":"web_search","argumentsJSON":"{}","resultJSON":"{\"ok\":true}"}"#.utf8)
        let decoded = try JSONDecoder().decode(AgentToolCheckpoint.self, from: legacy)
        try check(decoded.state == .completed && decoded.sourceTitles.isEmpty && decoded.placeIDs.isEmpty,
                  "legacy completed result remains readable")
        let pending = try JSONDecoder().decode(AgentToolCheckpoint.self,
            from: Data(#"{"id":"pending","name":"web_search","argumentsJSON":"{}"}"#.utf8))
        try check(pending.state == .planned, "legacy unfinished call remains planned")

        let corruptURL = root.appendingPathComponent("corrupt.json")
        try Data("broken json".utf8).write(to: corruptURL)
        let corrupt = FileAgentExecutionJournal(url: corruptURL)
        try check(!corrupt.savePlan(batch, for: turn), "corruption cannot be overwritten")
        do {
            _ = try await executor.execute(batch, for: turn, journal: corrupt,
                allowedTools: [call.name], isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("corrupt journal must fail closed")
        } catch AgentRuntimeError.unsupportedVersion { }
        var newer = read
        newer.implementationVersion = 999
        do {
            _ = try await executor.execute(.init(calls: [newer]), for: turn, journal: identityJournal,
                allowedTools: [read.name], isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("unknown checkpoint version must fail closed")
        } catch AgentRuntimeError.unsupportedVersion { }
        do {
            _ = try await executor.execute(.init(calls: [.init(id: "unknown", name: "not_registered", argumentsJSON: "{}")]),
                for: turn, journal: identityJournal, allowedTools: ["not_registered"],
                isCurrent: { true }, perform: { result($0) })
            throw Failure.assertion("unknown policy must reject even if caller allows it")
        } catch AgentRuntimeError.toolNotAllowed { }
        let futureURL = root.appendingPathComponent("future.json")
        try Data(#"{"version":999,"records":[]}"#.utf8).write(to: futureURL)
        try check(!FileAgentExecutionJournal(url: futureURL).savePlan(batch, for: turn),
                  "future journal envelope cannot be overwritten")
        print("Agent runtime host regressions passed (\(assertionCount) assertions)")
    }
}
