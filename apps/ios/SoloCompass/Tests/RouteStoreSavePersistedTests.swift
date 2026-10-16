import SwiftData
import XCTest
@testable import SoloCompass

/// Throwing save paths with OWN-change rollback and notify-only-on-success
/// semantics (contract 3). The injectable `commit` seam forces durable-write
/// failures without touching the shared container.
@MainActor
final class RouteStoreSavePersistedTests: XCTestCase {

    private struct CommitFailure: Error {}

    private var context: ModelContext!
    private var store: RouteStore!

    override func setUp() async throws {
        try await super.setUp()
        context = ModelContext(SoloCompassModelContainer.makeInMemory())
        store = RouteStore(context: context)
    }

    override func tearDown() async throws {
        store = nil
        context = nil
        try await super.tearDown()
    }

    private func makeRoute(id: String, title: String) -> Route {
        Route(
            id: RouteId(rawValue: id),
            title: title,
            summary: "summary",
            experienceIds: ["exp_a", "exp_b"],
            cityCode: "VTE",
            region: "Riverfront",
            estimatedDuration: 60,
            distanceMeters: 1000,
            pace: .relaxed,
            source: .userCreated
        )
    }

    // MARK: - Success path

    func testSavePersistedUpsertsAndNotifiesOnce() {
        let route = makeRoute(id: "route_ok", title: "Original")
        var notifications: [String] = []
        let token = NotificationCenter.default.addObserver(
            forName: RouteStore.didChange,
            object: nil,
            queue: nil
        ) { note in
            if let id = note.userInfo?["routeId"] as? String { notifications.append(id) }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try? store.savePersisted(makeRoute(id: "route_ok", title: "Updated"))

        XCTAssertEqual(notifications, ["route_ok"])
        XCTAssertEqual(store.get(route.id)?.title, "Updated")
    }

    func testSavePersistedPreservesActiveRouteProgress() {
        let route = makeRoute(id: "route_progress", title: "Walk")
        store.save(route)
        store.startRoute(route.id)
        let startedBefore = store.loadActiveRoute()

        try? store.savePersisted(makeRoute(id: "route_progress", title: "Walk v2"))

        let after = store.loadActiveRoute()
        XCTAssertNotNil(after, "Re-saving the route must not wipe active progress")
        XCTAssertEqual(after?.route.title, "Walk v2")
        XCTAssertEqual(after?.stopIndex, startedBefore?.stopIndex)
    }

    // MARK: - Failure path (rollback + no notify)

    func testSavePersistedFailureKeepsPreviousValueAndDoesNotNotify() {
        store.save(makeRoute(id: "route_fail", title: "Keep me"))

        var notifications = 0
        let token = NotificationCenter.default.addObserver(
            forName: RouteStore.didChange,
            object: nil,
            queue: nil
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertThrowsError(
            try store.savePersisted(makeRoute(id: "route_fail", title: "Never lands")) {
                throw CommitFailure()
            }
        )

        XCTAssertEqual(notifications, 0, "A failed commit must not announce a change")
        XCTAssertEqual(
            store.get(RouteId(rawValue: "route_fail"))?.title,
            "Keep me",
            "Own pending delete/insert must roll back to the prior value"
        )
    }

    func testSavePersistedFailureOnNewRouteLeavesNoRow() {
        XCTAssertThrowsError(
            try store.savePersisted(makeRoute(id: "route_new_fail", title: "Ghost")) {
                throw CommitFailure()
            }
        )
        XCTAssertNil(store.get(RouteId(rawValue: "route_new_fail")))
    }

    func testRecoveryAfterFailedSavePersisted() {
        store.save(makeRoute(id: "route_retry", title: "First"))
        XCTAssertThrowsError(
            try store.savePersisted(makeRoute(id: "route_retry", title: "Middle")) {
                throw CommitFailure()
            }
        )
        // The retry (same content the user still sees) must succeed cleanly.
        try? store.savePersisted(makeRoute(id: "route_retry", title: "Final"))
        XCTAssertEqual(store.get(RouteId(rawValue: "route_retry"))?.title, "Final")
    }

    // MARK: - Atomic route + conversation pair

    private func makeConversation(id: String) -> Conversation {
        Conversation(
            id: ConversationId(rawValue: id),
            participantIds: ["host", "guest"],
            type: .groupRoute,
            routeId: "route_pair",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
    }

    func testSaveRouteAndConversationCommitsBothOnSuccess() throws {
        store.save(makeRoute(id: "route_pair", title: "Pair"))
        let conversation = makeConversation(id: "conv_pair")

        try store.saveRouteAndConversation(
            makeRoute(id: "route_pair", title: "Pair updated"),
            conversation: conversation
        )

        XCTAssertEqual(store.get(RouteId(rawValue: "route_pair"))?.title, "Pair updated")
        let stored = ConversationStore(context: context).get(ConversationId(rawValue: "conv_pair"))
        XCTAssertEqual(stored?.id.rawValue, "conv_pair")
        XCTAssertEqual(stored?.participantIds, ["host", "guest"])
    }

    func testSaveRouteAndConversationFailureRollsBackBothRows() {
        store.save(makeRoute(id: "route_pair", title: "Pair prior"))
        let priorConversation = makeConversation(id: "conv_pair")
        ConversationStore(context: context).save(priorConversation)

        var notifications = 0
        let token = NotificationCenter.default.addObserver(
            forName: RouteStore.didChange,
            object: nil,
            queue: nil
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        let mutatedConversation = Conversation(
            id: ConversationId(rawValue: "conv_pair"),
            participantIds: ["host", "guest", "third"],
            type: .groupRoute,
            routeId: "route_pair",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-02-01T00:00:00Z"
        )
        XCTAssertThrowsError(
            try store.saveRouteAndConversation(
                makeRoute(id: "route_pair", title: "Pair never lands"),
                conversation: mutatedConversation
            ) {
                throw CommitFailure()
            }
        )

        XCTAssertEqual(notifications, 0)
        XCTAssertEqual(store.get(RouteId(rawValue: "route_pair"))?.title, "Pair prior")
        let restored = ConversationStore(context: context).get(ConversationId(rawValue: "conv_pair"))
        XCTAssertEqual(restored?.participantIds, ["host", "guest"], "Conversation must roll back to its prior value")
    }
}
