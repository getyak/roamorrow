import Foundation
import XCTest
@testable import SoloCompass

@MainActor
final class AgentRuntimeTests: XCTestCase {
    private func turn(_ sessionID: String = "session") -> AgentTurnIdentity {
        .init(session: .init(id: sessionID, scope: "global"), turnID: UUID())
    }

    private func receipt(_ call: AgentToolCheckpoint) -> AgentToolCheckpoint {
        var observed = call
        observed.resultJSON = #"{"success":true}"#
        observed.state = .completed
        return observed
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("agent-runtime-\(UUID()).json")
    }

    func testFailedSideEffectReceiptCannotDispatchAgainAfterReopen() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let call = AgentToolCheckpoint(id: "save", name: "save_to_favorites", argumentsJSON: "{}")
        let batch = AgentToolBatch(calls: [call])
        var writes = 0
        let journal = FileAgentExecutionJournal(url: url) { data, url in
            writes += 1
            if writes == 3 { throw CocoaError(.fileWriteOutOfSpace) }
            try data.write(to: url, options: .atomic)
        }
        var effects = 0
        do {
            _ = try await AgentToolExecutor().execute(batch, for: identity, journal: journal,
                allowedTools: [call.name], isCurrent: { true }) {
                effects += 1
                return self.receipt($0)
            }
            XCTFail("Failed receipt must stop the model continuation")
        } catch { XCTAssertEqual(error as? AgentRuntimeError, .persistenceFailed) }
        let reopened = FileAgentExecutionJournal(url: url)
        let results = try await AgentToolExecutor().execute(batch, for: identity, journal: reopened,
            allowedTools: [call.name], isCurrent: { true }) {
            effects += 1
            return self.receipt($0)
        }
        XCTAssertEqual(effects, 1)
        XCTAssertEqual(results.first?.state, .uncertain)
        XCTAssertEqual(FileAgentExecutionJournal(url: url).toolBatches(for: identity).first?.calls.first?.state, .uncertain)
    }

    func testDifferentCallIDCannotRepeatSameResolvedSideEffect() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let journal = FileAgentExecutionJournal(url: url)
        let call = AgentToolCheckpoint(id: "one", name: "save_to_favorites", argumentsJSON: #"{"id":"place"}"#)
        var effects = 0
        let first = try await AgentToolExecutor().execute(.init(calls: [call]), for: identity,
            journal: journal, allowedTools: [call.name], isCurrent: { true }) {
            effects += 1
            return self.receipt($0)
        }
        let alias = AgentToolCheckpoint(id: "two", name: call.name, argumentsJSON: #"{ "id" : "place" }"#)
        let second = try await AgentToolExecutor().execute(.init(calls: [alias]), for: identity,
            journal: journal, allowedTools: [call.name], isCurrent: { true }) {
            effects += 1
            return self.receipt($0)
        }
        XCTAssertEqual(effects, 1)
        XCTAssertEqual(second.first?.id, "two")
        XCTAssertEqual(second.first?.cardID, first.first?.cardID)
    }

    func testStaleInvocationPersistsObservedResultBeforeStopping() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let journal = FileAgentExecutionJournal(url: url)
        let calls = ["one", "two"].map { AgentToolCheckpoint(id: $0, name: "web_search", argumentsJSON: "{}") }
        var active = true
        var dispatches = 0
        do {
            _ = try await AgentToolExecutor().execute(.init(calls: calls), for: identity,
                journal: journal, allowedTools: ["web_search"], isCurrent: { active }) {
                dispatches += 1
                active = false
                return self.receipt($0)
            }
            XCTFail("Stale invocation cannot return a result for active UI")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(dispatches, 1)
        let restored = FileAgentExecutionJournal(url: url).toolBatches(for: identity).first?.calls
        XCTAssertEqual(restored?.first?.state, .completed)
        XCTAssertEqual(restored?.last?.state, .planned)
    }

    func testDeletionTombstoneRejectsLateResultAndSurvivesReload() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let journal = FileAgentExecutionJournal(url: url)
        let call = AgentToolCheckpoint(id: "one", name: "web_search", argumentsJSON: "{}")
        XCTAssertTrue(journal.savePlan(.init(calls: [call]), for: identity))
        XCTAssertTrue(journal.saveStarted(callID: call.id, for: identity))
        XCTAssertTrue(journal.forget(sessionID: identity.session.id))
        XCTAssertFalse(journal.saveResult(receipt(call), for: identity))
        let reopened = FileAgentExecutionJournal(url: url)
        XCTAssertTrue(reopened.isForgotten(sessionID: identity.session.id))
        XCTAssertFalse(reopened.savePlan(.init(calls: [call]), for: identity))
    }

    func testStartedClaimIsExclusiveAcrossJournalInstances() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let journal = FileAgentExecutionJournal(url: url)
        let call = AgentToolCheckpoint(id: "one", name: "web_search", argumentsJSON: "{}")
        XCTAssertTrue(journal.savePlan(.init(calls: [call]), for: identity))
        XCTAssertTrue(journal.saveStarted(callID: call.id, for: identity))
        XCTAssertFalse(FileAgentExecutionJournal(url: url).saveStarted(callID: call.id, for: identity))
    }

    func testTextOnlyContextEpochIsDurableFrozenAndDeleted() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        let journal = FileAgentExecutionJournal(url: url)
        let context = AgentTurnContext(capturedAt: Date(timeIntervalSince1970: 123), scope: "global",
                                       facts: "Frozen", memoryEpoch: UUID())
        XCTAssertTrue(journal.saveContext(context, for: identity))
        let reopened = FileAgentExecutionJournal(url: url)
        XCTAssertEqual(reopened.context(for: identity), context)
        XCTAssertTrue(reopened.toolBatches(for: identity).isEmpty)
        var changed = context
        changed.memoryEpoch = UUID()
        XCTAssertFalse(reopened.saveContext(changed, for: identity))
        XCTAssertEqual(reopened.context(for: identity), context)
        XCTAssertTrue(reopened.forgetAll())
        XCTAssertNil(reopened.context(for: identity))
        XCTAssertFalse(reopened.saveContext(context, for: identity))
        let failedURL = temporaryURL()
        let failed = FileAgentExecutionJournal(url: failedURL) { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertFalse(failed.saveContext(context, for: turn("failed")))
        XCTAssertNil(failed.context(for: identity))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failedURL.path))
    }

    func testHistoricalImportFailureCannotLeaveDispatchablePartialPlan() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let identity = turn()
        var fail = true
        let journal = FileAgentExecutionJournal(url: url) { data, url in
            if fail { throw CocoaError(.fileWriteOutOfSpace) }
            try data.write(to: url, options: .atomic)
        }
        let observed = AgentToolCheckpoint(id: "read", name: "web_search", argumentsJSON: "{}", resultJSON: "{}")
        let missing = AgentToolCheckpoint(id: "save", name: "save_to_favorites", argumentsJSON: "{}")
        let historical = AgentToolBatch(calls: [observed, missing])
        XCTAssertFalse(journal.importObservedBatch(historical, for: identity))
        XCTAssertTrue(journal.toolBatches(for: identity).isEmpty)
        fail = false
        XCTAssertTrue(journal.importObservedBatch(historical, for: identity))
        let reopened = FileAgentExecutionJournal(url: url)
        XCTAssertEqual(reopened.toolBatches(for: identity).first?.calls.map(\.state), [.completed, .started])
        var dispatched = 0
        let result = try await AgentToolExecutor().execute(historical, for: identity, journal: reopened,
            allowedTools: [observed.name, missing.name], isCurrent: { true }) {
            dispatched += 1
            return self.receipt($0)
        }
        XCTAssertEqual(dispatched, 0)
        XCTAssertEqual(result.last?.state, .uncertain)
    }

    func testLegacyJSONDefaultsAndCanonicalIdentity() throws {
        let data = Data(#"{"id":"old","name":"web_search","argumentsJSON":"{}","resultJSON":"{}"}"#.utf8)
        let old = try JSONDecoder().decode(AgentToolCheckpoint.self, from: data)
        let secondDecode = try JSONDecoder().decode(AgentToolCheckpoint.self, from: data)
        XCTAssertEqual(old.state, .completed)
        XCTAssertEqual(old.cardID, secondDecode.cardID)
        XCTAssertEqual(old.placeIDs, [])
        let left = AgentToolCheckpoint(id: "id", name: "web_search", argumentsJSON: #"{"a":1,"b":2}"#)
        let right = AgentToolCheckpoint(id: "id", name: "web_search", argumentsJSON: #"{ "b":2, "a":1 }"#)
        XCTAssertTrue(try left.hasSameIdentity(as: right))
        XCTAssertThrowsError(try AgentToolCheckpoint.canonicalArguments("[]"))
    }
}
