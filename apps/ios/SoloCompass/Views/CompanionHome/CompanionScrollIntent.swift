import CoreGraphics
import Foundation
import Observation

/// User intent is independent of changing content height and layout estimates.
struct CompanionScrollIntent: Equatable {
    enum ScrollRequestKind: Equatable, Sendable { case following, explicit, restoration }

    struct ScrollRequest: Equatable, Sendable {
        var revision = 0
        var target: String? = "stream-bottom"
        var animated = false
        var kind: ScrollRequestKind = .following

        static func initial(reading: CompanionConversationReadingState) -> Self {
            guard !reading.followsLatest else { return Self() }
            return Self(revision: reading.anchorID == nil ? 0 : 1, target: reading.anchorID, kind: .restoration)
        }

        mutating func enqueue(target: String? = "stream-bottom", animated: Bool = false, kind: ScrollRequestKind) {
            // Working/content notifications can follow a send in the same
            // render turn. Preserve that explicit intent until it is consumed.
            let pendingSend = self.target != nil && self.target == target && self.kind == .explicit && kind == .following
            self = Self(revision: revision + 1, target: target, animated: animated, kind: pendingSend ? .explicit : kind)
        }

        mutating func consume(revision: Int) {
            guard self.revision == revision else { return }
            target = nil
        }

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
    private(set) var hasInteractedSinceRestore = false

    init(reading: CompanionConversationReadingState) {
        followsLatest = reading.followsLatest
        hasUnread = reading.hasUnread
        nearLatest = reading.followsLatest
    }

    mutating func interactionChanged(active: Bool) {
        guard isInteracting != active else { return }
        isInteracting = active
        if active { followsLatest = false; hasInteractedSinceRestore = true }
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

    func permitsScroll(_ request: ScrollRequest, current: ScrollRequest) -> Bool {
        current.target != nil && request.revision == current.revision && request.target != nil && permitsScroll(request.kind)
    }

    func keyboardRestorationTarget(reading: CompanionConversationReadingState) -> String? {
        guard !isInteracting else { return nil }
        if followsLatest { return "stream-bottom" }
        // A row ID does not encode a reader's position inside a tall message.
        // Native manual scrolling relinquishes layout restoration until the
        // next explicit map/tab restore constructs a fresh intent.
        guard !hasInteractedSinceRestore else { return nil }
        // A tall row can leave the persisted ID temporarily behind the native
        // offset. Keyboard layout must never promote current history intent
        // from a stale latest checkpoint or reset its unread state.
        guard let anchor = reading.anchorID, anchor != "stream-bottom" else { return nil }
        return anchor
    }
}


/// Scroll policy is not display state. Only its small presentation projection
/// and the execution channel publish changes, to their respective child views.
@MainActor
@Observable
final class CompanionScrollState {
    struct Presentation: Equatable {
        var showsLatest: Bool
        var hasUnread: Bool
        init(_ intent: CompanionScrollIntent) {
            showsLatest = intent.hasUnread || (!intent.followsLatest && !intent.nearLatest)
            hasUnread = intent.hasUnread
        }
    }

    @ObservationIgnored private(set) var intent: CompanionScrollIntent
    private(set) var request: CompanionScrollIntent.ScrollRequest
    private(set) var presentation: Presentation
    private(set) var viewport = CGRect.zero

    init(reading: CompanionConversationReadingState) {
        let intent = CompanionScrollIntent(reading: reading)
        self.intent = intent
        request = .initial(reading: reading)
        presentation = Presentation(intent)
    }

    func restore(reading: CompanionConversationReadingState) {
        intent = CompanionScrollIntent(reading: reading)
        if let target = reading.anchorID { request.enqueue(target: target, kind: .restoration) }
        publishPresentation()
    }

    func setInteraction(_ active: Bool) {
        guard intent.isInteracting != active else { return }
        intent.interactionChanged(active: active)
        if active { request.cancelForInteraction() }
        publishPresentation()
    }

    func setNearLatest(_ near: Bool) {
        guard near != intent.nearLatest else { return }
        intent.visibilityChanged(nearLatest: near)
        publishPresentation()
    }

    func contentArrived(isUserAction: Bool) -> Bool {
        let follow = intent.contentArrived(isUserAction: isUserAction)
        publishPresentation()
        return follow
    }

    func revealLatest() { intent.revealLatest(); publishPresentation() }

    func enqueue(target: String? = "stream-bottom", animated: Bool = false,
                 kind: CompanionScrollIntent.ScrollRequestKind) {
        request.enqueue(target: target, animated: animated, kind: kind)
    }

    func consume(revision: Int) {
        guard request.revision == revision, request.target != nil else { return }
        request.consume(revision: revision)
    }

    func updateViewport(_ value: CGRect, isActive: Bool = true) {
        guard viewport != value else { return }
        let resized = viewport.height > 0 && viewport.size != value.size
        viewport = value
        // Composer wrapping and keyboard layout can move the native position
        // without a scroll gesture. Keep only an idle latest intention pinned.
        if resized, value.height > 0, value.width > 0, isActive,
           intent.followsLatest, !intent.isInteracting {
            request.enqueue(kind: .following)
        }
    }

    private func publishPresentation() {
        let updated = Presentation(intent)
        if updated != presentation { presentation = updated }
    }
}
