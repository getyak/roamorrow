import Foundation

/// Post IDs and user IDs are different namespaces. The backend resolves the
/// author after the user's explicit action; anonymous discovery stays anonymous.
@MainActor
public final class CompanionPostActionService {
    public static let shared = CompanionPostActionService()
    private let client: SupabaseClientProtocol
    private let isEnabled: () -> Bool

    public init(
        client: SupabaseClientProtocol = SupabaseClient.shared,
        isEnabled: @escaping () -> Bool = { FeatureFlags.companion }
    ) {
        self.client = client
        self.isEnabled = isEnabled
    }

    /// Explicit traveler intent submitted against a discovery post.
    public enum Action: String, Encodable { case request, friend, report, block }

    /// Keep actionId stable across a retry of the same intent. A transport
    /// failure must not cause a second report or duplicate pending request.
    public func perform(
        _ action: Action,
        postId: String,
        actionId: String,
        note: String? = nil,
        reason: CompanionReportReason? = nil,
        details: String? = nil
    ) async -> Result<Void, Error> {
        guard isEnabled() else { return .failure(CompanionServiceError.featureDisabled) }
        guard client.currentSession != nil else { return .failure(CompanionServiceError.notSignedIn) }
        struct Payload: Encodable {
            let action: Action
            let postId: String
            let actionId: String
            let note: String?
            let reason: String?
            let details: String?
        }
        do {
            let payload = Payload(action: action, postId: postId, actionId: actionId,
                                  note: note, reason: reason?.rawValue, details: details)
            let body = try JSONEncoder().encode(payload)
            let result = await client.invoke(function: "companion-post-action", body: body)
            switch result {
            case .failure(.requestFailed(status: 409, body: _)):
                return .failure(PostActionError.editedAfterSaved)
            case .failure(.requestFailed(status: 404, body: _)):
                return .failure(PostActionError.postUnavailable)
            case .failure(.requestFailed(status: 401, body: _)), .failure(.notSignedIn):
                return .failure(CompanionServiceError.notSignedIn)
            case .failure: return .failure(PostActionError.notSaved)
            case .success(let data):
                struct Receipt: Decodable { let saved: Bool }
                guard let receipt = try? JSONDecoder().decode(Receipt.self, from: data), receipt.saved else {
                    return .failure(PostActionError.notSaved)
                }
                return .success(())
            }
        } catch {
            return .failure(PostActionError.notSaved)
        }
    }

    enum PostActionError: LocalizedError, Equatable {
        case notSaved, postUnavailable, editedAfterSaved
        var errorDescription: String? {
            switch self {
            case .notSaved:
                return NSLocalizedString("companion.post.action.retry", value: "Couldn’t save. Your draft is still here. Please retry.", comment: "Post action did not receive a server acknowledgement")
            case .editedAfterSaved:
                return NSLocalizedString("companion.post.action.edited", value: "Your previous submission was saved. These edited words have not been sent. Refresh to check its status.", comment: "A lost acknowledgement belongs to a different snapshot")
            case .postUnavailable:
                return NSLocalizedString("companion.post.action.unavailable", value: "This post is no longer available. Refresh discovery to find another companion.", comment: "A discovery post can no longer accept an action")
            }
        }
    }
}
