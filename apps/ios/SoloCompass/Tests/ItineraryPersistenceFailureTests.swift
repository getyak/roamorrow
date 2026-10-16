import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class ItineraryPersistenceFailureTests: XCTestCase {
    private enum StorageFailure: Error { case full }
    private func itinerary(_ id: String = "saved", title: String = "Original") -> Itinerary {
        Itinerary(id: .init(rawValue: id), ownerId: "test", title: title, cityCode: "TYO", startDate: "2026-10-16", endDate: "2026-10-17", experienceIds: [], openToCompanions: false, createdAt: "2026-10-16T00:00:00Z", updatedAt: "2026-10-16T00:00:00Z")
    }
    func testFailedInsertRemovesOnlyItsOwnPendingRow() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        context.insert(ItineraryRecord(from: itinerary("unrelated")))
        let failing = ItineraryStore(context: context, saveContext: { throw StorageFailure.full })
        XCTAssertThrowsError(try failing.save(itinerary("failed")))
        XCTAssertEqual(failing.loadAll().map(\.id.rawValue), ["unrelated"])
        XCTAssertTrue(ItineraryStore(context: ModelContext(container)).loadAll().isEmpty)
    }
    func testFailedDeleteRetainsSavedItineraryAndRetryWorks() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let original = ItineraryStore(context: context)
        try original.save(itinerary())
        let failing = ItineraryStore(context: context, saveContext: { throw StorageFailure.full })
        XCTAssertThrowsError(try failing.delete(id: .init(rawValue: "saved")))
        XCTAssertEqual(failing.load(id: .init(rawValue: "saved"))?.title, "Original")
        XCTAssertEqual(ItineraryStore(context: ModelContext(container)).loadAll().count, 1)
        try original.delete(id: .init(rawValue: "saved"))
        XCTAssertTrue(ItineraryStore(context: ModelContext(container)).loadAll().isEmpty)
    }
    func testFailedReplacementKeepsOriginalAndNoDuplicateStops() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let original = ItineraryStore(context: context)
        try original.save(itinerary())
        let failing = ItineraryStore(context: context, saveContext: { throw StorageFailure.full })
        XCTAssertThrowsError(try failing.save(itinerary(title: "Changed")))
        XCTAssertEqual(failing.loadAll().map(\.title), ["Original"])
        _ = try original.addExperiences(["a", "a", "b"], to: .init(rawValue: "saved"))
        XCTAssertEqual(original.load(id: .init(rawValue: "saved"))?.experienceIds, ["a", "b"])
    }
}
