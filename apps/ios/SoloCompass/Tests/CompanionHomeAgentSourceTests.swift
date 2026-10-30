import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeAgentSourceTests: XCTestCase {
    func testLocalReferenceIncludesActualURLWithoutClaimingLiveLookup() {
        let label = CompanionHomeAgent.sourceLabel(kind: "本机参考", title: "本机地点 · 手工资料", url: "https://example.org/original")
        XCTAssertEqual(label, "本机参考 · 本机地点 · 手工资料\nhttps://example.org/original")
        XCTAssertFalse(label.contains("实时"))
    }

    func testSearchLabelRetainsActualReturnedLink() {
        XCTAssertEqual(CompanionHomeAgent.sourceLabel(kind: "本轮网页检索", title: "实际结果", url: "https://example.org/result"),
                       "本轮网页检索 · 实际结果\nhttps://example.org/result")
    }

    func testMissingAndUnsupportedLinksDoNotInventAnAddress() {
        for url in [nil, "file:///private/local", "javascript:alert(1)", "https:///", "not a URL"] {
            XCTAssertEqual(CompanionHomeAgent.sourceLabel(kind: "本机参考", title: "原有来源", url: url), "本机参考 · 原有来源")
        }
    }

    func testSearchGroundingPreservesTheRoutersActualOrigin() throws {
        let planned = CompanionHomeToolCheckpoint(id: "search", name: "search_places", argumentsJSON: #"{"query":"books"}"#)
        for origin in ["map_viewport", "map_selection", "selected_city", "authorized_location", "explicit_coordinates"] {
            let raw = #"{"ok":true,"origin_source":""# + origin + #"","eligible_count":0,"search_exhausted":true}"#
            let result = try CompanionHomeAgent.groundedResult(for: planned, raw: raw, effect: nil)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(result.resultJSON).utf8)) as? [String: Any])
            XCTAssertEqual(json["origin_source"] as? String, origin)
            XCTAssertEqual(json["search_area_basis"] as? String, origin)
            XCTAssertFalse((json["search_area_basis"] as? String)?.contains("default") == true)
        }
    }

    func testMissingSearchOriginStaysUnknownEvenWithPartialCoordinates() throws {
        let planned = CompanionHomeToolCheckpoint(id: "search", name: "search_places", argumentsJSON: #"{"query":"books","latitude":35.7}"#)
        let result = try CompanionHomeAgent.groundedResult(for: planned, raw: #"{"ok":false,"outcome":"fatal"}"#, effect: nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(result.resultJSON).utf8)) as? [String: Any])
        XCTAssertEqual(json["origin_source"] as? String, "unknown")
        XCTAssertEqual(json["search_area_basis"] as? String, "unknown")
    }

    func testRespondCancelsTheModelAtTheWholeTurnDeadline() async throws {
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []), turnTimeout: .milliseconds(20))
        var cancelled = false
        var requests = 0
        agent.messageSender = { _, _ in
            requests += 1
            do { try await Task.sleep(for: .seconds(5)) }
            catch { cancelled = true; throw error }
            return .init(content: "Late response", toolCalls: [])
        }
        do {
            _ = try await agent.respond(to: [.init(role: .user, text: "Find a bookstore")])
            XCTFail("An expired model response cannot be accepted")
        } catch {
            guard case CompanionHomeAgent.Failure.timedOut = error else { return XCTFail("Expected the whole-turn deadline") }
        }
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(cancelled)
    }

    func testCurrentPlaceScopeIsOneTurnAndCutsUnrelatedLocalRecords() async throws {
        let experiences = Array(ExperienceService.hardcodedSeed.prefix(2))
        let selected = try XCTUnwrap(experiences.first)
        let scope = CompanionHomePlaceScope(experienceID: selected.id, name: selected.shortName, cityCode: selected.location.cityCode,
                                            latitude: selected.location.coordinates[1], longitude: selected.location.coordinates[0])
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: experiences))
        var prompts: [[VoiceAgentSession.Message]] = []
        agent.messageSender = { messages, _ in
            prompts.append(messages)
            return .init(content: "Acknowledged", toolCalls: [])
        }
        let scoped = CompanionHomeEntry(role: .user, text: "这家适合读书吗？", placeScope: scope)
        _ = try await agent.respond(to: [scoped])
        _ = try await agent.respond(to: [scoped, .init(role: .companion, text: "资料待核实", status: .delivered), .init(role: .user, text: "换个话题")])
        let currentFact = try XCTUnwrap(prompts.first?.dropLast().last?.content)
        XCTAssertTrue(currentFact.contains(scope.experienceID))
        let nextFact = try XCTUnwrap(prompts.last?.dropLast().last?.content)
        XCTAssertTrue(nextFact.contains("No place or area scope was selected for this message"))
        if experiences.count == 2 {
            XCTAssertFalse((prompts.first?.first?.content ?? "").contains(experiences[1].id), "A place-scoped question must not carry unrelated local venue records")
        }
    }

    func testFrozenAreaScopeOverridesLaterMapSelectionForThisRequest() async throws {
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
        var liveMapReads = 0
        agent.searchArea = {
            liveMapReads += 1
            return .init(name: "Singapore", latitude: 1.35, longitude: 103.82)
        }
        let area = CompanionHomeAreaScope(area: .init(name: "Tokyo", latitude: 35.7, longitude: 139.7), query: "bookstores", category: "work",
                                          experienceIDs: [], latitudeDelta: 0.02, longitudeDelta: 0.02)
        agent.messageSender = { messages, _ in
            let system = messages.first?.content ?? ""
            let fact = messages.dropLast().last?.content ?? ""
            XCTAssertTrue(system.contains("Tokyo"))
            XCTAssertFalse(system.contains("Singapore"))
            XCTAssertTrue(fact.contains("bookstores"))
            XCTAssertTrue(fact.contains("user_selected_area_for_this_message"))
            XCTAssertFalse(fact.contains("Singapore"))
            return .init(content: "I will use the area you asked about", toolCalls: [])
        }
        _ = try await agent.respond(to: [.init(role: .user, text: "就这片区域", searchArea: area)])
        XCTAssertEqual(liveMapReads, 0, "A queued question owns its frozen area, even if the live map moved")
    }

    func testSearchExecutionAndPersistedRetryUseFrozenAreaInsteadOfLiveMap() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("frozen-search-\(UUID())/v1.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let frozen = CompanionHomeSearchArea(name: "Tokyo", latitude: 35.7, longitude: 139.7)
        let live = CompanionHomeSearchArea(name: "Singapore", latitude: 1.35, longitude: 103.82)
        let store = CompanionHomeStore(url: url)
        XCTAssertTrue(store.setNextTurnArea(frozen))
        var executed: [[String: Any]] = []
        func makeAgent(_ owner: CompanionHomeStore, callID: String, failAfterSearch: Bool) -> CompanionHomeAgent {
            let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []), toolExecutor: { call in
                if let data = call.argumentsJSON.data(using: .utf8), let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    executed.append(args)
                }
                return (#"{"ok":true,"origin_source":"explicit_coordinates","eligible_count":0,"search_exhausted":true}"#, nil)
            })
            agent.journalStore = owner
            var rounds = 0
            agent.messageSender = { _, _ in
                rounds += 1
                if rounds == 1 { return .init(content: nil, toolCalls: [.init(id: callID, name: "search_places", argumentsJSON: #"{"query":"books"}"#)]) }
                if failAfterSearch { throw URLError(.networkConnectionLost) }
                return .init(content: "No verified match in the selected area", toolCalls: [])
            }
            owner.configure(searchArea: { live })
            owner.configure(agent: agent)
            return agent
        }
        let firstAgent = makeAgent(store, callID: "search-first", failAfterSearch: true)
        await store.send(text: "就这片区域找书店")
        let inputID = try XCTUnwrap(store.entries.first?.id)
        XCTAssertEqual(executed.count, 1)
        let first = try XCTUnwrap(executed.first)
        XCTAssertEqual(first["latitude"] as? Double, 35.7)
        XCTAssertEqual(first["longitude"] as? Double, 139.7)
        let restored = CompanionHomeStore(url: url)
        let retryAgent = makeAgent(restored, callID: "search-retry", failAfterSearch: false)
        await restored.retry(id: inputID)
        XCTAssertEqual(executed.count, 1, "A retry reuses the completed canonical search receipt even when the model assigns a new call ID")
        let originalReceipt = try XCTUnwrap(restored.toolJournal(for: inputID).first?.calls.first)
        let aliasReceipt = try XCTUnwrap(restored.toolJournal(for: inputID).last?.calls.first)
        XCTAssertEqual(aliasReceipt.id, "search-retry")
        XCTAssertEqual(aliasReceipt.resultJSON, originalReceipt.resultJSON)
        XCTAssertEqual(aliasReceipt.cardID, originalReceipt.cardID)
        let retried = try XCTUnwrap(executed.last)
        XCTAssertEqual(retried["latitude"] as? Double, 35.7)
        XCTAssertEqual(retried["longitude"] as? Double, 139.7)
        XCTAssertEqual(restored.entries.first?.searchArea?.area, frozen)
        XCTAssertEqual(restored.entries.first?.status, .delivered)
        XCTAssertEqual(restored.toolJournal(for: inputID).first?.calls.first?.argumentsJSON, #"{"query":"books"}"#, "Execution must not rewrite the persisted model-plan identity")
        _ = (firstAgent, retryAgent)
    }

    func testPlaceWithoutCoordinatesRequiresManualAreaAndNeverUsesLiveMap() async throws {
        let entry = CompanionHomeEntry(role: .user, text: "这家附近有什么？", placeScope: .init(experienceID: "saved-place", name: "Saved bookstore", cityCode: "TYO", latitude: nil, longitude: nil))
        let result = try await scopedExecution(entry: entry, arguments: #"{"query":"coffee"}"#)
        XCTAssertTrue(result.calls.isEmpty)
        XCTAssertEqual(result.payload["outcome"] as? String, "needs_confirmation")
        XCTAssertEqual(result.payload["reason"] as? String, "search_scope_requires_area")
        XCTAssertTrue((result.payload["question"] as? String)?.contains("map area") == true)
    }

    func testScopedSearchRejectsPartialInvalidOrDifferentCoordinatesBeforeRouter() async throws {
        let scope = CompanionHomeAreaScope(area: .init(name: "Tokyo", latitude: 35.7, longitude: 139.7), query: nil, category: nil)
        let entry = CompanionHomeEntry(role: .user, text: "就这里找书店", searchArea: scope)
        for arguments in [#"{"query":"books","latitude":35.7}"#, #"{"query":"books","latitude":true,"longitude":139.7}"#, #"{"query":"books","latitude":91,"longitude":139.7}"#] {
            let result = try await scopedExecution(entry: entry, arguments: arguments)
            XCTAssertTrue(result.calls.isEmpty)
            XCTAssertEqual(result.payload["reason"] as? String, "invalid_search_coordinates")
        }
        let conflict = try await scopedExecution(entry: entry, arguments: #"{"query":"books","latitude":1.35,"longitude":103.82}"#)
        XCTAssertTrue(conflict.calls.isEmpty, "A different explicit destination must be clarified rather than silently rewritten or searched")
        XCTAssertEqual(conflict.payload["outcome"] as? String, "needs_confirmation")
        XCTAssertEqual(conflict.payload["reason"] as? String, "search_scope_conflict")
    }

    func testPlaceScopeFillsMissingCoordinatesWhileUnscopedSearchKeepsItsContract() async throws {
        let place = CompanionHomePlaceScope(experienceID: "saved-place", name: "Bookstore", cityCode: "TYO", latitude: 35.7, longitude: 139.7)
        let scoped = try await scopedExecution(entry: .init(role: .user, text: "这家附近", placeScope: place), arguments: #"{"query":"coffee"}"#)
        let coordinates = try XCTUnwrap(scoped.calls.first)
        XCTAssertEqual(coordinates["latitude"] as? Double, 35.7)
        XCTAssertEqual(coordinates["longitude"] as? Double, 139.7)
        let unscoped = try await scopedExecution(entry: .init(role: .user, text: "地图附近"), arguments: #"{"query":"coffee"}"#)
        XCTAssertEqual(unscoped.calls.count, 1)
        XCTAssertNil(unscoped.calls.first?["latitude"])
        XCTAssertNil(unscoped.calls.first?["longitude"])
    }

    private func scopedExecution(entry: CompanionHomeEntry, arguments: String) async throws -> (calls: [[String: Any]], payload: [String: Any]) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scoped-tool-\(UUID())/v1.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let encodedEntries = try JSONSerialization.jsonObject(with: JSONEncoder().encode([entry]))
        let snapshot: [String: Any] = ["version": 1, "entries": encodedEntries, "composerDraft": "", "people": [], "selectedPeopleIDs": [], "invites": []]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: snapshot).write(to: url)
        let store = CompanionHomeStore(url: url)
        var calls: [[String: Any]] = []
        var payload: [String: Any] = [:]
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []), toolExecutor: { call in
            let args = try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any]
            if let args { calls.append(args) }
            return (#"{"ok":true,"origin_source":"explicit_coordinates","eligible_count":0}"#, nil)
        })
        agent.journalStore = store
        var rounds = 0
        agent.messageSender = { messages, _ in
            rounds += 1
            if rounds == 1 { return .init(content: nil, toolCalls: [.init(id: "scoped-search", name: "search_places", argumentsJSON: arguments)]) }
            if let result = messages.last(where: { $0.role == .tool })?.content,
               let decoded = try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any] { payload = decoded }
            return .init(content: "The selected search scope is preserved", toolCalls: [])
        }
        store.configure(searchArea: { .init(name: "Singapore", latitude: 1.35, longitude: 103.82) })
        store.configure(agent: agent)
        await store.retry(id: entry.id)
        return (calls, payload)
    }
}
