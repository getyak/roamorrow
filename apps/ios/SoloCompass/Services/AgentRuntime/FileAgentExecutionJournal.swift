import Foundation

/// A transactional device journal. Failed writes never advance its in-memory snapshot.
@MainActor
final class FileAgentExecutionJournal: AgentExecutionJournal {
    typealias AtomicWriter = (Data, URL) throws -> Void

    static let shared = FileAgentExecutionJournal(url:
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Roamorrow/AgentRuntime/map-journal-v1.json"))

    private struct Record: Codable {
        var turn: AgentTurnIdentity
        var batches: [AgentToolBatch]
        var context: AgentTurnContext? = nil
    }

    private struct Snapshot: Codable {
        var version: Int = 1
        var records: [Record] = []
        var forgottenSessionIDs: Set<String> = []

        private enum CodingKeys: String, CodingKey { case version, records, forgottenSessionIDs }

        init() {}

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = try values.decode(Int.self, forKey: .version)
            records = try values.decode([Record].self, forKey: .records)
            forgottenSessionIDs = try values.decodeIfPresent(Set<String>.self, forKey: .forgottenSessionIDs) ?? []
        }
    }

    let url: URL
    private let atomicWriter: AtomicWriter
    private var snapshot = Snapshot()
    private(set) var isAvailable = true

    init(url: URL, atomicWriter: @escaping AtomicWriter = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }) {
        self.url = url
        self.atomicWriter = atomicWriter
        reload()
    }

    func toolBatches(for turn: AgentTurnIdentity) -> [AgentToolBatch] {
        reload()
        guard isAvailable else { return [unavailableBatch()] }
        guard !snapshot.forgottenSessionIDs.contains(turn.session.id), scopeMatches(turn) else {
            return [unavailableBatch()]
        }
        return snapshot.records.first(where: { $0.turn == turn })?.batches ?? []
    }

    func context(for turn: AgentTurnIdentity) -> AgentTurnContext? {
        reload()
        guard canWrite(turn), let record = snapshot.records.first(where: { $0.turn == turn }) else { return nil }
        return record.context ?? record.batches.compactMap(\.context).first
    }

    /// The first durable context also covers text-only turns with no tool calls.
    func saveContext(_ context: AgentTurnContext, for turn: AgentTurnIdentity) -> Bool {
        reload()
        guard canWrite(turn), context.scope == turn.session.scope else { return false }
        var candidate = snapshot
        if let index = candidate.records.firstIndex(where: { $0.turn == turn }) {
            if let frozen = candidate.records[index].context
                ?? candidate.records[index].batches.compactMap(\.context).first {
                guard frozen == context else { return false }
                if candidate.records[index].context != nil { return true }
            }
            candidate.records[index].context = context
        } else {
            candidate.records.append(.init(turn: turn, batches: [], context: context))
        }
        return persist(candidate)
    }

    /// Trusted historical evidence only. Missing receipts become started in the same
    /// atomic write, so an interrupted migration can never leave a dispatchable plan.
    func importObservedBatch(_ batch: AgentToolBatch, for turn: AgentTurnIdentity) -> Bool {
        reload()
        guard canWrite(turn), batch.context == nil || batch.context?.scope == turn.session.scope else { return false }
        var candidate = snapshot
        let recordIndex: Int
        if let index = candidate.records.firstIndex(where: { $0.turn == turn }) {
            recordIndex = index
        } else {
            candidate.records.append(.init(turn: turn, batches: []))
            recordIndex = candidate.records.count - 1
        }
        var record = candidate.records[recordIndex]
        let frozenContext = record.context ?? record.batches.compactMap(\.context).first
        if let frozenContext, let incoming = batch.context, frozenContext != incoming { return false }
        record.context = frozenContext ?? batch.context
        var imported = batch
        imported.context = record.context
        var known: [String: AgentToolCheckpoint] = [:]
        for call in record.batches.flatMap(\.calls) { known[call.id] = call }
        var ids: Set<String> = []
        for index in imported.calls.indices {
            var call = imported.calls[index]
            guard ids.insert(call.id).inserted,
                  call.implementationVersion == AgentToolCheckpoint.currentImplementationVersion,
                  AgentToolPolicy.knownTools.contains(call.name),
                  (try? AgentToolCheckpoint.canonicalArguments(call.argumentsJSON)) != nil else { return false }
            if let previous = known[call.id] {
                guard previous.matchesIdentity(call) else { return false }
                if previous.state == .completed || previous.state == .uncertain {
                    call = previous
                } else {
                    call.cardID = previous.cardID
                    call.resolvedOrigin = previous.resolvedOrigin
                    call.resolvedArgumentsJSON = previous.resolvedArgumentsJSON ?? call.resolvedArgumentsJSON
                }
            }
            if call.resultJSON == nil {
                guard call.state == .planned || call.state == .started else { return false }
                call.state = .started
            } else {
                guard call.state == .completed || call.state == .uncertain else { return false }
            }
            call.resolvedArgumentsJSON = call.resolvedArgumentsJSON ?? call.argumentsJSON
            imported.calls[index] = call
            known[call.id] = call
        }
        guard known.count <= 5 else { return false }
        if let index = record.batches.firstIndex(where: { $0.id == batch.id }) {
            guard record.batches[index].calls.map(\.id) == imported.calls.map(\.id) else { return false }
            record.batches[index] = imported
        } else {
            record.batches.append(imported)
        }
        for batchIndex in record.batches.indices {
            for callIndex in record.batches[batchIndex].calls.indices {
                let id = record.batches[batchIndex].calls[callIndex].id
                if ids.contains(id), let updated = known[id] { record.batches[batchIndex].calls[callIndex] = updated }
            }
        }
        candidate.records[recordIndex] = record
        guard valid(candidate) else { return false }
        return persist(candidate)
    }

    func savePlan(_ batch: AgentToolBatch, for turn: AgentTurnIdentity) -> Bool {
        reload()
        guard canWrite(turn), batch.context == nil || batch.context?.scope == turn.session.scope else { return false }
        var candidate = snapshot
        let recordIndex: Int
        if let index = candidate.records.firstIndex(where: { $0.turn == turn }) {
            recordIndex = index
        } else {
            candidate.records.append(.init(turn: turn, batches: []))
            recordIndex = candidate.records.count - 1
        }
        let frozenContext = candidate.records[recordIndex].context
            ?? candidate.records[recordIndex].batches.compactMap(\.context).first
        if let frozenContext, let incoming = batch.context, frozenContext != incoming { return false }
        candidate.records[recordIndex].context = frozenContext ?? batch.context
        var batches = candidate.records[recordIndex].batches
        var known: [String: AgentToolCheckpoint] = [:]
        for call in batches.flatMap(\.calls) {
            if let previous = known[call.id], !previous.matchesIdentity(call) { return false }
            known[call.id] = call
        }
        var stored = batch
        stored.context = candidate.records[recordIndex].context
        var incomingIDs: Set<String> = []
        for index in stored.calls.indices {
            let call = stored.calls[index]
            guard incomingIDs.insert(call.id).inserted,
                  call.implementationVersion == AgentToolCheckpoint.currentImplementationVersion,
                  (try? AgentToolCheckpoint.canonicalArguments(call.argumentsJSON)) != nil else { return false }
            if let previous = known[call.id] {
                guard previous.matchesIdentity(call) else { return false }
                stored.calls[index] = previous
            } else {
                guard call.state == .planned, call.resultJSON == nil else { return false }
                stored.calls[index].resolvedArgumentsJSON = call.resolvedArgumentsJSON ?? call.argumentsJSON
                known[call.id] = stored.calls[index]
            }
        }
        guard known.count <= 5 else { return false }
        if let existing = batches.firstIndex(where: { $0.id == batch.id }) {
            guard batches[existing].calls.map(\.id) == stored.calls.map(\.id) else { return false }
            // Original assistant/context and all receipts remain frozen on retries.
            return true
        }
        batches.append(stored)
        candidate.records[recordIndex].batches = batches
        return persist(candidate)
    }

    func saveStarted(callID: String, for turn: AgentTurnIdentity) -> Bool {
        reload()
        guard canWrite(turn),
              let index = snapshot.records.firstIndex(where: { $0.turn == turn }),
              let call = snapshot.records[index].batches.flatMap(\.calls).first(where: { $0.id == callID }),
              call.implementationVersion == AgentToolCheckpoint.currentImplementationVersion,
              call.state == .planned
        else { return false }
        var started = call
        started.state = .started
        started.resolvedArgumentsJSON = call.resolvedArgumentsJSON ?? call.argumentsJSON
        return replace(started, recordIndex: index)
    }

    func saveResult(_ result: AgentToolCheckpoint, for turn: AgentTurnIdentity) -> Bool {
        reload()
        guard canWrite(turn),
              result.implementationVersion == AgentToolCheckpoint.currentImplementationVersion,
              result.state == .completed || result.state == .uncertain, result.resultJSON != nil,
              let index = snapshot.records.firstIndex(where: { $0.turn == turn }),
              let planned = snapshot.records[index].batches.flatMap(\.calls).first(where: { $0.id == result.id }),
              planned.matchesIdentity(result), result.resolvedOrigin == planned.resolvedOrigin,
              planned.state == .planned || planned.state == .started
        else { return false }
        var stored = result
        stored.cardID = planned.cardID
        stored.resolvedArgumentsJSON = result.resolvedArgumentsJSON ?? planned.resolvedArgumentsJSON
        return replace(stored, recordIndex: index)
    }

    func isForgotten(sessionID: String) -> Bool {
        reload()
        return !isAvailable || snapshot.forgottenSessionIDs.contains(sessionID)
    }

    @discardableResult
    func forget(sessionID: String) -> Bool {
        reload()
        guard isAvailable else { return false }
        var candidate = snapshot
        candidate.records.removeAll { $0.turn.session.id == sessionID }
        candidate.forgottenSessionIDs.insert(sessionID)
        return persist(candidate)
    }

    @discardableResult
    func forgetAll() -> Bool {
        reload()
        guard isAvailable else { return false }
        var candidate = snapshot
        candidate.forgottenSessionIDs.formUnion(candidate.records.map(\.turn.session.id))
        candidate.records.removeAll()
        return persist(candidate)
    }

    private func replace(_ result: AgentToolCheckpoint, recordIndex: Int) -> Bool {
        var candidate = snapshot
        for batchIndex in candidate.records[recordIndex].batches.indices {
            for callIndex in candidate.records[recordIndex].batches[batchIndex].calls.indices
                where candidate.records[recordIndex].batches[batchIndex].calls[callIndex].id == result.id {
                candidate.records[recordIndex].batches[batchIndex].calls[callIndex] = result
            }
        }
        return persist(candidate)
    }

    private func canWrite(_ turn: AgentTurnIdentity) -> Bool {
        isAvailable && !snapshot.forgottenSessionIDs.contains(turn.session.id) && scopeMatches(turn)
    }

    private func scopeMatches(_ turn: AgentTurnIdentity) -> Bool {
        !snapshot.records.contains {
            $0.turn.session.id == turn.session.id && $0.turn.session.scope != turn.session.scope
        }
    }

    private func persist(_ candidate: Snapshot) -> Bool {
        do {
            let data = try JSONEncoder().encode(candidate)
            try atomicWriter(data, url)
            snapshot = candidate
            return true
        } catch {
            return false
        }
    }

    private func reload() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Do not silently recover a previously corrupt/unavailable store by treating it as empty.
            return
        }
        do {
            let decoded = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
            guard valid(decoded) else {
                isAvailable = false
                return
            }
            snapshot = decoded
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }

    private func valid(_ decoded: Snapshot) -> Bool {
        guard decoded.version == 1 else { return false }
        var turns: Set<AgentTurnIdentity> = []
        var scopes: [String: String] = [:]
        for record in decoded.records {
            guard turns.insert(record.turn).inserted,
                  !decoded.forgottenSessionIDs.contains(record.turn.session.id),
                  record.context == nil || record.context?.scope == record.turn.session.scope else { return false }
            if let scope = scopes[record.turn.session.id], scope != record.turn.session.scope { return false }
            scopes[record.turn.session.id] = record.turn.session.scope
            var batchIDs: Set<UUID> = []
            var known: [String: AgentToolCheckpoint] = [:]
            for batch in record.batches {
                guard batchIDs.insert(batch.id).inserted,
                      batch.context == nil || batch.context?.scope == record.turn.session.scope else { return false }
                var callIDs: Set<String> = []
                for call in batch.calls {
                    guard callIDs.insert(call.id).inserted, !call.id.isEmpty, !call.name.isEmpty,
                          call.implementationVersion == AgentToolCheckpoint.currentImplementationVersion,
                          (try? AgentToolCheckpoint.canonicalArguments(call.argumentsJSON)) != nil else { return false }
                    if let resolved = call.resolvedArgumentsJSON,
                       (try? AgentToolCheckpoint.canonicalArguments(resolved)) == nil { return false }
                    switch call.state {
                    case .completed, .uncertain:
                        guard call.resultJSON != nil else { return false }
                    case .planned, .started:
                        guard call.resultJSON == nil else { return false }
                    }
                    if let previous = known[call.id], previous != call { return false }
                    known[call.id] = call
                }
            }
            guard known.count <= 5 else { return false }
        }
        return true
    }

    // The protocol's read is nonthrowing; an unsupported checkpoint prevents any executor dispatch.
    private func unavailableBatch() -> AgentToolBatch {
        AgentToolBatch(calls: [.init(id: "journal-unavailable", name: "journal-unavailable",
                                    argumentsJSON: "{}", implementationVersion: Int.max)])
    }
}
