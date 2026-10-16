import SwiftData
import XCTest
@testable import SoloCompass

/// Atomic route and conversation persistence: one staged route +
/// conversation snapshot committed ATOMICALLY ONCE — never per-friend partial
/// commits. A real injected commit failure must leave the route, its group
/// conversation AND unrelated rows exactly as they were.
@MainActor
final class InviteFriendsPersistTests: XCTestCase {

    private struct CommitFailure: Error {}

    private var context: ModelContext!
    private var routeStore: RouteStore!

    override func setUp() async throws {
        try await super.setUp()
        context = ModelContext(SoloCompassModelContainer.makeInMemory())
        routeStore = RouteStore(context: context)
    }

    override func tearDown() async throws {
        routeStore = nil
        context = nil
        try await super.tearDown()
    }

    private func makeRoute(
        id: String = "route_invite",
        status: CompanionStatus = .open,
        maxMembers: Int = 4,
        confirmedMembers: [String] = [],
        groupConversationId: String? = nil
    ) -> Route {
        let companion = RouteCompanion(
            status: status,
            hostId: "host",
            departureWindow: DepartureWindow(startDate: "2026-07-01", to: "2026-07-03", time: "morning"),
            departureLabel: "Jul 1–3 · morning",
            maxMembers: maxMembers,
            confirmedMembers: confirmedMembers,
            groupConversationId: groupConversationId
        )
        return Route(
            id: RouteId(rawValue: id),
            title: "Invite Route",
            summary: "",
            experienceIds: ["e1"],
            cityCode: "VTE",
            region: "Riverfront",
            estimatedDuration: 60,
            distanceMeters: 800,
            pace: .standard,
            source: .userCreated,
            companion: companion
        )
    }

    // MARK: - Success: one atomic write

    func testConfirmFriendsWritesRouteAndConversationOnce() throws {
        let route = makeRoute()
        routeStore.save(route)

        let added = try InviteFriendsSheet.confirmFriendsPersisted(
            ["maya", "kenji"],
            into: route,
            contextProvider: { self.context }
        )

        XCTAssertEqual(added, ["maya", "kenji"])
        let updated = try XCTUnwrap(routeStore.get(route.id))
        let companion = try XCTUnwrap(updated.companion)
        XCTAssertEqual(companion.confirmedMembers, ["maya", "kenji"])
        XCTAssertEqual(companion.status, .forming)
        let conv = try XCTUnwrap(
            ConversationStore(context: context)
                .get(ConversationId(rawValue: try XCTUnwrap(companion.groupConversationId)))
        )
        XCTAssertEqual(Set(conv.participantIds), ["host", "maya", "kenji"])
    }

    // MARK: - Injected commit failure: nothing partial, nothing lost

    func testCommitFailureRollsBackBothRowsAndKeepsUnrelatedRows() throws {
        // Unrelated rows that must survive an unrelated failed write.
        let unrelated = makeRoute(id: "route_unrelated")
        routeStore.save(unrelated)
        let unrelatedConv = Conversation(
            id: ConversationId(rawValue: "conv_unrelated"),
            participantIds: ["a", "b"],
            type: .groupRoute,
            routeId: "route_unrelated",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
        ConversationStore(context: context).save(unrelatedConv)

        let route = makeRoute()
        routeStore.save(route)

        XCTAssertThrowsError(
            try InviteFriendsSheet.confirmFriendsPersisted(
                ["maya", "kenji"],
                into: route,
                contextProvider: { self.context },
                commit: { throw CommitFailure() }
            )
        )

        // Route unchanged: no partial membership, no dangling conversation id.
        let after = try XCTUnwrap(routeStore.get(route.id))
        XCTAssertEqual(after.companion?.confirmedMembers ?? [], [])
        XCTAssertNil(after.companion?.groupConversationId)
        // No group conversation row was left behind.
        XCTAssertTrue(ConversationStore(context: context).all().count == 1,
                      "only the unrelated conversation may exist")

        // Unrelated rows are untouched.
        XCTAssertEqual(routeStore.get(RouteId(rawValue: "route_unrelated"))?.title, "Invite Route")
        XCTAssertEqual(
            ConversationStore(context: context).get(ConversationId(rawValue: "conv_unrelated"))?.participantIds,
            ["a", "b"]
        )
    }

    func testCommitFailureOnExistingConversationKeepsParticipants() throws {
        let conv = Conversation(
            id: ConversationId(rawValue: "conv_group"),
            participantIds: ["host"],
            type: .groupRoute,
            routeId: "route_invite",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
        ConversationStore(context: context).save(conv)
        let route = makeRoute(status: .forming, confirmedMembers: ["maya"], groupConversationId: "conv_group")
        routeStore.save(route)

        XCTAssertThrowsError(
            try InviteFriendsSheet.confirmFriendsPersisted(
                ["kenji"],
                into: route,
                contextProvider: { self.context },
                commit: { throw CommitFailure() }
            )
        )

        let after = try XCTUnwrap(routeStore.get(route.id))
        XCTAssertEqual(after.companion?.confirmedMembers ?? [], ["maya"], "no partial membership")
        let restored = try XCTUnwrap(
            ConversationStore(context: context).get(ConversationId(rawValue: "conv_group"))
        )
        XCTAssertEqual(restored.participantIds, ["host"], "conversation rolls back to its prior value")
    }

    func testMissingRouteDoesNotResurrectStaleSheetSnapshot() {
        let route = makeRoute()
        XCTAssertThrowsError(try InviteFriendsSheet.confirmFriendsPersisted(["maya"], into: route, contextProvider: { self.context }))
        XCTAssertNil(routeStore.get(route.id))
        XCTAssertTrue(ConversationStore(context: context).all().isEmpty)
    }

    func testCompletedRouteRejectsMembershipWithoutMutation() {
        let route = makeRoute(status: .completed)
        routeStore.save(route)
        XCTAssertThrowsError(try InviteFriendsSheet.confirmFriendsPersisted(["maya"], into: route, contextProvider: { self.context }))
        XCTAssertEqual(routeStore.get(route.id)?.companion?.confirmedMembers, [])
        XCTAssertTrue(ConversationStore(context: context).all().isEmpty)
    }

    // MARK: - Legacy wrapper compatibility

    func testLegacyWrapperStillAddsFriendsOnSuccess() {
        let route = makeRoute()
        routeStore.save(route)
        // Kept for old callers/tests: same selection semantics as the throwing
        // method on the success path (no injected failure — that path is
        // covered by the throwing method above).
        let added = InviteFriendsSheet.confirmFriends(
            ["maya", "kenji"],
            into: route,
            contextProvider: { self.context }
        )
        XCTAssertEqual(added, ["maya", "kenji"])
        XCTAssertEqual(routeStore.get(route.id)?.companion?.confirmedMembers, ["maya", "kenji"])
    }
}
