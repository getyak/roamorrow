import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeCommitmentTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("commitment-tests-\(UUID())/v1.json")
    }

    private func request(_ values: [String: Any]) throws -> CompanionHomeFollowUpRequest {
        let data = try JSONSerialization.data(withJSONObject: values)
        return try CompanionHomeFollowUpRequest(argumentsJSON: String(decoding: data, as: UTF8.self))
    }

    func testCommitmentRoundTripAndLifecycleAreIndependentOfMessages() throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let origin = UUID()
        let create = try request(["action": "create", "title": "核对明天的集合地点", "note": "等我确认", "dueAt": "2026-10-24T09:00:00Z"])
        let first = store.manageFollowUp(create, originEntryID: origin)
        XCTAssertTrue(first.success)
        let commitment = try XCTUnwrap(first.commitment)
        XCTAssertEqual(try JSONDecoder().decode(CompanionHomeCommitment.self, from: JSONEncoder().encode(commitment)), commitment)
        let duplicate = store.manageFollowUp(create, originEntryID: origin)
        XCTAssertEqual(duplicate.commitment?.id, commitment.id)
        XCTAssertEqual(store.activeCommitments.count, 1)
        XCTAssertTrue(store.entries.isEmpty)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.activeCommitments, [commitment])
        XCTAssertTrue(restored.completeCommitment(id: commitment.id))
        XCTAssertTrue(restored.activeCommitments.isEmpty)
        XCTAssertEqual(CompanionHomeStore(url: url).commitments.first?.status, .done)
        XCTAssertFalse(restored.cancelCommitment(id: commitment.id))
    }

    func testLegacyV1WithoutCommitmentsLoadsWithoutRecovery() throws {
        let url = location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy: [String: Any] = ["version": 1, "entries": [], "composerDraft": "原草稿", "people": [], "selectedPeopleIDs": [], "invites": []]
        let bytes = try JSONSerialization.data(withJSONObject: legacy)
        try bytes.write(to: url)
        let store = CompanionHomeStore(url: url)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.composerDraft, "原草稿")
        XCTAssertTrue(store.commitments.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testPersistenceFailureRollsBackCreateUpdateCompleteCancel() throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let first = store.manageFollowUp(try request(["action": "create", "title": "已保存事项"]), originEntryID: UUID())
        let id = try XCTUnwrap(first.commitment?.id)
        let original = store.commitments
        let directory = url.deletingLastPathComponent()
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("preserved"))
        try Data("blocker".utf8).write(to: directory)
        XCTAssertFalse(store.manageFollowUp(try request(["action": "create", "title": "不得假保存"]), originEntryID: UUID()).success)
        XCTAssertFalse(store.manageFollowUp(try request(["action": "update", "id": id.uuidString, "note": "新备注"]), originEntryID: UUID()).success)
        XCTAssertFalse(store.completeCommitment(id: id))
        XCTAssertFalse(store.cancelCommitment(id: id))
        XCTAssertEqual(store.commitments, original)
        XCTAssertNotNil(store.errorMessage)
    }

    func testUpdateClearDeadlineCancelAndRejectUnknownID() throws {
        let store = CompanionHomeStore(url: location())
        let first = store.manageFollowUp(try request(["action": "create", "title": "本地事项", "dueAt": "2026-10-24T09:00:00Z"]), originEntryID: UUID())
        let id = try XCTUnwrap(first.commitment?.id)
        XCTAssertTrue(store.manageFollowUp(try request(["action": "update", "id": id.uuidString, "dueAt": NSNull()]), originEntryID: UUID()).success)
        XCTAssertNil(store.commitments[0].dueAt)
        XCTAssertFalse(store.manageFollowUp(try request(["action": "update", "id": UUID().uuidString, "title": "未知ID"]), originEntryID: UUID()).success)
        XCTAssertTrue(store.cancelCommitment(id: id))
        XCTAssertTrue(store.activeCommitments.isEmpty)
        XCTAssertEqual(store.commitments.first?.status, .cancelled)
    }

    func testStrictToolValidationRejectsMalformedOrOversizedArguments() {
        let invalid: [[String: Any]] = [
            ["action": "create"], ["action": "create", "title": " "],
            ["action": "create", "title": String(repeating: "字", count: 161)],
            ["action": "create", "title": "合法标题", "note": String(repeating: "字", count: 2001)],
            ["action": "create", "title": "事项", "dueAt": "tomorrow"],
            ["action": "create", "title": "事项", "surprise": true],
            ["action": "complete", "id": "invalid"],
            ["action": "update", "id": UUID().uuidString],
            ["action": "cancel", "id": UUID().uuidString, "title": "不可暗改"],
            ["action": "create", "title": ["数组不是标题"]]
        ]
        for values in invalid { XCTAssertThrowsError(try request(values)) }
    }
}
