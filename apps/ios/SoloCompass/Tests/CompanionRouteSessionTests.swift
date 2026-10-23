import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class CompanionRouteSessionTests: XCTestCase {
    private struct SaveFailure: Error {}
    private final class Publisher: CompanionRoutePublishing {
        var shown: [CompanionRouteProgress] = []
        var ended: [String] = []
        func show(_ value: CompanionRouteProgress) async -> Bool { shown.append(value); return true }
        func end(contextID: String) async { ended.append(contextID) }
    }
    private func fixture() -> (RouteStore, Publisher, Experience) {
        let store = RouteStore(context: ModelContext(SoloCompassModelContainer.makeInMemory()))
        return (store, Publisher(), ExperienceService.hardcodedSeed[0])
    }
    func testDurableStartRestoresSameTaskWithoutStartingAnotherRoute() async throws {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        let outcome1 = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(outcome1)
        let first = try XCTUnwrap(session.active)
        XCTAssertEqual(first.placeID, place.id)
        XCTAssertEqual(first.stopIndex, 0)
        XCTAssertEqual(first.totalStops, 1)
        XCTAssertEqual(first.etaText, "")
        let reopened = CompanionRouteSession(routeStore: store, publisher: publisher)
        await reopened.refresh(experiences: [place])
        XCTAssertEqual(reopened.active?.contextID, first.contextID)
        XCTAssertEqual(store.all().count, 1)
        let outcome2 = await reopened.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(outcome2)
        XCTAssertEqual(store.all().count, 1)
    }
    func testFailedStartDoesNotLeavePhantomProgressOrPublishAnActivity() async {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher,
                                            commit: { throw SaveFailure() })
        let outcome3 = await session.start(experience: place, cityCode: "cmi")
        XCTAssertFalse(outcome3)
        XCTAssertNil(session.active)
        XCTAssertNil(store.loadActiveRoute())
        XCTAssertTrue(publisher.shown.isEmpty)
        XCTAssertNotNil(session.errorMessage)
    }
    func testFailedEndKeepsDurableTaskAndDoesNotEndItsActivity() async {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        let outcome4 = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(outcome4)
        let failing = CompanionRouteSession(routeStore: store, publisher: publisher,
                                            commit: { throw SaveFailure() })
        await failing.refresh(experiences: [place])
        let outcome5 = await failing.end()
        XCTAssertFalse(outcome5)
        XCTAssertNotNil(store.loadActiveRoute())
        XCTAssertNotNil(failing.active)
        XCTAssertTrue(publisher.ended.isEmpty)
    }
    func testArrivalCompletesOnlyCurrentTaskAndRetainsHistory() async throws {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        let outcome6 = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(outcome6)
        let contextID = try XCTUnwrap(session.active?.contextID)
        let outcome7 = await session.arrived()
        XCTAssertTrue(outcome7)
        XCTAssertNil(session.active)
        XCTAssertNil(store.loadActiveRoute())
        XCTAssertEqual(publisher.ended, [contextID])
        XCTAssertEqual(store.all().count, 1)
    }
    func testStartingAnotherPlaceDoesNotOverwriteExistingActiveTask() async {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        let outcome8 = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(outcome8)
        let firstID = session.active?.contextID
        let other = ExperienceService.hardcodedSeed[1]
        let outcome9 = await session.start(experience: other, cityCode: "cmi")
        XCTAssertFalse(outcome9)
        XCTAssertEqual(session.active?.contextID, firstID)
        XCTAssertEqual(store.all().count, 1)
    }
private final class PausedPublisher: CompanionRoutePublishing {
        var continuation: CheckedContinuation<Void, Never>?
        func show(_ value: CompanionRouteProgress) async -> Bool { true }
        func end(contextID: String) async { await withCheckedContinuation { continuation = $0 } }
        func resume() { continuation?.resume(); continuation = nil }
    }
    func testEndingRouteBlocksNewStartUntilPublisherHasFinished() async throws {
        let (store, _, place) = fixture()
        let publisher = PausedPublisher()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        let started = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(started)
        let ending = Task { await session.end() }
        for _ in 0..<100 where publisher.continuation == nil { await Task.yield() }
        XCTAssertNotNil(publisher.continuation)
        XCTAssertTrue(session.isUpdating)
        let interleaved = await session.start(experience: ExperienceService.hardcodedSeed[1], cityCode: "cmi")
        XCTAssertFalse(interleaved)
        publisher.resume()
        let ended = await ending.value
        XCTAssertTrue(ended)
        let next = await session.start(experience: ExperienceService.hardcodedSeed[1], cityCode: "cmi")
        XCTAssertTrue(next)
        XCTAssertEqual(session.active?.placeID, ExperienceService.hardcodedSeed[1].id)
    }
    func testRouteRevealRemainsPendingUntilViewAcknowledgesIt() async {
        let (store, publisher, place) = fixture()
        let session = CompanionRouteSession(routeStore: store, publisher: publisher)
        session.reveal()
        await session.refresh(experiences: [])
        XCTAssertTrue(session.wantsRoutePresentation)
        _ = await session.start(experience: place, cityCode: "cmi")
        XCTAssertTrue(session.wantsRoutePresentation)
        session.acknowledgeReveal()
        XCTAssertFalse(session.wantsRoutePresentation)
    }
    func testLegacyActivityStateDecodesWithoutContextID() throws {
        let state = SoloCompassActivityState(routeTitle: "Old route")
        let data = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "contextID")
        let decoded = try JSONDecoder().decode(SoloCompassActivityState.self,
                                              from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.contextID)
        XCTAssertEqual(decoded.routeTitle, "Old route")
    }
}
