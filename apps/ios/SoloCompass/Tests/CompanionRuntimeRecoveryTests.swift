import XCTest
@testable import SoloCompass

@MainActor
final class CompanionRuntimeRecoveryTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("companion-runtime-\(UUID())/v1.json")
    }

    private func agent(for store: CompanionHomeStore) -> CompanionHomeAgent {
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
        store.configure(agent: agent)
        return agent
    }

    func testStartedFollowUpRestoresAsUncertainWithoutCreatingAnything() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "记下要确认时间")
        let id = try XCTUnwrap(store.entries.first?.id)
        let turn = AgentTurnIdentity(session: store.agentSession, turnID: id)
        let call = AgentToolCheckpoint(id: "started-create", name: "manage_follow_up", argumentsJSON: #"{"action":"create","title":"确认时间"}"#)
        XCTAssertTrue(store.savePlan(.init(calls: [call]), for: turn))
        XCTAssertTrue(store.saveStarted(callID: call.id, for: turn))
        XCTAssertFalse(store.saveStarted(callID: call.id, for: turn))
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.agentSession, turn.session)
        let agent = agent(for: restored)
        agent.messageSender = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertTrue(messages.contains { $0.role == .tool && ($0.content?.contains("uncertain") == true) })
            return .init(content: "上次记录是否完成还不确定，请重新确认要记录的事项。", toolCalls: [])
        }
        await restored.retry(id: id)
        XCTAssertTrue(restored.commitments.isEmpty)
        XCTAssertEqual(restored.toolBatches(for: turn).first?.calls.first?.state, .uncertain)
    }

    func testCanonicalRepeatedCallReusesReceiptAndChangedPayloadIsRejected() async throws {
        let store = CompanionHomeStore(url: location())
        await store.send(text: "记下待办")
        let id = try XCTUnwrap(store.entries.first?.id)
        let turn = AgentTurnIdentity(session: store.agentSession, turnID: id)
        let call = AgentToolCheckpoint(id: "stable", name: "manage_follow_up", argumentsJSON: #"{"title":"确认地点","action":"create"}"#)
        XCTAssertTrue(store.savePlan(.init(calls: [call]), for: turn))
        let receipt = try XCTUnwrap(store.executeFollowUpCheckpoint(entryID: id, callID: call.id))
        XCTAssertFalse(store.saveStarted(callID: call.id, for: turn))
        let reordered = AgentToolCheckpoint(id: call.id, name: call.name, argumentsJSON: #"{ "action": "create", "title": "确认地点" }"#)
        XCTAssertTrue(store.savePlan(.init(calls: [reordered]), for: turn))
        XCTAssertEqual(store.toolBatches(for: turn).last?.calls.first, receipt)
        let changed = AgentToolCheckpoint(id: call.id, name: call.name, argumentsJSON: #"{"action":"create","title":"其他地点"}"#)
        XCTAssertFalse(store.savePlan(.init(calls: [changed]), for: turn))
        XCTAssertEqual(store.commitments.count, 1)
    }

    func testCompletedLegacyReadReusesResultWithoutRouterAndKeepsCardIdentity() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "看看之前的资料")
        let id = try XCTUnwrap(store.entries.first?.id)
        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: store.exportedSnapshotData()) as? [String: Any])
        snapshot["toolJournals"] = [id.uuidString: [["id": UUID().uuidString, "calls": [[
            "id": "legacy-web", "name": "web_search", "argumentsJSON": #"{"query":"旧资料"}"#,
            "resultJSON": #"{"success":true,"past":true}"#, "sourceTitles": ["历史来源"]
        ]]]]]
        try JSONSerialization.data(withJSONObject: snapshot).write(to: url, options: .atomic)
        let restored = CompanionHomeStore(url: url)
        let checkpoint = try XCTUnwrap(restored.toolJournal(for: id).first?.calls.first)
        XCTAssertEqual(checkpoint.state, .completed)
        let agent = agent(for: restored)
        agent.messageSender = { messages, _ in
            XCTAssertTrue(messages.contains { $0.toolCallId == "legacy-web" && $0.content == checkpoint.resultJSON })
            return .init(content: "这是之前保存的资料。", toolCalls: [])
        }
        await restored.retry(id: id)
        XCTAssertEqual(restored.entries.last?.status, .delivered)
        XCTAssertEqual(CompanionHomeStore(url: url).toolJournal(for: id).first?.calls.first?.cardID, checkpoint.cardID)
    }

    func testLargeContextKeepsFollowUpIDsAndMemoryInsideClosedBoundedBlocks() async throws {
        let seed = try XCTUnwrap(ExperienceService.hardcodedSeed.first)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(seed)) as? [String: Any])
        object["title"] = String(repeating: "large-record-", count: 500)
        object["whyItMatters"] = String(repeating: "long descriptive evidence ", count: 500)
        let large = try JSONDecoder().decode(Experience.self, from: JSONSerialization.data(withJSONObject: object))
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false),
                                       experienceService: ExperienceService(seed: Array(repeating: large, count: 20)))
        let memory = DeviceAgentMemoryStore(fileURL: location())
        let session = AgentSessionDescriptor(id: UUID().uuidString, scope: "global")
        XCTAssertTrue(memory.recordCompletedTurn(.init(identity: .init(session: session, turnID: UUID()),
                                                       userText: "memory-evidence-marker " + String(repeating: "past ", count: 500),
                                                       assistantText: String(repeating: "past reply ", count: 500))))
        agent.memory = memory
        agent.searchArea = { .init(name: "杭州", latitude: 30.2741, longitude: 120.1551) }
        let active = (0..<50).map { index in
            CompanionHomeCommitment(title: "follow-up-\(index)-" + String(repeating: "a", count: 130),
                                    note: String(repeating: "detail ", count: 400))
        }
        agent.activeCommitments = { active }
        let context = await agent.snapshot(for: session)
        let rendered = context.renderForPrompt()
        XCTAssertLessThan(context.facts.count, 12_000)
        XCTAssertTrue(rendered.contains("memory-evidence-marker"))
        XCTAssertTrue(rendered.contains("omittedDetailCount"))
        XCTAssertTrue(rendered.contains("Additional local experience records omitted: 15"))
        for item in active { XCTAssertTrue(rendered.contains(item.id.uuidString)) }
        for tag in ["local_experience_records", "active_local_follow_ups", "past_device_dialogue"] {
            XCTAssertTrue(rendered.contains("<" + tag + ">"))
            XCTAssertTrue(rendered.contains("</" + tag + ">"))
        }
        XCTAssertTrue(context.selectedAreaFact?.contains("杭州") == true)
        XCTAssertFalse(context.selectedAreaFact?.contains("memory-evidence-marker") == true)
    }

    func testLegacyImplicitSearchNeverResolvesItsOldPlanFromANewLiveCity() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "原来地图附近的书店")
        let id = try XCTUnwrap(store.entries.first?.id)
        let planned = AgentToolCheckpoint(id: "legacy-implicit", name: "search_places", argumentsJSON: #"{"query":"books"}"#)
        XCTAssertTrue(store.checkpointToolPlan(entryID: id, batch: .init(calls: [planned])))
        let restored = CompanionHomeStore(url: url)
        var executions = 0
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []), toolExecutor: { _ in
            executions += 1
            return (#"{"ok":true,"origin_source":"map_viewport"}"#, nil)
        })
        restored.configure(searchArea: { .init(name: "New city", latitude: 1.35, longitude: 103.82) })
        restored.configure(agent: agent)
        agent.messageSender = { messages, tools in
            XCTAssertTrue(tools.isEmpty, "Unknown legacy scope requires a new explicit user turn")
            XCTAssertTrue(messages.contains { $0.role == .tool && ($0.content?.contains("legacy_search_scope_unavailable") == true) })
            return .init(content: "请选择搜索范围并开始一个新问题。", toolCalls: [])
        }
        await restored.retry(id: id)
        XCTAssertEqual(executions, 0)
        let receipt = try XCTUnwrap(CompanionHomeStore(url: url).toolJournal(for: id).first?.calls.first)
        XCTAssertEqual(receipt.state, .uncertain)
        XCTAssertNil(receipt.resolvedArgumentsJSON)
        XCTAssertEqual(receipt.argumentsJSON, planned.argumentsJSON)
        XCTAssertEqual(restored.entries.first?.status, .delivered)
    }

    func testLegacyPlannedScopedSearchPersistsResolvedCoordinatesBeforeDispatch() async throws {
        let url = location()
        let scope = CompanionHomeAreaScope(area: .init(name: "Tokyo", latitude: 35.7, longitude: 139.7), query: nil, category: nil)
        let entry = CompanionHomeEntry(role: .user, text: "就在这片区域", searchArea: scope)
        let entries = try JSONSerialization.jsonObject(with: JSONEncoder().encode([entry]))
        let snapshot: [String: Any] = ["version": 1, "entries": entries, "composerDraft": "", "people": [], "selectedPeopleIDs": [], "invites": []]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: snapshot).write(to: url)
        let store = CompanionHomeStore(url: url)
        let planned = AgentToolCheckpoint(id: "legacy-pending", name: "search_places", argumentsJSON: #"{"query":"books"}"#)
        XCTAssertTrue(store.checkpointToolPlan(entryID: entry.id, batch: .init(calls: [planned])))
        var executions = 0
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []), toolExecutor: { call in
            executions += 1
            let durable = try? XCTUnwrap(CompanionHomeStore(url: url).toolJournal(for: entry.id).first?.calls.first)
            XCTAssertEqual(durable?.state, .started)
            XCTAssertEqual(durable?.resolvedArgumentsJSON, call.argumentsJSON)
            let args = try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any]
            XCTAssertEqual(args?["latitude"] as? Double, 35.7)
            XCTAssertEqual(args?["longitude"] as? Double, 139.7)
            return (#"{"ok":true,"origin_source":"explicit_coordinates"}"#, nil)
        })
        store.configure(searchArea: { .init(name: "Singapore", latitude: 1.35, longitude: 103.82) })
        store.configure(agent: agent)
        agent.messageSender = { _, _ in .init(content: "原区域的查询结果已保留。", toolCalls: []) }
        await store.retry(id: entry.id)
        XCTAssertEqual(executions, 1)
        XCTAssertEqual(store.entries.first?.status, .delivered)
        XCTAssertEqual(store.toolJournal(for: entry.id).first?.calls.first?.argumentsJSON, planned.argumentsJSON)
    }

    func testReceivedReplyDoesNotEnterMemoryUntilFinalSaveSucceeds() async throws {
        let url = location()
        let memory = DeviceAgentMemoryStore(fileURL: location())
        let store = CompanionHomeStore(url: url, memory: memory)
        let agent = agent(for: store)
        let directory = url.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("preserved")
        var requests = 0
        agent.messageSender = { _, _ in
            requests += 1
            try FileManager.default.moveItem(at: directory, to: backup)
            try Data("storage-blocker".utf8).write(to: directory)
            return .init(content: "我会按你给出的节奏聊。", toolCalls: [])
        }
        await store.send(text: "今天想走慢一点")
        let id = try XCTUnwrap(store.entries.first?.id)
        XCTAssertEqual(store.entries.first?.status, .failed)
        XCTAssertTrue(memory.context(for: store.agentSession).records.isEmpty)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        await store.retry(id: id)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(store.entries.first?.status, .delivered)
        XCTAssertEqual(memory.context(for: store.agentSession).records.count, 1)
    }

    func testForgetRejectsSavedOldReplyButNewInputLearnsInSameSession() async throws {
        let url = location()
        let memory = DeviceAgentMemoryStore(fileURL: location())
        let store = CompanionHomeStore(url: url, memory: memory)
        let agent = agent(for: store)
        let directory = url.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("preserved")
        var requests = 0
        agent.messageSender = { _, _ in
            requests += 1
            if requests == 1 {
                try FileManager.default.moveItem(at: directory, to: backup)
                try Data("storage-blocker".utf8).write(to: directory)
            }
            return .init(content: "可以按自己的节奏出发。", toolCalls: [])
        }
        await store.send(text: "这段话随后会被遗忘")
        let oldEntry = try XCTUnwrap(store.entries.first)
        let session = store.agentSession
        XCTAssertNotNil(oldEntry.memoryEpoch)
        XCTAssertTrue(memory.forgetAll())
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        await store.retry(id: oldEntry.id)
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(memory.context(for: session).records.isEmpty)
        await store.send(text: "这是遗忘之后的新对话")
        let newEntry = try XCTUnwrap(store.entries.last(where: { $0.role == .user }))
        XCTAssertEqual(store.agentSession, session)
        XCTAssertNotEqual(newEntry.memoryEpoch, oldEntry.memoryEpoch)
        XCTAssertEqual(memory.context(for: session).records.map(\.identity.turnID), [newEntry.id])
        let restored = CompanionHomeStore(url: url, memory: memory)
        XCTAssertEqual(restored.entries.first?.memoryEpoch, oldEntry.memoryEpoch)
        XCTAssertEqual(restored.entries.last(where: { $0.role == .user })?.memoryEpoch, newEntry.memoryEpoch)
    }

    func testMemoryIsWrittenOnlyAfterFinalPersistenceAndClearInvalidatesOldSession() async throws {
        let url = location()
        let memory = DeviceAgentMemoryStore(fileURL: url.appendingPathExtension("test-memory"))
        let store = CompanionHomeStore(url: url, memory: memory)
        let agent = agent(for: store)
        agent.messageSender = { _, _ in throw URLError(.networkConnectionLost) }
        await store.send(text: "我想安静散步")
        let id = try XCTUnwrap(store.entries.first?.id)
        let session = store.agentSession
        XCTAssertTrue(memory.context(for: session).records.isEmpty)
        agent.messageSender = { _, _ in .init(content: "可以先找一段安静的小路。", toolCalls: []) }
        await store.retry(id: id)
        XCTAssertEqual(memory.context(for: session).records.count, 1)
        XCTAssertEqual(memory.context(for: session).records.first?.identity.turnID, id)
        XCTAssertTrue(store.clearLocalData())
        XCTAssertTrue(memory.context(for: session).records.isEmpty)
        XCTAssertNotEqual(store.agentSession, session)
        XCTAssertEqual(CompanionHomeStore(url: url).agentSession, store.agentSession)
        let stale = AgentTurnIdentity(session: session, turnID: id)
        XCTAssertFalse(store.savePlan(.init(calls: [.init(id: "late", name: "web_search", argumentsJSON: "{}")]), for: stale))
    }
}
