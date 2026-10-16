import XCTest
@testable import SoloCompass

@MainActor
final class CompanionPostActionServiceTests: XCTestCase {
    private final class Client: SupabaseClientProtocol {
        var currentSession: SupabaseClient.Session? = .init(userId: "caller", accessToken: "test", refreshToken: "test", expiresAt: .distantFuture)
        var response: Result<Data, SupabaseClient.SupabaseError> = .success(Data("{\"saved\":true}".utf8))
        var calls: [(String, Data)] = []
        var isAnonymous: Bool { get async { true } }
        func invoke(function: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> { calls.append((function, body)); return response }
        func signInAnonymously() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func refreshSession() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func linkAppleIdentity(identityToken: String, nonce: String) async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func post(table: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> { XCTFail("Must resolve via server, not direct insert"); return .failure(.backendDisabled) }
        func get(table: String, query: [URLQueryItem]) async -> Result<Data, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func delete(table: String, id: String) async -> Result<Void, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
    }

    func testAnonymousDiscoveryActionSendsPostAndStableIntentWithoutClientIdentity() async throws {
        let client = Client()
        let service = CompanionPostActionService(client: client, isEnabled: { true })
        for _ in 0..<2 { try await service.perform(.request, postId: "post", actionId: "stable", note: "hello").get() }
        XCTAssertEqual(client.calls.count, 2)
        XCTAssertEqual(client.calls[0].0, "companion-post-action")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: client.calls[0].1) as? [String: String])
        XCTAssertEqual(payload["postId"], "post")
        XCTAssertEqual(payload["actionId"], "stable")
        XCTAssertNil(payload["recipientId"])
        XCTAssertNil(payload["requesterId"])
        let retriedPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: client.calls[1].1) as? [String: String])
        XCTAssertEqual(payload, retriedPayload)
    }

    func testEmptyFalseOrInvalidAcknowledgementIsFailure() async {
        let client = Client()
        let service = CompanionPostActionService(client: client, isEnabled: { true })
        for text in ["", "{}", "{\"saved\":false}", "[]", "{\"saved\":\"true\"}"] {
            client.response = .success(Data(text.utf8))
            if case .success = await service.perform(.block, postId: "post", actionId: "stable") { XCTFail("Unacknowledged action: " + text) }
        }
    }

    func testFeatureOffOrSignedOutNeverInvokesEndpoint() async {
        let client = Client()
        let disabled = CompanionPostActionService(client: client, isEnabled: { false })
        if case .success = await disabled.perform(.friend, postId: "post", actionId: "one") { XCTFail("Feature off") }
        client.currentSession = nil
        let signedOut = CompanionPostActionService(client: client, isEnabled: { true })
        if case .success = await signedOut.perform(.report, postId: "post", actionId: "one", reason: .spam) { XCTFail("Signed out") }
        XCTAssertTrue(client.calls.isEmpty)
    }

    func testEditedDraftCannotBeAcknowledgedByPreviousSubmission() async {
        let client = Client()
        client.response = .failure(.requestFailed(status: 409, body: "private diagnostic"))
        let service = CompanionPostActionService(client: client, isEnabled: { true })
        let result = await service.perform(.request, postId: "post", actionId: "one", note: "edited")
        guard case .failure(let error) = result else { return XCTFail("Edited content was acknowledged") }
        XCTAssertEqual(error as? CompanionPostActionService.PostActionError, .editedAfterSaved)
    }

    func testTransportFailureDoesNotBecomeSavedOrLeakRawBackendError() async {
        let client = Client()
        client.response = .failure(.requestFailed(status: 503, body: "SQL diagnostic"))
        let service = CompanionPostActionService(client: client, isEnabled: { true })
        let result = await service.perform(.report, postId: "post", actionId: "one", reason: .spam)
        if case .failure(let error) = result { XCTAssertFalse(error.localizedDescription.contains("SQL diagnostic")) }
        else { XCTFail("Transport failure acknowledged") }
    }
}
