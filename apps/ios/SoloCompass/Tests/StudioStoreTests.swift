import XCTest
#if canImport(SoloCompass)
@testable import SoloCompass
#else
@testable import LifeStudioPreview
#endif

@MainActor final class StudioStoreTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("composition.json")
    }

    func testEditPreservesOtherObjectsAndRoundTrips() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StudioStore(url: url)
        let first = StudioPiece(kind: .book, title: "One")
        var second = StudioPiece(kind: .photo, title: "Two")
        second.original = Data([1, 2, 3])
        XCTAssertTrue(store.change { $0.pieces = [first, second] })
        store.move(first.id, x: 0.7, y: 0.2)
        XCTAssertEqual(store.document.pieces[1], second)
        let reopened = StudioStore(url: url)
        XCTAssertEqual(reopened.document, store.document)
        XCTAssertEqual(reopened.document.pieces[0].id, first.id)
    }

    func testDeleteUndoAndUnsuccessfulSaveDoNotLoseState() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StudioStore(url: url)
        let piece = StudioPiece(kind: .note, title: "Keep me")
        store.change { $0.pieces = [piece] }
        store.change { $0.pieces = [] }
        store.undo()
        XCTAssertEqual(store.document.pieces, [piece])
        XCTAssertEqual(StudioStore(url: url).document.pieces, [piece])
        // Replace the storage parent with a file to make the next save fail deterministically.
        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
        try Data().write(to: url.deletingLastPathComponent())
        XCTAssertFalse(store.change { $0.title = "Unsaved" })
        XCTAssertEqual(store.document.title, "")
        XCTAssertNotNil(store.error)
    }

    func testUnreadableDocumentIsNeverOverwritten() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("not-json".utf8)
        try original.write(to: url)
        let store = StudioStore(url: url)
        XCTAssertFalse(store.isReadable)
        XCTAssertFalse(store.change { $0.title = "Should not save" })
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnknownVersionIsPreservedAndMissingObjectMoveIsNoOp() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StudioStore(url: url)
        store.move(UUID(), x: 0.3, y: 0.7)
        XCTAssertTrue(store.history.isEmpty)
        var future = StudioDocument(); future.version = 2
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(future)
        try data.write(to: url)
        let reopened = StudioStore(url: url)
        XCTAssertFalse(reopened.isReadable)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
