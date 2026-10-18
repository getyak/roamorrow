import XCTest
@testable import SoloCompass

/// Photo-draft batch identity + invalidation (review closure 5). Pure logic —
/// no UIKit images, no file I/O: the guarantees under test are that a retry
/// reuses the same per-image ids and that the explicit-omit receipt can never
/// outlive the batch it was written for.
@MainActor
final class PlacePhotoDraftBatchTests: XCTestCase {

    func testIdsAreStableAcrossRetries() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage()
        batch.appendImage()
        let idsBefore = batch.imageIds
        XCTAssertEqual(idsBefore.count, 2)

        // A failed attempt does not change identity…
        batch.recordAttempt(savedUrls: [], failedIndices: [0, 1])
        XCTAssertEqual(batch.imageIds, idsBefore)

        // …and a retry (no edit) keeps the same ids, so the same output files
        // are overwritten instead of accumulating duplicates.
        batch.recordAttempt(savedUrls: ["file://a.jpg"], failedIndices: [1])
        XCTAssertEqual(batch.imageIds, idsBefore)
    }

    func testStableIdsComeFromInsertTime() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage(id: "id-a")
        batch.appendImage(id: "id-b")
        XCTAssertEqual(batch.imageIds, ["id-a", "id-b"])

        let removed = batch.removeImage(at: 0)
        XCTAssertEqual(removed, "id-a")
        XCTAssertEqual(batch.imageIds, ["id-b"], "remaining ids stay stable after a removal")
    }

    func testRemoveInvalidatesAttemptReceipt() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage(id: "id-a")
        batch.appendImage(id: "id-b")
        batch.recordAttempt(savedUrls: ["file://a.jpg", "file://b.jpg"], failedIndices: [1])
        XCTAssertTrue(batch.isAttemptCurrent)
        XCTAssertEqual(batch.omitCandidateUrls, ["file://a.jpg", "file://b.jpg"])

        batch.removeImage(at: 0)

        XCTAssertFalse(batch.isAttemptCurrent, "editing the batch invalidates the receipt")
        XCTAssertNil(batch.omitCandidateUrls, "omit may never reuse a stale receipt")
    }

    func testAppendInvalidatesAttemptReceipt() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage(id: "id-a")
        batch.recordAttempt(savedUrls: ["file://a.jpg"], failedIndices: [0])

        batch.appendImage(id: "id-b")

        XCTAssertFalse(batch.isAttemptCurrent, "a newly picked photo must not be silently omitted")
        XCTAssertNil(batch.omitCandidateUrls)
    }

    func testClearAttemptIsReturnToEdit() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage(id: "id-a")
        batch.recordAttempt(savedUrls: ["file://a.jpg"], failedIndices: [])

        batch.clearAttempt()

        XCTAssertFalse(batch.isAttemptCurrent)
        XCTAssertNil(batch.lastAttempt)
    }

    func testRecordAttemptCapturesFailedIndicesAndCounts() {
        var batch = PlacePhotoDraftBatch()
        batch.appendImage(id: "id-a")
        batch.appendImage(id: "id-b")
        batch.appendImage(id: "id-c")
        batch.recordAttempt(savedUrls: ["file://a.jpg", "file://c.jpg"], failedIndices: [1])

        XCTAssertEqual(batch.lastAttempt?.failedIndices, [1])
        XCTAssertEqual(batch.lastAttempt?.imageIds, ["id-a", "id-b", "id-c"])
        XCTAssertEqual(batch.omitCandidateUrls?.count, 2)
    }
}
