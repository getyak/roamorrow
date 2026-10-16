import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class LocalRouteCompanionAcknowledgementTests: XCTestCase {
    private enum StorageFailure: Error { case full }
    private func route(status: CompanionStatus = .closed) -> Route {
        Route(id: .init(rawValue: "ack-route"), title: "Walk", summary: "", experienceIds: [], cityCode: "VTE", region: "River", estimatedDuration: 30, distanceMeters: 300, pace: .relaxed, source: .userCreated, verification: .init(status: .proposed, walkedByCount: 0, walkedBy: []), companion: .init(status: status, hostId: "host", departureWindow: .init(startDate: "2026-10-16", to: "2026-10-17", time: "morning"), departureLabel: "October", maxMembers: 3, confirmedMembers: ["host"], joinRequests: [.init(id: .init(rawValue: "request"), requesterId: "friend", message: "Hello", status: .pending, createdAt: "2026-10-16T00:00:00Z")]))
    }
    func testFailedCompletionNeverAcknowledgesOrLeaksThroughLaterSave() async throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let store = RouteStore(context: context)
        let original = route()
        try store.savePersisted(original)
        let remote = LocalRouteCompanionRemote(store: store, commit: { throw StorageFailure.full })
        do { try await remote.markCompleted(routeId: original.id); XCTFail("must throw") } catch { }
        XCTAssertEqual(store.get(original.id)?.companion?.status, .closed)
        try context.save()
        XCTAssertEqual(RouteStore(context: ModelContext(container)).get(original.id)?.companion?.status, .closed)
    }
    func testFailedAcceptRetainsPendingRequestAndNoConversation() async throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let store = RouteStore(context: context)
        let original = route(status: .open)
        try store.savePersisted(original)
        let request = try XCTUnwrap(original.companion?.joinRequests.first)
        let remote = LocalRouteCompanionRemote(store: store, commit: { throw StorageFailure.full })
        do { try await remote.accept(request, route: original); XCTFail("must throw") } catch { }
        XCTAssertEqual(store.get(original.id)?.companion?.joinRequests.first?.status, .pending)
        XCTAssertEqual(store.get(original.id)?.companion?.confirmedMembers, ["host"])
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ConversationRecord>()).isEmpty)
    }
    func testClosedRouteRejectsAcceptAndMissingRouteDoesNotAcknowledge() async throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let store = RouteStore(context: ModelContext(container))
        let original = route()
        try store.savePersisted(original)
        let remote = LocalRouteCompanionRemote(store: store)
        do { try await remote.accept(try XCTUnwrap(original.companion?.joinRequests.first), route: original); XCTFail("closed must reject") } catch { }
        do { try await remote.markCompleted(routeId: .init(rawValue: "missing")); XCTFail("missing must reject") } catch { }
        XCTAssertEqual(store.get(original.id)?.companion?.confirmedMembers, ["host"])
    }
}
