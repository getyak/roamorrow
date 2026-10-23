import Foundation

/// A display projection only. It never rewrites history or treats a meeting date as a creation date.
enum CompanionTimeline {
    enum Event: Identifiable, Equatable, Sendable {
        case message(CompanionHomeEntry)
        case invite(CompanionHomeInvite)

        var id: String {
            switch self {
            case .message(let value): return "message:\(value.id)"
            case .invite(let value): return "invite:\(value.id)"
            }
        }

        var createdAt: Date? {
            switch self {
            case .message(let value): return value.createdAt
            case .invite(let value): return value.createdAt
            }
        }

        var isUserAction: Bool {
            switch self {
            case .message(let value): return value.role == .user
            case .invite: return true
            }
        }
    }

    static func events(entries: [CompanionHomeEntry], invites: [CompanionHomeInvite]) -> [Event] {
        let combined = entries.map(Event.message) + invites.map(Event.invite)
        return combined.enumerated().sorted { lhs, rhs in
            switch (lhs.element.createdAt, rhs.element.createdAt) {
            case (nil, nil): return lhs.offset < rhs.offset
            case (nil, _): return true
            case (_, nil): return false
            case let (.some(left), .some(right)):
                return left == right ? lhs.offset < rhs.offset : left < right
            }
        }.map(\.element)
    }

    static func replyContext(for entry: CompanionHomeEntry, in events: [Event]) -> String? {
        replyContexts(in: events)[entry.id]
    }

    static func replyContexts(in events: [Event]) -> [UUID: String] {
        var originals: [UUID: String] = [:]
        for event in events {
            if case .message(let original) = event { originals[original.id] = original.text }
        }
        var contexts: [UUID: String] = [:]
        for (position, event) in events.enumerated() {
            guard case .message(let entry) = event, entry.role == .companion, let replyID = entry.replyToID else { continue }
            if position > 0, case .message(let previous) = events[position - 1], previous.id == replyID { continue }
            contexts[entry.id] = originals[replyID]
        }
        return contexts
    }
}
