import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeInviteTimelineTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("invite-time-tests-\(UUID())/v1.json")
    }
    private func invite() -> CompanionHomeInvite {
        .init(placeID: "place", placeName: "地点", date: Date().addingTimeInterval(86_400 * 30),
              durationMinutes: 60, people: [], note: "未发送")
    }

    func testCreationTimeIsSaveTimeNotFutureMeetingTimeAndSurvivesEditing() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        var draft = invite()
        draft.createdAt = Date(timeIntervalSince1970: 1)
        let before = Date()
        let saved = await store.saveInvite(draft)
        XCTAssertTrue(saved)
        let createdAt = try XCTUnwrap(store.invites.first?.createdAt)
        XCTAssertGreaterThanOrEqual(createdAt, before)
        XCTAssertLessThanOrEqual(createdAt, Date())
        XCTAssertLessThan(createdAt, draft.date)
        draft.createdAt = draft.date
        draft.note = "修改备注"
        let edited = await store.saveInvite(draft)
        XCTAssertTrue(edited)
        XCTAssertEqual(store.invites.first?.createdAt, createdAt)
        XCTAssertEqual(CompanionHomeStore(url: url).invites.first?.createdAt, createdAt)
    }

    func testLegacyMissingCreationTimeRemainsNilWhenEdited() async throws {
        let url = location()
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var oldInvite = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(invite())) as? [String: Any])
        oldInvite.removeValue(forKey: "createdAt")
        let snapshot: [String: Any] = ["version": 1, "entries": [], "composerDraft": "", "people": [], "selectedPeopleIDs": [], "invites": [oldInvite]]
        try JSONSerialization.data(withJSONObject: snapshot).write(to: url)
        let store = CompanionHomeStore(url: url)
        XCTAssertNil(store.errorMessage)
        var restored = try XCTUnwrap(store.invites.first)
        XCTAssertNil(restored.createdAt)
        restored.createdAt = Date()
        restored.note = "编辑旧记录"
        let success = await store.saveInvite(restored)
        XCTAssertTrue(success)
        XCTAssertNil(store.invites.first?.createdAt)
        XCTAssertNil(CompanionHomeStore(url: url).invites.first?.createdAt)
    }

    func testFailedSaveRollsBackCreationTimeAndContents() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let first = await store.saveInvite(invite())
        XCTAssertTrue(first)
        let original = store.invites
        let directory = url.deletingLastPathComponent()
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("preserved"))
        try Data("blocked".utf8).write(to: directory)
        var edited = original[0]
        edited.note = "不得保存"
        edited.createdAt = Date(timeIntervalSince1970: 1)
        let failed = await store.saveInvite(edited)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.invites, original)
        let failedNew = await store.saveInvite(invite())
        XCTAssertFalse(failedNew)
        XCTAssertEqual(store.invites, original)
    }
}
