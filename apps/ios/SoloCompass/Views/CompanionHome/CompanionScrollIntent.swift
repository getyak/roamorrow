import Foundation

/// User intent is independent of changing content height and layout estimates.
struct CompanionScrollIntent: Equatable {
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
}
