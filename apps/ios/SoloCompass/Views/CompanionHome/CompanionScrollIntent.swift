import Foundation

/// User intent is independent of changing content height and layout estimates.
struct CompanionScrollIntent: Equatable {
    enum ScrollRequestKind: Equatable, Sendable { case following, explicit, restoration }

    struct ScrollRequest: Equatable, Sendable {
        var revision = 0
        var target: String? = "stream-bottom"
        var animated = false
        var kind: ScrollRequestKind = .following

        mutating func cancelForInteraction() {
            // A deferred automatic request must not revive after the gesture
            // finishes and following becomes eligible again.
            guard kind != .explicit, target != nil else { return }
            revision += 1
            target = nil
        }
    }
    private(set) var followsLatest: Bool
    private(set) var hasUnread: Bool
    private(set) var isInteracting = false
    private(set) var nearLatest: Bool

    init(reading: CompanionConversationReadingState) {
        followsLatest = reading.followsLatest
        hasUnread = reading.hasUnread
        nearLatest = reading.followsLatest
    }

    mutating func interactionChanged(active: Bool) {
        guard isInteracting != active else { return }
        isInteracting = active
        if active { followsLatest = false }
        else if nearLatest { revealLatest() }
    }

    mutating func visibilityChanged(nearLatest: Bool) {
        self.nearLatest = nearLatest
        // Layout/keyboard changes must not cancel a saved reading-history intent.
        if nearLatest && followsLatest && !isInteracting { hasUnread = false }
    }

    /// True requests one coalesced scroll, not an animation through history.
    mutating func contentArrived(isUserAction: Bool) -> Bool {
        if isUserAction { revealLatest(); return true }
        guard followsLatest && !isInteracting else { hasUnread = true; return false }
        return true
    }

    mutating func revealLatest() {
        followsLatest = true
        hasUnread = false
    }

    /// Keyboard/layout-driven binding updates are observations, not a new
    /// reading intention. Only native user scrolling may move a history anchor.
    func anchorForSaving(visible: String?, saved: String?) -> String? {
        if followsLatest { return "stream-bottom" }
        return isInteracting ? visible : saved
    }

    func permitsScroll(_ kind: ScrollRequestKind) -> Bool {
        switch kind {
        case .explicit: return true
        case .restoration: return !isInteracting
        case .following: return followsLatest && !isInteracting
        }
    }

    func permitsScroll(_ request: ScrollRequest, currentRevision: Int) -> Bool {
        request.revision == currentRevision && request.target != nil && permitsScroll(request.kind)
    }

    func keyboardRestorationTarget(reading: CompanionConversationReadingState) -> String? {
        guard !isInteracting else { return nil }
        if followsLatest { return "stream-bottom" }
        // A tall row can leave the persisted ID temporarily behind the native
        // offset. Keyboard layout must never promote current history intent
        // from a stale latest checkpoint or reset its unread state.
        guard let anchor = reading.anchorID, anchor != "stream-bottom" else { return nil }
        return anchor
    }
}
