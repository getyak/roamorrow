import Foundation

/// One web page returned by a live search. The chat agent summarizes the
/// `content` snippets into a sourced answer, and the UI renders `title` + `url`
/// as tappable source-link cards (Perplexity-style provenance).
public struct WebSearchResult: Codable, Equatable, Identifiable, Sendable {
    /// Stable identity for SwiftUI lists — the URL is unique within a result set
    /// (the Edge Function dedupes by URL).
    public var id: String { url }
    public let title: String
    public let url: String
    /// Extracted page snippet. Bounded server-side so a chatty page can't blow
    /// the model's context budget.
    public let content: String

    public init(title: String, url: String, content: String) {
        self.title = title
        self.url = url
        self.content = content
    }

    /// Human-facing host label for a source card ("example.com"), stripped of a
    /// leading "www.". Falls back to the raw URL when it won't parse.
    public var host: String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Live web search for the in-chat agent, fronting the `tavily-search` Edge
/// Function so the Tavily key stays server-side.
///
/// This is the real thing the old `AIService.sendWebSearchQuery` only pretended
/// to be: that path just asked the model what it already knew from training and
/// never touched the network. Here the query reaches Tavily, and the agent gets
/// back actual pages — titles, URLs, and extracted snippets — to ground its
/// answer in current, citable sources.
///
/// `searchOutcome` distinguishes a completed empty search from unavailable
/// search. `search` retains the older best-effort array contract for callers
/// that only need source cards.
@MainActor
public final class WebSearchService {
    public static let shared = WebSearchService()

    private let client: SupabaseClientProtocol
    private let backendEnabled: @MainActor () -> Bool

    public init(
        client: SupabaseClientProtocol = SupabaseClient.shared,
        backendEnabled: @escaping @MainActor () -> Bool = { FeatureFlags.backendSync }
    ) {
        self.client = client
        self.backendEnabled = backendEnabled
    }

    /// Topic hint passed to Tavily. `.news` biases toward recent, time-sensitive
    /// pages (events, "what's on now"); `.general` is the default.
    public enum Topic: String, Sendable {
        case general
        case news
    }

    /// Search results and availability, with a safe error category when search could not complete.
    public struct SearchOutcome: Equatable, Sendable {
        /// Distinguishes sourced results, a completed empty search and an unavailable search.
        public enum Status: String, Sendable { case results, empty, unavailable }
        /// Safe categories only. Never carry a response body, exception text or token.
        public enum ErrorCategory: String, Sendable {
            case backendDisabled = "backend_disabled"
            case notConfigured = "not_configured"
            case authenticationRequired = "authentication_required"
            case accessDenied = "access_denied"
            case rateLimited = "rate_limited"
            case requestFailed = "request_failed"
            case invalidResponse = "invalid_response"
            case invalidQuery = "invalid_query"
            case cancelled
        }

        public let status: Status
        public let results: [WebSearchResult]
        public let errorCategory: ErrorCategory?
        public var available: Bool { status != .unavailable }

        fileprivate static func completed(_ results: [WebSearchResult]) -> Self {
            .init(status: results.isEmpty ? .empty : .results, results: results, errorCategory: nil)
        }

        fileprivate static func unavailable(_ category: ErrorCategory) -> Self {
            .init(status: .unavailable, results: [], errorCategory: category)
        }
    }

    /// Run a live web search. Returns up to a handful of deduped pages, or an
    /// empty array on any failure. Use `searchOutcome` when failure semantics matter.
    ///
    /// - Parameters:
    ///   - query: The natural-language search string.
    ///   - topic: `.news` for time-sensitive queries, else `.general`.
    ///   - days: For `.news`, how far back to look (ignored otherwise).
    public func search(
        query: String,
        topic: Topic = .general,
        days: Int? = nil
    ) async -> [WebSearchResult] {
        await searchOutcome(query: query, topic: topic, days: days).results
    }

    /// Only a valid results envelope proves that a live search completed.
    /// In particular, the client's disabled-backend empty-Data no-op is not
    /// evidence of a completed search with no matches.
    public func searchOutcome(
        query: String,
        topic: Topic = .general,
        days: Int? = nil
    ) async -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unavailable(.invalidQuery) }
        guard !Task.isCancelled else { return .unavailable(.cancelled) }
        guard backendEnabled() else { return .unavailable(.backendDisabled) }

        var payload: [String: Any] = [
            "query": trimmed,
            "topic": topic.rawValue,
        ]
        if topic == .news, let days { payload["days"] = days }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return .unavailable(.invalidQuery)
        }

        let result = await client.invoke(function: "tavily-search", body: body)
        guard !Task.isCancelled else { return .unavailable(.cancelled) }
        let data: Data
        switch result {
        case .success(let response): data = response
        case .failure(let error):
            switch error {
            case .backendDisabled: return .unavailable(.backendDisabled)
            case .missingConfig: return .unavailable(.notConfigured)
            case .notSignedIn: return .unavailable(.authenticationRequired)
            case .decoding: return .unavailable(.invalidResponse)
            case .requestFailed(let status, _):
                switch status {
                case 401: return .unavailable(.authenticationRequired)
                case 403: return .unavailable(.accessDenied)
                case 429: return .unavailable(.rateLimited)
                // The client collapses non-HTTP failures into status 0. There
                // is no reliable evidence here to label them offline or auth.
                default: return .unavailable(.requestFailed)
                }
            }
        }

        struct Envelope: Decodable {
            let results: [WebSearchResult]
        }
        guard !data.isEmpty, let decoded = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return .unavailable(.invalidResponse)
        }
        return .completed(decoded.results)
    }
}
