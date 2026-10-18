import Foundation
import SwiftData

// MARK: - LocalRouteCompanionRemote

/// `RouteCompanionRemote` that persists mutations via `RouteStore` (SwiftData).
/// Used when `FF_BACKEND_SYNC` is false — all data lives on-device.
@MainActor
public final class LocalRouteCompanionRemote: RouteCompanionRemote {
    enum MutationError: Error, Equatable { case missingRoute, missingCompanion, missingRequest, invalidState }
    private let store: RouteStore
    private let commit: (() throws -> Void)?

    public init(context: ModelContext) {
        self.store = RouteStore(context: context)
        self.commit = nil
    }

    public init(store: RouteStore, commit: (() throws -> Void)? = nil) {
        self.store = store
        self.commit = commit
    }

    // MARK: - RouteCompanionRemote

    /// Fetches routes currently recruiting companions in the given city.
    public func fetchRecruitingRoutes(cityCode: String) async throws -> [Route] {
        store.all().filter {
            $0.cityCode == cityCode
                && ($0.companion?.status == .open || $0.companion?.status == .forming)
        }
    }

    /// Submits a request to join a route's companion group with a message and pace preference.
    public func sendJoinRequest(routeId: RouteId, message: String, pace: String) async throws {
        guard var route = store.get(routeId) else { throw MutationError.missingRoute }
        guard var companion = route.companion else { throw MutationError.missingCompanion }
        guard companion.status == .open || companion.status == .forming,
              companion.confirmedMembers.count < companion.maxMembers else { throw MutationError.invalidState }
        let request = JoinRequest(
            id: JoinRequestId(rawValue: UUID().uuidString),
            requesterId: DeviceIdentityService.shared.deviceID,
            message: "\(pace): \(message)",
            status: .pending,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        companion.joinRequests.append(request)
        route.companion = companion
        try store.savePersisted(route, commit: commit)
    }

    /// Fetches the host's pending join requests awaiting a decision.
    public func fetchInbox() async throws -> [JoinRequest] {
        let hostId = DeviceIdentityService.shared.deviceID
        return store.all().flatMap { route -> [JoinRequest] in
            guard let companion = route.companion, companion.hostId == hostId else { return [] }
            return companion.joinRequests.filter { $0.status == .pending }
        }
    }

    /// Accepts a join request, adding the requester to the route's companion group and forming its group chat.
    public func accept(_ request: JoinRequest, route: Route) async throws {
        guard var updated = store.get(route.id) else { throw MutationError.missingRoute }
        guard var companion = updated.companion else { throw MutationError.missingCompanion }
        guard let idx = companion.joinRequests.firstIndex(where: { $0.id == request.id }) else { throw MutationError.missingRequest }

        guard companion.joinRequests[idx].status == .pending else {
            if companion.joinRequests[idx].status == .accepted && companion.confirmedMembers.contains(request.requesterId) { return }
            throw MutationError.invalidState
        }
        guard companion.confirmedMembers.count < companion.maxMembers else { throw MutationError.invalidState }
        let wasOpen = companion.status == .open
        let event: CompanionEvent = wasOpen ? .acceptFirst : .acceptAdditional
        let newStatus = try RouteCompanionStateMachine.transition(state: companion.status, event: event)
        companion.joinRequests[idx].status = .accepted
        if !companion.confirmedMembers.contains(request.requesterId) { companion.confirmedMembers.append(request.requesterId) }
        companion.status = newStatus

        if companion.confirmedMembers.count >= companion.maxMembers,
           let closed = try? RouteCompanionStateMachine.transition(state: companion.status, event: .reachMax) {
            companion.status = closed
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let convStore = ConversationStore(context: store.context)

        if companion.groupConversationId == nil {
            // First accept: open → forming. Create the group conversation.
            let convId = ConversationId(rawValue: UUID().uuidString)
            let conversation = Conversation(
                id: convId,
                requestId: CompanionRequestId(rawValue: request.id.rawValue),
                participantIds: [companion.hostId] + companion.confirmedMembers.filter { $0 != companion.hostId },
                type: .groupRoute,
                routeId: route.id.rawValue,
                createdAt: now,
                updatedAt: now
            )
            companion.groupConversationId = convId.rawValue
            updated.companion = companion
            try store.saveRouteAndConversation(updated, conversation: conversation, commit: commit)
        } else if let existingConvIdStr = companion.groupConversationId,
                  let existingConv = convStore.get(ConversationId(rawValue: existingConvIdStr)) {
            // Subsequent accept: still forming. Append requesterId to participants.
            var participants = existingConv.participantIds
            if !participants.contains(request.requesterId) {
                participants.append(request.requesterId)
            }
            let updatedConv = Conversation(
                id: existingConv.id,
                requestId: existingConv.requestId,
                participantIds: participants,
                type: existingConv.type,
                routeId: existingConv.routeId,
                lastMessageAt: existingConv.lastMessageAt,
                createdAt: existingConv.createdAt,
                updatedAt: now
            )
            updated.companion = companion
            try store.saveRouteAndConversation(updated, conversation: updatedConv, commit: commit)
        } else {
            throw MutationError.invalidState
        }
    }

    /// Declines a join request, leaving the companion group unchanged.
    public func decline(_ request: JoinRequest, route: Route) async throws {
        guard var updated = store.get(route.id) else { throw MutationError.missingRoute }
        guard var companion = updated.companion else { throw MutationError.missingCompanion }
        guard let idx = companion.joinRequests.firstIndex(where: { $0.id == request.id }) else { throw MutationError.missingRequest }
        if companion.joinRequests[idx].status == .declined { return }
        guard companion.joinRequests[idx].status == .pending else { throw MutationError.invalidState }
        companion.joinRequests[idx].status = .declined
        updated.companion = companion
        try store.savePersisted(updated, commit: commit)
    }

    /// Withdraws a previously submitted join request.
    public func withdraw(_ request: JoinRequest, route: Route) async throws {
        guard var updated = store.get(route.id) else { throw MutationError.missingRoute }
        guard var companion = updated.companion else { throw MutationError.missingCompanion }
        guard let idx = companion.joinRequests.firstIndex(where: { $0.id == request.id }) else { throw MutationError.missingRequest }
        if companion.joinRequests[idx].status == .withdrawn { return }
        guard companion.joinRequests[idx].status == .pending else { throw MutationError.invalidState }
        companion.joinRequests[idx].status = .withdrawn
        updated.companion = companion
        try store.savePersisted(updated, commit: commit)
    }

    /// Marks a route as completed, verifying it and crediting the confirmed companions as walkers.
    public func markCompleted(routeId: RouteId) async throws {
        guard var route = store.get(routeId) else { throw MutationError.missingRoute }
        guard var companion = route.companion else { throw MutationError.missingCompanion }
        if companion.status == .completed { return }
        let newStatus = try RouteCompanionStateMachine.transition(
            state: companion.status,
            event: .markCompleted
        )
        companion.status = newStatus
        route.companion = companion
        let newMembers = Set(companion.confirmedMembers).subtracting(route.verification.walkedBy)
        route.verification.status = .verified
        route.verification.walkedByCount += newMembers.count
        for memberId in newMembers where !route.verification.walkedBy.contains(memberId) {
            route.verification.walkedBy.append(memberId)
        }

        if let convIdStr = companion.groupConversationId {
            let convStore = ConversationStore(context: store.context)
            let convId = ConversationId(rawValue: convIdStr)
            if let conv = convStore.get(convId) {
                let frozen = Conversation(
                    id: conv.id,
                    requestId: conv.requestId,
                    participantIds: conv.participantIds,
                    type: conv.type,
                    routeId: conv.routeId,
                    lastMessageAt: conv.lastMessageAt,
                    createdAt: conv.createdAt,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    isReadOnly: true
                )
                try store.saveRouteAndConversation(route, conversation: frozen, commit: commit)
                return
            }
        }

        try store.savePersisted(route, commit: commit)
    }
}
