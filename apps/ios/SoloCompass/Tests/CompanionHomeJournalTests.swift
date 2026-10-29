import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeJournalTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("journal-tests-\(UUID())/v1.json")
    }
    private func create(_ id: String, title: String) throws -> CompanionHomeToolCheckpoint {
        let data = try JSONSerialization.data(withJSONObject: ["action": "create", "title": title])
        return .init(id: id, name: "manage_follow_up", argumentsJSON: String(decoding: data, as: UTF8.self))
    }
    private func agent(for store: CompanionHomeStore) -> CompanionHomeAgent {
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
        agent.journalStore = store
        store.configure(agent: agent)
        return agent
    }

    func testFailedContinuationCannotReplanARenamedCreateOnRetry() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = agent(for: store)
        let planned = try create("original-call", title: "确认集合地点")
        var requests = 0
        agent.messageSender = { _, _ in
            requests += 1
            if requests == 1 { return .init(content: nil, toolCalls: [.init(id: planned.id, name: planned.name, argumentsJSON: planned.argumentsJSON)]) }
            throw URLError(.networkConnectionLost)
        }
        await store.send(text: "记下要确认集合地点")
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let taskID = try XCTUnwrap(store.commitments.first?.id)
        XCTAssertEqual(store.entries.first?.status, .failed)
        XCTAssertNotNil(store.toolJournal(for: entryID).first?.calls.first?.resultJSON)
        let restored = CompanionHomeStore(url: url)
        let retryAgent = self.agent(for: restored)
        let renamed = try create("replanned-call", title: "和对方核实集合位置")
        retryAgent.messageSender = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertTrue(messages.contains { $0.name == "manage_follow_up" && ($0.content?.contains("success") ?? false) })
            // An uncooperative model ignores unavailable tools. It still cannot execute.
            return .init(content: nil, toolCalls: [.init(id: renamed.id, name: renamed.name, argumentsJSON: renamed.argumentsJSON)])
        }
        await restored.retry(id: entryID)
        XCTAssertEqual(restored.commitments.count, 1)
        XCTAssertEqual(restored.commitments.first?.id, taskID)
        XCTAssertEqual(restored.toolJournal(for: entryID).count, 1)
        retryAgent.messageSender = { _, tools in
            XCTAssertTrue(tools.isEmpty)
            return .init(content: "事项已保留，尚未联系对方。", toolCalls: [])
        }
        await restored.retry(id: entryID)
        XCTAssertEqual(restored.entries.count, 2)
        XCTAssertEqual(restored.commitments.count, 1)
    }

    func testMultipleCreatesResumeTheUnfinishedPlanAfterCancellationAndRestart() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "记下两件事：确认地点，核对时间")
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let first = try create("first", title: "确认地点")
        let second = try create("second", title: "核对时间")
        XCTAssertTrue(store.checkpointToolPlan(entryID: entryID, batch: .init(calls: [first, second])))
        XCTAssertNotNil(store.executeFollowUpCheckpoint(entryID: entryID, callID: first.id))
        let firstID = try XCTUnwrap(store.commitments.first?.id)
        store.cancel() // Suspension boundary after one persisted result, before the next call.
        let restored = CompanionHomeStore(url: url)
        let agent = self.agent(for: restored)
        agent.messageSender = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertEqual(messages.filter { $0.role == .tool }.count, 2)
            return .init(content: "两件事均已记下。", toolCalls: [])
        }
        await restored.retry(id: entryID)
        XCTAssertEqual(restored.commitments.count, 2)
        XCTAssertEqual(restored.commitments.first?.id, firstID)
        XCTAssertTrue(restored.toolJournal(for: entryID).flatMap(\.calls).allSatisfy { $0.resultJSON != nil })
        XCTAssertEqual(CompanionHomeStore(url: url).commitments, restored.commitments)
    }

    func testCheckpointWriteFailurePreventsEffectsAndAtomicResultFailureRollsBack() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "请记下待办")
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let call = try create("create", title: "待办")
        let batch = CompanionHomeToolBatch(calls: [call])
        let directory = url.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("preserved")
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("blocker".utf8).write(to: directory)
        XCTAssertFalse(store.checkpointToolPlan(entryID: entryID, batch: batch))
        XCTAssertNil(store.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        XCTAssertTrue(store.commitments.isEmpty)
        XCTAssertTrue(store.toolJournal(for: entryID).isEmpty)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        XCTAssertTrue(store.checkpointToolPlan(entryID: entryID, batch: batch))
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("blocker".utf8).write(to: directory)
        XCTAssertNil(store.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        XCTAssertTrue(store.commitments.isEmpty)
        XCTAssertNil(store.toolJournal(for: entryID).first?.calls.first?.resultJSON)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        let restored = CompanionHomeStore(url: url)
        XCTAssertNotNil(restored.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        XCTAssertNotNil(restored.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        XCTAssertEqual(restored.commitments.count, 1)
    }

    func testCancelledLateExecutorCannotOverwriteResumedReceipt() async throws {
        let store = CompanionHomeStore(url: location())
        await store.send(text: "记下事项")
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let call = try create("stable-call", title: "只创建一次")
        XCTAssertTrue(store.checkpointToolPlan(entryID: entryID, batch: .init(calls: [call])))
        var resume: CheckedContinuation<Void, Never>?
        let cancelled = Task { () -> CompanionHomeToolCheckpoint? in
            await withCheckedContinuation { resume = $0 }
            return store.executeFollowUpCheckpoint(entryID: entryID, callID: call.id)
        }
        while resume == nil { await Task.yield() }
        cancelled.cancel()
        let completed = try XCTUnwrap(store.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        resume?.resume()
        let late = await cancelled.value
        XCTAssertNil(late)
        XCTAssertEqual(store.commitments.count, 1)
        XCTAssertEqual(store.toolJournal(for: entryID).first?.calls.first, completed)
    }

    func testSearchReturnsActualBoundedRecordsAndDoesNotClaimGPS() throws {
        let experience = try XCTUnwrap(ExperienceService.hardcodedSeed.first)
        let planned = CompanionHomeToolCheckpoint(id: "search", name: "search_places", argumentsJSON: #"{"query":"coffee"}"#)
        let result = try CompanionHomeAgent.groundedResult(for: planned, raw: #"{"ok":true,"added_count":6,"origin_source":"map_viewport"}"#,
                                                         effect: .experiences(Array(repeating: experience, count: 6)))
        let data = Data(try XCTUnwrap(result.resultJSON).utf8)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try XCTUnwrap(json["actual_experience_records"] as? [[String: Any]])
        XCTAssertEqual(records.count, 5)
        XCTAssertTrue((records[0]["record"] as? String)?.contains(experience.shortName) == true)
        XCTAssertNotNil(records[0]["sources"])
        XCTAssertEqual(json["search_area_basis"] as? String, "map_viewport")
        XCTAssertLessThanOrEqual(data.count, 64_000)
    }
}
