import XCTest
@testable import SoloCompass

@MainActor
final class EmailAccountServiceTests: XCTestCase {
    private let userID = "11111111-2222-4333-8444-555555555555"

    private final class SessionBox {
        var session: SupabaseClient.Session?
        var identity: EmailAccountService.Identity?
        var acceptsWrites = true
    }

    private func service(_ box: SessionBox = SessionBox()) -> EmailAccountService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AccountTestURLProtocol.self]
        return EmailAccountService(transport: URLSession(configuration: config),
            config: { URL(string: "https://auth.example.test").map { ($0, "public-test-key") } },
            readSession: { box.session }, saveSession: { box.session = $0; return box.acceptsWrites },
            clearSession: { box.session = nil }, loadIdentity: { box.identity },
            saveIdentity: { box.identity = $0; return box.acceptsWrites })
    }

    private func authResponse(email: String = "traveler@example.test", confirmed: Bool = true) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["access_token": "synthetic-access", "refresh_token": "synthetic-refresh",
            "expires_in": 3600, "user": ["id": userID, "email": email, "is_anonymous": false,
            "email_confirmed_at": confirmed ? ("2026-10-24T00:00:00Z" as Any) : NSNull()]])
    }

    func testAddressDoesNotAuthenticateBeforeVerification() async throws {
        AccountTestURLProtocol.reset([(200, Data("{}".utf8))])
        let box = SessionBox()
        let auth = service(box)
        try await auth.requestCode(email: "  Traveler@Example.Test ")
        XCTAssertEqual(auth.codeSentTo, "traveler@example.test")
        XCTAssertNil(auth.identity)
        XCTAssertNil(box.session)
        XCTAssertEqual(AccountTestURLProtocol.requests.last?.url?.path, "/auth/v1/otp")
    }

    func testInvalidEmailNeverStartsARequest() async {
        AccountTestURLProtocol.reset([])
        let auth = service()
        for email in ["plain", "one@@example.test", "a b@example.test", "a@example", "@example.test"] {
            do { try await auth.requestCode(email: email); XCTFail("Accepted invalid email") }
            catch { }
        }
        XCTAssertTrue(AccountTestURLProtocol.requests.isEmpty)
    }

    func testVerifiedCodeStoresTheProviderUserAndEmailSession() async throws {
        AccountTestURLProtocol.reset([(200, Data("{}".utf8)), (200, try authResponse())])
        let box = SessionBox()
        let auth = service(box)
        try await auth.requestCode(email: "traveler@example.test")
        try await auth.verifyCode("123456")
        XCTAssertEqual(auth.identity?.userID, userID)
        XCTAssertEqual(box.session?.userId, userID)
        XCTAssertNil(auth.codeSentTo)
        let body = try XCTUnwrap(AccountTestURLProtocol.requests.last?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object["type"], "email")
    }

    func testUnverifiedOrDifferentEmailCannotBecomeSignedIn() async throws {
        for response in [try authResponse(confirmed: false), try authResponse(email: "another@example.test")] {
            AccountTestURLProtocol.reset([(200, response)])
            let box = SessionBox()
            let auth = service(box)
            do { try await auth.signIn(email: "traveler@example.test", password: "synthetic"); XCTFail("Accepted unverified identity") }
            catch { }
            XCTAssertNil(auth.identity)
            XCTAssertNil(box.session)
        }
    }

    func testStorageFailureRollsBackIdentityAndSession() async throws {
        AccountTestURLProtocol.reset([(200, try authResponse())])
        let box = SessionBox(); box.acceptsWrites = false
        let auth = service(box)
        do { try await auth.signIn(email: "traveler@example.test", password: "synthetic"); XCTFail("Accepted failed persistence") }
        catch { }
        XCTAssertNil(auth.identity)
        XCTAssertNil(box.session)
    }

    func testSavedIdentityCannotAttachToAnotherAccount() {
        let box = SessionBox()
        box.identity = .init(userID: userID, email: "traveler@example.test")
        box.session = .init(userId: UUID().uuidString, accessToken: "synthetic", refreshToken: "synthetic", expiresAt: .distantFuture)
        XCTAssertNil(service(box).identity)
    }

    func testSavedVerifiedSessionRestoresWithoutAnUnnecessaryLogin() async throws {
        AccountTestURLProtocol.reset([])
        let box = SessionBox()
        box.identity = .init(userID: userID, email: "traveler@example.test")
        box.session = .init(userId: userID, accessToken: "synthetic", refreshToken: "synthetic", expiresAt: .distantFuture)
        let auth = service(box)
        XCTAssertEqual(auth.identity, box.identity)
        let token = try await auth.accessToken()
        XCTAssertEqual(token, "synthetic")
        XCTAssertTrue(AccountTestURLProtocol.requests.isEmpty)
    }

    func testRejectedCodeCanChangeEmailAndRequestAgain() async throws {
        AccountTestURLProtocol.reset([(200, Data("{}".utf8)), (400, Data()), (200, Data("{}".utf8))])
        let auth = service()
        try await auth.requestCode(email: "traveler@example.test")
        do { try await auth.verifyCode("123456"); XCTFail("Invalid provider code succeeded") } catch { }
        XCTAssertNil(auth.identity)
        auth.resetCode()
        XCTAssertNil(auth.codeSentTo)
        try await auth.requestCode(email: "corrected@example.test")
        XCTAssertEqual(auth.codeSentTo, "corrected@example.test")
        XCTAssertNil(auth.identity)
    }

    func testExpiredRefreshCannotRestoreAnAccountAfterSignOut() async throws {
        AccountTestURLProtocol.reset([(200, try authResponse()), (503, Data())])
        let box = SessionBox()
        box.identity = .init(userID: userID, email: "traveler@example.test")
        box.session = .init(userId: userID, accessToken: "synthetic", refreshToken: "synthetic", expiresAt: .distantPast)
        let auth = service(box)
        let started = expectation(description: "Refresh request started")
        AccountTestURLProtocol.holdNext(started: started)
        let pending = Task { try await auth.accessToken() }
        await fulfillment(of: [started], timeout: 3)
        await auth.signOut()
        AccountTestURLProtocol.releaseHeld()
        do { _ = try await pending.value; XCTFail("Old refresh restored a signed-out account") } catch { }
        XCTAssertNil(auth.identity)
        XCTAssertNil(box.session)
    }

    func testProfileResponseForSignedOutAccountIsDiscarded() async throws {
        let profile = try JSONSerialization.data(withJSONObject: ["user_id": userID, "email": "traveler@example.test",
            "display_name": "Synthetic traveler", "home_city": "", "interests": [], "ai_context_consent": true,
            "google": ["connected": false, "email": "", "scopes": []]])
        AccountTestURLProtocol.reset([(200, profile), (503, Data())])
        let box = SessionBox()
        box.identity = .init(userID: userID, email: "traveler@example.test")
        box.session = .init(userId: userID, accessToken: "synthetic", refreshToken: "synthetic", expiresAt: .distantFuture)
        let auth = service(box)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountTestURLProtocol.self]
        let client = TravelerHarnessClient(baseURL: URL(string: "https://harness.example.test"),
            transport: URLSession(configuration: configuration), account: auth)
        let started = expectation(description: "Profile request started")
        AccountTestURLProtocol.holdNext(started: started)
        let pending = Task { try await client.profile() }
        await fulfillment(of: [started], timeout: 3)
        await auth.signOut()
        AccountTestURLProtocol.releaseHeld()
        do { _ = try await pending.value; XCTFail("Old account profile escaped the generation boundary") } catch { }
    }

    func testSignOutIsLocalAndClearsIdentityEvenIfProviderFails() async throws {
        AccountTestURLProtocol.reset([(200, try authResponse()), (503, Data())])
        let box = SessionBox()
        let auth = service(box)
        try await auth.signIn(email: "traveler@example.test", password: "synthetic")
        await auth.signOut()
        XCTAssertNil(auth.identity)
        XCTAssertNil(box.session)
        let url = try XCTUnwrap(AccountTestURLProtocol.requests.last?.url)
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "local")
    }

    func testHarnessOriginRejectsCredentialsAndNonOriginComponents() {
        for raw in ["http://localhost:4437", "https://user:secret@example.test", "https://example.test/api",
                    "https://example.test?token=x", "https://example.test#fragment", "file:///tmp"] {
            XCTAssertNil(TravelerHarnessClient.validatedOrigin(raw))
        }
        XCTAssertEqual(TravelerHarnessClient.validatedOrigin("https://example.test:18443/")?.port, 18443)
    }
}

/// In-memory synthetic transport. A lock protects URLSession's background callbacks.
final class AccountTestURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [(Int, Data)] = []
    nonisolated(unsafe) private static var recorded: [URLRequest] = []
    nonisolated(unsafe) private static var holdExpectation: XCTestExpectation?
    nonisolated(unsafe) private static var held: [AccountTestURLProtocol] = []
    private var queuedReply: (Int, Data)?
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return recorded }
    static func reset(_ replies: [(Int, Data)]) {
        lock.lock(); defer { lock.unlock() }
        self.replies = replies; recorded = []; holdExpectation = nil; held = []
    }
    static func holdNext(started: XCTestExpectation) { lock.lock(); defer { lock.unlock() }; holdExpectation = started }
    static func releaseHeld() {
        lock.lock(); let pending = held; held = []; lock.unlock()
        for item in pending { item.deliver() }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        var recordedRequest = request
        if recordedRequest.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            recordedRequest.httpBody = data
        }
        Self.recorded.append(recordedRequest)
        let reply = Self.replies.isEmpty ? (500, Data()) : Self.replies.removeFirst()
        queuedReply = reply
        let expectation = Self.holdExpectation
        if expectation != nil { Self.holdExpectation = nil; Self.held.append(self) }
        Self.lock.unlock()
        if let expectation { expectation.fulfill(); return }
        deliver()
    }
    private func deliver() {
        guard let reply = queuedReply else { return }
        queuedReply = nil
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: reply.0,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.1)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
