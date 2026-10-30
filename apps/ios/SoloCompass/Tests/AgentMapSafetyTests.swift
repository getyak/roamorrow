import XCTest
import CoreLocation
import MapKit
@testable import SoloCompass

@MainActor
final class AgentMapSafetyTests: XCTestCase {
    private final class PausedGeocoder: ReverseGeocoding {
        var didEnter: (() -> Void)?
        var continuation: CheckedContinuation<ReverseGeocodeService.Resolved?, Never>?

        func resolve(coordinate: CLLocationCoordinate2D) async -> ReverseGeocodeService.Resolved? {
            await withCheckedContinuation {
                continuation = $0
                didEnter?()
            }
        }
    }

    private func fixture() -> (VoiceAgentToolRouter, MapViewModel, UserPreferences) {
        let preferences = UserPreferences(defaults: UserDefaults(suiteName: "agent-map-safety-\(UUID())")!)
        let map = MapViewModel(locationService: LocationService(), experienceService: ExperienceService(seed: []),
                               aiService: AIService(), preferences: preferences)
        return (VoiceAgentToolRouter(mapViewModel: map, preferences: preferences), map, preferences)
    }

    func testPolicyCatalogIsExhaustiveAndUnknownActionsAreConservative() {
        XCTAssertEqual(AgentToolPolicy.knownTools, Set(VoiceAgentToolRouter.allTools.map(\.name)).union(["manage_follow_up"]))
        for tool in ["navigate_to", "expand_radius", "save_to_favorites", "unknown_future_action"] {
            XCTAssertEqual(AgentToolPolicy.recovery(for: tool), .neverReplayStarted)
        }
        XCTAssertEqual(AgentToolPolicy.recovery(for: "recall_memory"), .retryRead)
    }

    func testFavoriteSaveRepeatedlyKeepsSavedState() async {
        let (router, map, preferences) = fixture()
        let call = VoiceAgentSession.ToolCall(id: "save", name: "save_to_favorites", argumentsJSON: #"{"experience_id":"fixture"}"#)
        _ = await router.execute(call)
        _ = await router.execute(call)
        XCTAssertTrue(preferences.isFavorited("fixture"))
        withExtendedLifetime(map) {}
    }

    func testInvalidInvocationCannotSaveOrExploreOrNavigate() async {
        let (router, map, preferences) = fixture()
        let save = VoiceAgentSession.ToolCall(id: "save", name: "save_to_favorites", argumentsJSON: #"{"experience_id":"fixture"}"#)
        let result = await router.execute(save, isCurrent: { false })
        XCTAssertTrue(result.contains("cancelled"))
        XCTAssertFalse(preferences.isFavorited("fixture"))
        let anchor = map.lastExploreCenter
        await map.exploreProgressively(at: CLLocationCoordinate2D(latitude: 1, longitude: 2), isCurrent: { false })
        XCTAssertEqual(map.lastExploreCenter?.latitude, anchor?.latitude)
        XCTAssertFalse(map.isExploring)
        let navigate = VoiceAgentSession.ToolCall(id: "navigate", name: "navigate_to", argumentsJSON: #"{"experience_id":"fixture"}"#)
        let navigationResult = await router.execute(navigate, isCurrent: { false })
        XCTAssertTrue(navigationResult.contains("cancelled"))
    }

    func testPreparedExplorationFreezesCoordinatesWithoutChangingCallIdentity() throws {
        let (router, map, _) = fixture()
        let viewport = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.77)
        map.noteWorkspaceViewport(MKCoordinateRegion(center: viewport,
                                                     span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04)))
        let call = VoiceAgentSession.ToolCall(id: "explore", name: "explore_nearby", argumentsJSON: "{}")
        let prepared = router.prepareForExecution(call)
        XCTAssertEqual(prepared.id, call.id)
        XCTAssertEqual(prepared.name, call.name)
        let args = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(prepared.argumentsJSON.utf8)) as? [String: Any])
        XCTAssertEqual(args["latitude"] as? Double, viewport.latitude)
        XCTAssertEqual(args["longitude"] as? Double, viewport.longitude)
        XCTAssertEqual(router.prepareForExecution(prepared), prepared)
    }

    func testPreparationDoesNotInventMissingCoordinateOrFallbackOrigin() async throws {
        let (router, map, _) = fixture()
        let incomplete = router.prepareForExecution(.init(id: "partial", name: "search_places",
                                                          argumentsJSON: #"{"query":"ramen","latitude":35.68}"#))
        let args = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(incomplete.argumentsJSON.utf8)) as? [String: Any])
        XCTAssertNil(args["longitude"])
        let result = await router.execute(incomplete)
        XCTAssertTrue(result.contains("provide both latitude and longitude"))
        if map.agentSearchOrigin == nil {
            let missing = router.prepareForExecution(.init(id: "missing", name: "explore_nearby", argumentsJSON: "{}"))
            let missingArgs = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(missing.argumentsJSON.utf8)) as? [String: Any])
            XCTAssertNil(missingArgs["latitude"])
            XCTAssertNil(missingArgs["longitude"])
        }
    }

    func testEffectRoundTripAndUnknownVersionFailClosed() throws {
        let source = WebSearchResult(title: "Evidence", url: "https://example.com", content: "Source text")
        let effect = VoiceAgentToolRouter.ToolEffect.webSources([source])
        let json = try XCTUnwrap(VoiceAgentToolRouter.encodeEffect(effect))
        XCTAssertEqual(VoiceAgentToolRouter.decodeEffect(json), effect)
        XCTAssertNil(VoiceAgentToolRouter.decodeEffect(json.replacingOccurrences(of: "\"version\":1", with: "\"version\":99")))
        XCTAssertNil(VoiceAgentToolRouter.decodeEffect("{bad"))
    }

    func testRouteEffectPreservesProposalSnapshotAndStopReasons() throws {
        let stops = Array(ExperienceService.hardcodedSeed.prefix(2))
        let route = Route(id: .init(rawValue: "durable-route"), title: "Saved proposal", summary: "Evidence snapshot",
                          experienceIds: stops.map(\.id), cityCode: "cmi", region: "test", estimatedDuration: 75,
                          distanceMeters: 900, pace: .standard, source: .aiGenerated)
        let proposal = RouteProposal(route: route, stops: stops, stopReasons: ["First", "Second"])
        let json = try XCTUnwrap(VoiceAgentToolRouter.encodeEffect(.route(proposal)))
        guard case .route(let decoded)? = VoiceAgentToolRouter.decodeEffect(json) else {
            XCTFail("route effect was not decoded")
            return
        }
        XCTAssertEqual(decoded, proposal)
        XCTAssertEqual(decoded.route.summary, "Evidence snapshot")
        XCTAssertEqual(decoded.route.estimatedDuration, 75)
        XCTAssertEqual(decoded.stops.map(\.title), stops.map(\.title))
    }

    func testInvalidationDuringGeocodeCannotCommitMapResults() async {
        let preferences = UserPreferences(defaults: UserDefaults(suiteName: "agent-map-barrier-\(UUID())")!)
        preferences.hasAcceptedExploreConsent = true
        let geocoder = PausedGeocoder()
        let entered = expectation(description: "geocoder entered")
        geocoder.didEnter = { entered.fulfill() }
        let map = MapViewModel(locationService: LocationService(), experienceService: ExperienceService(seed: []),
                               aiService: AIService(), preferences: preferences, geocodeService: geocoder)
        let router = VoiceAgentToolRouter(mapViewModel: map, preferences: preferences)
        let beforeIDs = map.visibleExperiences.map(\.id)
        let beforeCity = map.selectedCity
        var current = true
        let pending = Task {
            await router.execute(.init(id: "old-explore", name: "explore_nearby",
                                       argumentsJSON: #"{"latitude":1,"longitude":2}"#), isCurrent: { current })
        }
        await fulfillment(of: [entered], timeout: 2)
        current = false
        geocoder.continuation?.resume(returning: .init(cityCode: "old-city", name: "Old city", countryCode: "xx"))
        let result = await pending.value
        XCTAssertTrue(result.contains("cancelled"))
        XCTAssertEqual(map.visibleExperiences.map(\.id), beforeIDs)
        XCTAssertEqual(map.selectedCity, beforeCity)
        XCTAssertNil(map.lastExploreError)
        XCTAssertNil(router.lastEffect)
        XCTAssertFalse(map.isExploring)
    }

    func testCorruptMemoryReportsUnavailableInsteadOfEmptySearch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("agent-unavailable-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("memory.json")
        try Data("corrupt".utf8).write(to: url)
        let (router, map, _) = fixture()
        router.memoryProvider = DeviceAgentMemoryStore(fileURL: url)
        let wire = await router.execute(.init(id: "recall", name: "recall_memory", argumentsJSON: #"{"query":"coffee"}"#))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(wire.utf8)) as? [String: Any])
        XCTAssertEqual(payload["outcome"] as? String, "fatal")
        XCTAssertEqual(payload["reason"] as? String, "dependency_unavailable")
        XCTAssertTrue((payload["hint"] as? String)?.contains("not an empty search") == true)
        withExtendedLifetime(map) {}
    }
}
