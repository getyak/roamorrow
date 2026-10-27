import Foundation
import Observation

/// Email authentication is explicit and independent of optional background sync.
/// Source: https://github.com/supabase/auth/blob/master/README.md
@Observable @MainActor
final class EmailAccountService {
    static let shared = EmailAccountService()

    struct Identity: Codable, Equatable, Sendable {
        let userID: String
        let email: String
    }

    enum Failure: Error, LocalizedError {
        case invalidEmail, invalidCode, unavailable, rejected, unverified, network, storage
        var errorDescription: String? {
            accountText("account.error.\(self)")
        }
    }

    private(set) var identity: Identity?
    private(set) var isWorking = false
    private(set) var codeSentTo: String?
    private(set) var lastCodeSentAt: Date?
    /// Invalidates account-scoped responses after sign-out, refresh or replacement.
    private(set) var generation: UInt64 = 0
    private let transport: URLSession
    private let config: (() -> (url: URL, anonKey: String)?)
    private let readSession: () -> SupabaseClient.Session?
    private let saveSession: (SupabaseClient.Session) -> Bool
    private let clearSession: () -> Void
    private let saveIdentity: (Identity?) -> Bool

    init(
        transport: URLSession = AccountHTTP.transport(),
        config: @escaping () -> (url: URL, anonKey: String)? = { Secrets.resolvedSupabaseConfig() },
        readSession: @escaping () -> SupabaseClient.Session? = { EmailAccountService.storedSession() },
        saveSession: @escaping (SupabaseClient.Session) -> Bool = { EmailAccountService.storeSession($0) },
        clearSession: @escaping () -> Void = { _ = KeychainStore.delete(account: "sc.harness.email.session") },
        loadIdentity: (() -> Identity?)? = nil,
        saveIdentity: ((Identity?) -> Bool)? = nil
    ) {
        self.transport = transport
        self.config = config
        self.readSession = readSession
        self.saveSession = saveSession
        self.clearSession = clearSession
        self.saveIdentity = saveIdentity ?? { value in
            guard let value else { return KeychainStore.delete(account: "sc.email.identity") }
            guard let data = try? JSONEncoder().encode(value) else { return false }
            return KeychainStore.write(account: "sc.email.identity", value: String(decoding: data, as: UTF8.self))
        }
        let saved: Identity?
        if let loadIdentity { saved = loadIdentity() }
        else { saved = Self.savedIdentity() }
        if let saved, saved.userID == readSession()?.userId { identity = saved }
    }

    static func normalizedEmail(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.utf8.count <= 254,
              value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
        else { return nil }
        return value
    }

    func requestCode(email raw: String) async throws {
        guard !isWorking else { throw Failure.rejected }
        guard let email = Self.normalizedEmail(raw) else { throw Failure.invalidEmail }
        isWorking = true
        defer { isWorking = false }
        _ = try await request(path: "otp", body: ["email": email, "create_user": true])
        codeSentTo = email
        lastCodeSentAt = Date()
    }

    /// Cancels local code entry; a later verification cannot use the old address.
    func resetCode() {
        guard !isWorking else { return }
        codeSentTo = nil
        lastCodeSentAt = nil
        generation &+= 1
    }

    func verifyCode(_ raw: String) async throws {
        guard !isWorking else { throw Failure.rejected }
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = codeSentTo, (6...10).contains(code.count), code.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw Failure.invalidCode
        }
        isWorking = true
        defer { isWorking = false }
        let generation = generation
        let data = try await request(path: "verify", body: ["email": email, "token": code, "type": "email"])
        guard self.generation == generation else { throw Failure.rejected }
        try adopt(data, expectedEmail: email)
        codeSentTo = nil
    }

    func signIn(email raw: String, password: String) async throws {
        guard !isWorking else { throw Failure.rejected }
        guard let email = Self.normalizedEmail(raw), !password.isEmpty else { throw Failure.invalidEmail }
        isWorking = true
        defer { isWorking = false }
        let generation = generation
        let data = try await request(path: "token", query: "password", body: ["email": email, "password": password])
        guard self.generation == generation else { throw Failure.rejected }
        try adopt(data, expectedEmail: email)
    }

    /// Refreshes only the same verified account. A different cached user cannot inherit it.
    func accessToken() async throws -> String {
        guard let identity, let session = readSession(), session.userId == identity.userID else {
            throw Failure.rejected
        }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session.accessToken }
        let generation = generation
        let data = try await request(path: "token", query: "refresh_token", body: ["refresh_token": session.refreshToken])
        guard self.generation == generation, self.identity == identity, readSession()?.userId == identity.userID else { throw Failure.rejected }
        try adopt(data, expectedEmail: identity.email, expectedUserID: identity.userID)
        guard let refreshed = readSession(), refreshed.userId == identity.userID else { throw Failure.rejected }
        return refreshed.accessToken
    }

    /// Removes this account locally even if the provider cannot be reached.
    func signOut() async {
        let token = readSession()?.accessToken
        generation &+= 1
        clearSession()
        identity = nil
        codeSentTo = nil
        _ = saveIdentity(nil)
        if let token { _ = try? await request(path: "logout", body: [:], token: token) }
    }

    private struct AuthResponse: Decodable {
        struct User: Decodable {
            let id: String
            let email: String?
            let email_confirmed_at: String?
            let is_anonymous: Bool?
        }
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let user: User
    }

    private func adopt(_ data: Data, expectedEmail: String, expectedUserID: String? = nil) throws {
        try Task.checkCancellation()
        let response: AuthResponse
        do { response = try JSONDecoder().decode(AuthResponse.self, from: data) }
        catch { throw Failure.rejected }
        guard UUID(uuidString: response.user.id) != nil,
              response.user.is_anonymous != true,
              response.user.email_confirmed_at?.isEmpty == false,
              response.user.email?.lowercased() == expectedEmail,
              expectedUserID == nil || response.user.id == expectedUserID,
              !response.access_token.isEmpty, !response.refresh_token.isEmpty,
              (1...604_800).contains(response.expires_in) else { throw Failure.unverified }
        let newIdentity = Identity(userID: response.user.id, email: expectedEmail)
        let session = SupabaseClient.Session(userId: response.user.id, accessToken: response.access_token,
            refreshToken: response.refresh_token, expiresAt: Date().addingTimeInterval(Double(response.expires_in)))
        guard saveSession(session), saveIdentity(newIdentity) else {
            clearSession()
            identity = nil
            _ = saveIdentity(nil)
            throw Failure.storage
        }
        identity = newIdentity
        generation &+= 1
    }

    private func request(path: String, query: String? = nil, body: [String: Any], token: String? = nil) async throws -> Data {
        guard let config = config(), config.url.scheme == "https", config.url.host != nil else { throw Failure.unavailable }
        var url = config.url.appendingPathComponent("auth/v1").appendingPathComponent(path)
        if let query { url = url.appending(queryItems: [.init(name: "grant_type", value: query)]) }
        if path == "logout" { url = url.appending(queryItems: [.init(name: "scope", value: "local")]) }
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch { if Task.isCancelled { throw CancellationError() }; throw Failure.network }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw Failure.network }
        guard (200..<300).contains(http.statusCode) else {
            throw http.statusCode == 429 ? Failure.unavailable : Failure.rejected
        }
        guard data.count <= 64 * 1024 else { throw Failure.rejected }
        return data
    }

    private static func savedIdentity() -> Identity? {
        guard let raw = KeychainStore.read(account: "sc.email.identity") else { return nil }
        return try? JSONDecoder().decode(Identity.self, from: Data(raw.utf8))
    }

    // A separate Keychain account prevents legacy anonymous sync/bootstrap from
    // overwriting email auth, or uploading old sync outbox rows under a new user.
    // This account authorizes harness profile/provider tools, not legacy sync migration.
    private static func storedSession() -> SupabaseClient.Session? {
        guard let raw = KeychainStore.read(account: "sc.harness.email.session") else { return nil }
        return try? JSONDecoder().decode(SupabaseClient.Session.self, from: Data(raw.utf8))
    }

    private static func storeSession(_ session: SupabaseClient.Session) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        return KeychainStore.write(account: "sc.harness.email.session", value: String(decoding: data, as: UTF8.self))
    }
}

/// A separate, cookie-free transport never follows credential-bearing redirects.
enum AccountHTTP {
    static func transport() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: AccountNoRedirect(), delegateQueue: nil)
    }
}

private final class AccountNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

func accountText(_ key: String) -> String { NSLocalizedString(key, comment: "Email account and travel context") }
