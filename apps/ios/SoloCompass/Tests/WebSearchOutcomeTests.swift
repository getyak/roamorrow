import XCTest
@testable import SoloCompass

@MainActor
final class WebSearchOutcomeTests: XCTestCase {
    private final class Client: SupabaseClientProtocol {
        var response: Result<Data, SupabaseClient.SupabaseError> = .success(Data(#"{"results":[]}"#.utf8))
        var invokeCount = 0
        var currentSession: SupabaseClient.Session? { nil }
        var isAnonymous: Bool { get async { false } }
        func invoke(function: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> {
            invokeCount += 1
            return response
        }
        func signInAnonymously() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.notSignedIn) }
        func refreshSession() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.notSignedIn) }
        func post(table: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> { .success(Data()) }
        func get(table: String, query: [URLQueryItem]) async -> Result<Data, SupabaseClient.SupabaseError> { .success(Data()) }
        func delete(table: String, id: String) async -> Result<Void, SupabaseClient.SupabaseError> { .success(()) }
        func linkAppleIdentity(identityToken: String, nonce: String) async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.notSignedIn) }
    }

    func testDisabledBackendIsUnavailableAndDoesNotInvoke() async {
        let client = Client()
        let service = WebSearchService(client: client, backendEnabled: { false })
        let result = await service.searchOutcome(query: "coffee")
        XCTAssertEqual(result.status, .unavailable)
        XCTAssertFalse(result.available)
        XCTAssertEqual(result.errorCategory, .backendDisabled)
        XCTAssertEqual(client.invokeCount, 0)
    }

    func testCompletedSearchDistinguishesSourcesAndEmptyResults() async {
        let client = Client()
        let service = WebSearchService(client: client, backendEnabled: { true })
        let empty = await service.searchOutcome(query: "coffee")
        XCTAssertEqual(empty.status, .empty)
        XCTAssertTrue(empty.available)
        XCTAssertNil(empty.errorCategory)
        client.response = .success(Data(#"{"results":[{"title":"Source","url":"https://example.com","content":"Evidence"}]}"#.utf8))
        let found = await service.searchOutcome(query: "coffee")
        XCTAssertEqual(found.status, .results)
        XCTAssertEqual(found.results.count, 1)
        XCTAssertTrue(found.available)
    }

    func testTypedFailuresKeepStableCategoriesWithoutGuessingFromBody() async {
        let client = Client()
        let service = WebSearchService(client: client, backendEnabled: { true })
        let cases: [(SupabaseClient.SupabaseError, WebSearchService.SearchOutcome.ErrorCategory)] = [
            (.missingConfig, .notConfigured), (.notSignedIn, .authenticationRequired),
            (.backendDisabled, .backendDisabled), (.decoding("private diagnostics"), .invalidResponse),
            (.requestFailed(status: 401, body: "private diagnostics"), .authenticationRequired),
            (.requestFailed(status: 403, body: "private diagnostics"), .accessDenied),
            (.requestFailed(status: 429, body: "private diagnostics"), .rateLimited),
            (.requestFailed(status: 0, body: "offline or token failure: unknown"), .requestFailed),
            (.requestFailed(status: 502, body: "private diagnostics"), .requestFailed),
        ]
        for (error, category) in cases {
            client.response = .failure(error)
            let result = await service.searchOutcome(query: "coffee")
            XCTAssertEqual(result.status, .unavailable)
            XCTAssertEqual(result.errorCategory, category)
            XCTAssertTrue(result.results.isEmpty)
        }
    }

    func testEmptyOrMalformedSuccessIsNotACompletedEmptySearch() async {
        let client = Client()
        let service = WebSearchService(client: client, backendEnabled: { true })
        for body in ["", "{}", #"{"results":null}"#, "not json"] {
            client.response = .success(Data(body.utf8))
            let result = await service.searchOutcome(query: "coffee")
            XCTAssertEqual(result.status, .unavailable)
            XCTAssertEqual(result.errorCategory, .invalidResponse)
        }
    }

    func testCancelledSearchDoesNotInvokeOrReportNoMatches() async {
        let client = Client()
        let service = WebSearchService(client: client, backendEnabled: { true })
        let result = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await service.searchOutcome(query: "coffee")
        }.value
        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.errorCategory, .cancelled)
        XCTAssertEqual(client.invokeCount, 0)
    }

    func testRouterMakesUnavailableHonestAndClearsPreviousSources() async throws {
        let client = Client()
        let router = makeRouter(client)
        client.response = .success(Data(#"{"results":[{"title":"Source","url":"https://example.com","content":"Evidence"}]}"#.utf8))
        _ = await execute(router)
        XCTAssertNotNil(router.lastEffect)
        client.response = .failure(.requestFailed(status: 401, body: "private diagnostics must not escape"))
        let wire = await execute(router)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(wire.utf8)) as? [String: Any])
        XCTAssertEqual(payload["ok"] as? Bool, false)
        XCTAssertEqual(payload["success"] as? Bool, false)
        XCTAssertEqual(payload["available"] as? Bool, false)
        XCTAssertEqual(payload["status"] as? String, "unavailable")
        XCTAssertEqual(payload["errorCategory"] as? String, "authentication_required")
        XCTAssertFalse(wire.contains("private diagnostics"))
        XCTAssertNil(router.lastEffect)
    }

    func testRouterReportsOnlyGenuineEmptySearchAsSuccessful() async throws {
        let router = makeRouter(Client())
        let wire = await execute(router)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(wire.utf8)) as? [String: Any])
        XCTAssertEqual(payload["ok"] as? Bool, true)
        XCTAssertEqual(payload["success"] as? Bool, true)
        XCTAssertEqual(payload["available"] as? Bool, true)
        XCTAssertEqual(payload["status"] as? String, "empty")
        XCTAssertEqual(payload["result_count"] as? Int, 0)
        XCTAssertNil(router.lastEffect)
    }

    private func makeRouter(_ client: Client) -> VoiceAgentToolRouter {
        let preferences = UserPreferences(defaults: UserDefaults(suiteName: "web-search-outcome-\(UUID())")!)
        let model = MapViewModel(locationService: LocationService(), experienceService: ExperienceService(seed: []),
                                 aiService: AIService(), preferences: preferences)
        return VoiceAgentToolRouter(mapViewModel: model, preferences: preferences,
                                    webSearchService: WebSearchService(client: client, backendEnabled: { true }))
    }

    private func execute(_ router: VoiceAgentToolRouter) async -> String {
        await router.execute(.init(id: "test-search", name: "web_search", argumentsJSON: #"{"query":"coffee"}"#))
    }
}
