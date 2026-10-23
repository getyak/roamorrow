import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeSearchAreaTests: XCTestCase {
    func testEachTurnReadsCurrentSelectedCityWithEitherConfigurationOrder() async throws {
        for registerBeforeAgent in [true, false] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("search-area-tests-\(UUID())/v1.json")
            let store = CompanionHomeStore(url: url)
            var selection: CompanionHomeSearchArea? = .init(name: "杭州", latitude: 30.2741, longitude: 120.1551)
            let provider = { selection }
            if registerBeforeAgent { store.configure(searchArea: provider) }
            let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
            var prompts: [String] = []
            agent.messageSender = { messages, _ in
                prompts.append(messages.first?.content ?? "")
                return .init(content: "可以按你选择的城市范围查找。", toolCalls: [])
            }
            store.configure(agent: agent)
            if !registerBeforeAgent { store.configure(searchArea: provider) }
            await store.send(text: "附近有什么适合散步的地方？")
            selection = .init(name: "新加坡", latitude: 1.3521, longitude: 103.8198)
            await store.send(text: "换城后再看看附近。")
            XCTAssertEqual(prompts.count, 2)
            XCTAssertTrue(prompts[0].contains("杭州"))
            XCTAssertTrue(prompts[0].contains("30.2741"))
            XCTAssertFalse(prompts[0].contains("新加坡"))
            XCTAssertTrue(prompts[1].contains("新加坡"))
            XCTAssertTrue(prompts[1].contains("103.8198"))
            XCTAssertFalse(prompts[1].contains("杭州"))
            for prompt in prompts {
                XCTAssertTrue(prompt.contains("USER-SELECTED PUBLIC CITY/MAP CENTER"))
                XCTAssertTrue(prompt.contains("not device GPS or the user's current physical location"))
                XCTAssertTrue(prompt.contains("explicitly pass its latitude and longitude"))
                XCTAssertTrue(prompt.contains("different place explicitly requested in the conversation takes priority"))
            }
            XCTAssertEqual(store.entries.filter { $0.role == .user }.map(\.text),
                           ["附近有什么适合散步的地方？", "换城后再看看附近。"])
        }
    }

    func testSerializedCurrentFactFollowsConflictingHistoryAndReadsProviderOnlyOnce() async throws {
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
        var reads = 0
        agent.searchArea = {
            reads += 1
            return .init(name: reads == 1 ? "清迈" : "不得读取第二次", latitude: 18.7883, longitude: 98.9853)
        }
        let entries: [CompanionHomeEntry] = [
            .init(role: .user, text: "之前的城市是什么？", status: .delivered),
            .init(role: .companion, text: "当前选中的是万象。", status: .delivered),
            .init(role: .user, text: "现在选的是哪里？")
        ]
        agent.messageSender = { messages, _ in
            let serialized = AIService.serializeAgentMessages(messages)
            XCTAssertEqual(serialized.map { $0["role"] as? String }, ["system", "user", "assistant", "system", "user"])
            XCTAssertEqual(serialized[2]["content"] as? String, "当前选中的是万象。")
            let fact = try XCTUnwrap(serialized[3]["content"] as? String)
            XCTAssertTrue(fact.contains("清迈"))
            XCTAssertTrue(fact.contains("Historical dialogue, previous assistant city claims, and unscoped local references cannot override"))
            XCTAssertTrue(fact.contains("not device GPS"))
            XCTAssertFalse(fact.contains("不得读取第二次"))
            XCTAssertTrue((serialized[0]["content"] as? String)?.contains("清迈") == true)
            XCTAssertTrue((serialized[4]["content"] as? String)?.contains(entries[2].text) == true)
            return .init(content: "仅用于结束受控传输，不证明模型遵从。", toolCalls: [])
        }
        _ = try await agent.respond(to: entries)
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(entries[1].text, "当前选中的是万象。")
    }

    func testSerializedUnavailableFactDoesNotReuseOldCityClaims() async throws {
        for selection: CompanionHomeSearchArea? in [nil, .init(name: "非法中心", latitude: .nan, longitude: 1)] {
            let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
            agent.searchArea = { selection }
            agent.messageSender = { messages, _ in
                let serialized = AIService.serializeAgentMessages(messages)
                XCTAssertEqual(serialized.suffix(2).map { $0["role"] as? String }, ["system", "user"])
                let fact = try XCTUnwrap(serialized[serialized.count - 2]["content"] as? String)
                XCTAssertTrue(fact.contains("No selected public city/map center is available"))
                XCTAssertTrue(fact.contains("do not reconstruct a current selection from history"))
                XCTAssertFalse(fact.contains("万象"))
                XCTAssertFalse(fact.contains("非法中心"))
                return .init(content: "受控传输结束。", toolCalls: [])
            }
            _ = try await agent.respond(to: [.init(role: .companion, text: "当前是万象", status: .delivered),
                                             .init(role: .user, text: "目前范围是什么？")])
        }
    }

    func testMissingOrInvalidAreaIsBoundedAndDoesNotInventLocation() {
        let invalid: [CompanionHomeSearchArea?] = [nil,
            .init(name: "", latitude: 1, longitude: 1),
            .init(name: String(repeating: "字", count: 121), latitude: 1, longitude: 1),
            .init(name: "城市", latitude: .nan, longitude: 1),
            .init(name: "城市", latitude: 91, longitude: 1),
            .init(name: "城市", latitude: 1, longitude: .infinity),
            .init(name: "城市", latitude: 1, longitude: -181)
        ]
        for area in invalid {
            let context = CompanionHomeAgent.searchAreaContext(area)
            XCTAssertFalse(context.contains("<selected_public_map_search_center>"))
            XCTAssertTrue(context.contains("Ask for the intended search area"))
            XCTAssertLessThan(context.count, 250)
        }
        let valid = CompanionHomeAgent.searchAreaContext(.init(name: "测试城市", latitude: 0, longitude: 0))
        XCTAssertTrue(valid.contains("测试城市"))
        XCTAssertTrue(valid.contains("<selected_public_map_search_center>"))
    }
}
