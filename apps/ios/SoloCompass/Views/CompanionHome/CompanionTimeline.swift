import Foundation

/// A display projection only. It never rewrites history or treats a meeting date as a creation date.
enum CompanionTimeline {
    struct Change: Equatable, Sendable {
        var revision: UInt64 = 0
        var insertedCount = 0
        var hasUserAction = false
        var reset = false
        var contentRevision: UInt64 = 0
        var userActionRevision: UInt64 = 0
    }

    /// Prepared when content changes, never in a scroll-driven view body.
    struct Projection: Sendable {
        struct Row: Identifiable, Sendable {
            let id: String
            let event: Event
        }
        let events: [Event]
        let rows: [Row]
        let eventIDs: Set<String>
        let replyContexts: [UUID: String]
        let timestampIDs: Set<UUID>
        let change: Change

        init(entries: [CompanionHomeEntry] = [], invites: [CompanionHomeInvite] = [],
             previous: Projection? = nil, revision: UInt64 = 0, calendar: Calendar = .current) {
            let events = CompanionTimeline.events(entries: entries, invites: invites)
            self.events = events
            let rows = events.map { Row(id: $0.id, event: $0) }
            self.rows = rows
            eventIDs = Set(rows.map(\.id))
            replyContexts = CompanionTimeline.replyContexts(in: events)
            let oldIDs = previous?.eventIDs ?? []
            var insertedCount = 0
            var userAction = false
            var timestampIDs: Set<UUID> = []
            var priorMessage: CompanionHomeEntry?
            for row in rows {
                let event = row.event
                if !oldIDs.contains(row.id) {
                    insertedCount += 1
                    userAction = userAction || event.isUserAction
                }
                guard case .message(let message) = event else { continue }
                if let priorMessage {
                    if !calendar.isDate(priorMessage.createdAt, inSameDayAs: message.createdAt)
                        || message.createdAt.timeIntervalSince(priorMessage.createdAt) >= 300 {
                        timestampIDs.insert(message.id)
                    }
                } else { timestampIDs.insert(message.id) }
                priorMessage = message
            }
            self.timestampIDs = timestampIDs
            change = Change(revision: revision, insertedCount: insertedCount, hasUserAction: userAction,
                            reset: events.isEmpty && !(previous?.events.isEmpty ?? true),
                            contentRevision: insertedCount > 0 ? revision : (previous?.change.contentRevision ?? 0),
                            userActionRevision: userAction ? revision : (previous?.change.userActionRevision ?? 0))
        }
    }

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
