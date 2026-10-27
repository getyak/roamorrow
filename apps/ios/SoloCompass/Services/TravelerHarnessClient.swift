import Foundation

/// Account-scoped wire contract: docs/architecture/deepseek-onboarding-harness.md.
@MainActor
final class TravelerHarnessClient {
    struct Capabilities: Decodable, Sendable {
        let email_auth: Bool
        let google: Bool
        let deepseek: Bool
        let database: Bool
    }
    struct GoogleConnection: Codable, Equatable, Sendable {
        var connected: Bool
        var email: String
        var scopes: [String]
    }
    struct Profile: Codable, Equatable, Sendable {
        let user_id: String
        let email: String
        var display_name: String
        var home_city: String
        var interests: [String]
        var ai_context_consent: Bool
        var google: GoogleConnection
    }
    struct ProfileUpdate: Encodable {
        let display_name: String
        let home_city: String
        let interests: [String]
        let ai_context_consent: Bool
    }
    struct Authorization: Decodable { let authorization_url: URL; let expires_at: String }
    struct Disconnection: Decodable { let disconnected: Bool; let provider_revocation_confirmed: Bool }
    struct ChatResponse: Decodable {
        struct ToolCall: Decodable { let name: String; let status: String }
        let reply: String
        let tool_calls: [ToolCall]
    }

    enum Failure: Error, LocalizedError {
        case unconfigured, unavailable, signInRequired, permissionRequired, rejected, network
        var errorDescription: String? { accountText("harness.error.\(self)") }
    }

    private let baseURL: URL?
    private let transport: URLSession
    private let account: EmailAccountService

    init(baseURL: URL? = Secrets.resolvedHarnessBaseURL(), transport: URLSession = AccountHTTP.transport(),
         account: EmailAccountService = .shared) {
        self.baseURL = baseURL.flatMap { Self.validatedOrigin($0.absoluteString) }
        self.transport = transport
        self.account = account
    }

    static func validatedOrigin(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.query == nil,
              components.fragment == nil, components.path.isEmpty || components.path == "/" else { return nil }
        return components.url
    }

    func capabilities() async throws -> Capabilities { try await call("capabilities", authenticated: false) }
    func profile() async throws -> Profile { try await call("profile") }

    func save(_ profile: ProfileUpdate) async throws -> Profile {
        try await call("profile", method: "PUT", body: JSONEncoder().encode(profile))
    }

    func startGoogle(calendar: Bool, mail: Bool) async throws -> Authorization {
        let body = try JSONSerialization.data(withJSONObject: ["calendar": calendar, "mail": mail])
        let result: Authorization = try await call("google/start", method: "POST", body: body)
        guard result.authorization_url.scheme == "https", result.authorization_url.host == "accounts.google.com",
              result.authorization_url.user == nil, result.authorization_url.password == nil else { throw Failure.rejected }
        return result
    }

    func disconnectGoogle() async throws -> Disconnection { try await call("google", method: "DELETE") }

    func ask(_ message: String) async throws -> ChatResponse {
        let body = try JSONSerialization.data(withJSONObject: ["message": message])
        return try await call("chat", method: "POST", body: body)
    }

    private func call<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil,
                                   authenticated: Bool = true) async throws -> T {
        guard let baseURL else { throw Failure.unconfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/harness").appendingPathComponent(path), timeoutInterval: path == "chat" ? 60 : 15)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let expectedIdentity = account.identity
        if authenticated {
            let token: String
            do { token = try await account.accessToken() }
            catch { throw Failure.signInRequired }
            guard account.identity == expectedIdentity else { throw Failure.signInRequired }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let generation = account.generation
        let data: Data
        let response: URLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch { if Task.isCancelled { throw CancellationError() }; throw Failure.network }
        try Task.checkCancellation()
        guard !authenticated || (account.identity == expectedIdentity && account.generation == generation) else { throw Failure.signInRequired }
        guard let http = response as? HTTPURLResponse else { throw Failure.network }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw Failure.signInRequired
        case 403: throw Failure.permissionRequired
        case 429, 503: throw Failure.unavailable
        default: throw Failure.rejected
        }
        guard data.count <= 512 * 1024 else { throw Failure.rejected }
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            if let profile = value as? Profile, profile.user_id != expectedIdentity?.userID { throw Failure.rejected }
            return value
        }
        catch { throw Failure.rejected }
    }
}
