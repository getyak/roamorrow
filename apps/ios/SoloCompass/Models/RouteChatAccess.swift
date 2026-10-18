import Foundation

// MARK: - RouteChatAccess

/// Pure decision for the route-detail group-chat entry (R2-02).
///
/// A closed/completed group may or may not have a real conversation row, and
/// the viewer may or may not be allowed into it. The old dock rendered an
/// enabled "Open group chat" CTA whose action either did nothing (closed) or
/// played the completion celebration (completed) — a dead action and a
/// celebration wearing a chat label. `decide` makes the three real outcomes
/// explicit so the view can only ever enable the button when a chat will
/// actually open.
public enum RouteChatAccess: Equatable {
    /// A conversation exists and the viewer is allowed in — push ChatView.
    case available(Conversation)
    /// The companion slot exists but no group conversation was created yet.
    case noConversation
    /// A conversation exists but the viewer is not a participant / member.
    case notAuthorized

    /// - Parameters:
    ///   - companion: the route's companion slot.
    ///   - conversation: the stored conversation for
    ///     `companion.groupConversationId` (nil when absent or not loaded).
    ///   - viewerId: the current device/user id.
    public static func decide(
        companion: RouteCompanion,
        conversation: Conversation?,
        viewerId: String
    ) -> RouteChatAccess {
        guard let conversation else { return .noConversation }
        if conversation.participantIds.contains(viewerId) {
            return .available(conversation)
        }
        if companion.hostId == viewerId || companion.confirmedMembers.contains(viewerId) {
            return .available(conversation)
        }
        return .notAuthorized
    }
}

// MARK: - RouteCompletionReplay

/// Who may replay the completion celebration, kept OUT of the chat label.
/// Completion replay is a host-only recap of a finished route — naming and
/// gating it separately prevents "Open group chat" from secretly celebrating.
public enum RouteCompletionReplay {
    /// True when the host of a COMPLETED route may replay the moment.
    /// (Hosts of a merely `.closed` route get the real "Mark done" action
    /// instead — see RouteDetailView.showMarkCompleted.)
    public static func isReplayVisible(status: CompanionStatus, viewerIsHost: Bool) -> Bool {
        viewerIsHost && status == .completed
    }
}
