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
        let events: [Event]
        // Lazy layout scans identities when resolving native scroll positions.
        // Keep that collection independent of the full message/media payload.
        let rowIDs: [String]
        let eventIDs: Set<String>
        let replyContexts: [UUID: String]
        let timestampIDs: Set<UUID>
        let change: Change
        private let rowOrder: [String: Int]

        func event(forID id: String) -> Event? {
            guard let index = rowOrder[id] else { return nil }
            return events[index]
        }

        func readingAnchor(visibleIDs: [String], retaining previous: String?) -> String? {
            if let previous, visibleIDs.contains(previous) { return previous }
            var latest: String?
            var latestOrder = -1
            for id in visibleIDs {
                if let order = rowOrder[id], order > latestOrder { latest = id; latestOrder = order }
            }
            if let latest { return latest }
            if events.isEmpty, visibleIDs.contains("stream-introduction") { return "stream-introduction" }
            if visibleIDs.contains("stream-commitments") { return "stream-commitments" }
            if visibleIDs.contains("stream-bottom") { return "stream-bottom" }
            // Visibility can temporarily be empty during layout, or for an
            // exceptionally tall row. It never means "resume following".
            return previous
        }

        init(entries: [CompanionHomeEntry] = [], invites: [CompanionHomeInvite] = [],
             previous: Projection? = nil, revision: UInt64 = 0, calendar: Calendar = .current) {
            let events = CompanionTimeline.events(entries: entries, invites: invites)
            self.events = events
            let rowIDs = events.map(\.id)
            self.rowIDs = rowIDs
            var order: [String: Int] = [:]
            order.reserveCapacity(rowIDs.count)
            for (index, id) in rowIDs.enumerated() { order[id] = index }
            rowOrder = order
            eventIDs = Set(rowIDs)
            replyContexts = CompanionTimeline.replyContexts(in: events)
            let oldIDs = previous?.eventIDs ?? []
            var insertedCount = 0
            var userAction = false
            var timestampIDs: Set<UUID> = []
            var priorMessage: CompanionHomeEntry?
            for event in events {
                if !oldIDs.contains(event.id) {
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
