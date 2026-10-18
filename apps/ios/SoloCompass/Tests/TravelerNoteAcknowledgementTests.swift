import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class TravelerNoteAcknowledgementTests: XCTestCase {
    private enum StorageFailure: Error { case full }

    func testProductionHidesHistoricalFixturesButKeepsRealNotesAndStoredData() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let demo = TravelerNoteStore(context: ModelContext(container), includeDemonstrationContent: true)
        let fixtureCount = demo.notes(for: "x10kup").count
        XCTAssertGreaterThan(fixtureCount, 0)
        let production = TravelerNoteStore(context: ModelContext(container))
        XCTAssertTrue(production.notes(for: "x10kup").isEmpty)
        XCTAssertTrue(production.corrections(for: "x10kup").isEmpty)
        let actual = try XCTUnwrap(production.addNotePersisted(experienceId: "x10kup", text: "My own visit"))
        XCTAssertEqual(production.notes(for: "x10kup").map(\.id), [actual.id])
        XCTAssertEqual(demo.notes(for: "x10kup").count, fixtureCount + 1)
    }

    func testSuccessfulNoteCanBeReadFromAnotherContext() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let store = TravelerNoteStore(context: ModelContext(container))
        let note = try XCTUnwrap(store.addNotePersisted(experienceId: "ack-note", text: "Quiet upstairs"))
        let reader = TravelerNoteStore(context: ModelContext(container))
        XCTAssertEqual(reader.notes(for: "ack-note").map(\.id), [note.id])
    }

    func testFailedInsertThrowsWithoutDiscardingUnrelatedPendingNote() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let pending = TravelerNote(id: "unrelated", experienceId: "pending", authorInitial: "T", authorColor: nil, text: "Keep this edit", kind: .experience, createdAt: "2026-10-16T00:00:00Z", confirms: 0, aiAdopted: false, isMine: true)
        context.insert(TravelerNoteRecord(from: pending))
        let store = TravelerNoteStore(context: context, saveContext: { throw StorageFailure.full })
        XCTAssertThrowsError(try store.addNotePersisted(experienceId: "failed", text: "Keep draft in UI"))
        let staged = try context.fetch(FetchDescriptor<TravelerNoteRecord>())
        XCTAssertEqual(staged.map(\.id), ["unrelated"])
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<TravelerNoteRecord>()).isEmpty)
    }

    func testFailedConfirmationRestoresPreviousCount() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let initial = TravelerNoteStore(context: context)
        let note = try XCTUnwrap(initial.addNotePersisted(experienceId: "confirmation", text: "Original"))
        let failing = TravelerNoteStore(context: context, saveContext: { throw StorageFailure.full })
        XCTAssertFalse(failing.confirmNote(id: note.id))
        XCTAssertEqual(failing.notes(for: "confirmation").first?.confirms, 0)
        XCTAssertEqual(TravelerNoteStore(context: ModelContext(container)).notes(for: "confirmation").first?.confirms, 0)
    }

    func testFailedCorrectionKeepsPendingState() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let initial = TravelerNoteStore(context: context, includeDemonstrationContent: true)
        let correction = try XCTUnwrap(initial.corrections(for: "x10kup").first)
        let failing = TravelerNoteStore(context: context, includeDemonstrationContent: true, saveContext: { throw StorageFailure.full })
        XCTAssertFalse(failing.acceptCorrection(id: correction.id))
        XCTAssertEqual(failing.corrections(for: "x10kup").first?.id, correction.id)
    }
}
