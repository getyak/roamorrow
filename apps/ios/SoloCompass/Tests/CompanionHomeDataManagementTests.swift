import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeDataManagementTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("companion-data-tests-\(UUID())/v1.json")
    }
    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testExportContainsUnsentDraftAndFullToolJournal() async throws {
        let store = CompanionHomeStore(url: location())
        await store.send(text: "记录原话")
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let call = CompanionHomeToolCheckpoint(id: "persisted-call", name: "manage_follow_up",
            argumentsJSON: #"{"action":"create","title":"待确认事项","note":"未联络对方"}"#)
        XCTAssertTrue(store.checkpointToolPlan(entryID: entryID, batch: .init(calls: [call])))
        XCTAssertNotNil(store.executeFollowUpCheckpoint(entryID: entryID, callID: call.id))
        store.composerDraft = "尚未发送的新草稿"
        let data = try store.exportedSnapshotData()
        let snapshot = try json(data)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\n"))
        XCTAssertEqual(snapshot["composerDraft"] as? String, "尚未发送的新草稿")
        XCTAssertEqual((snapshot["entries"] as? [[String: Any]])?.first?["text"] as? String, "记录原话")
        XCTAssertEqual((snapshot["commitments"] as? [[String: Any]])?.count, 1)
        let journals = try XCTUnwrap(snapshot["toolJournals"] as? [String: [[String: Any]]])
        let calls = try XCTUnwrap(journals[entryID.uuidString]?.first?["calls"] as? [[String: Any]])
        XCTAssertEqual(calls.first?["id"] as? String, call.id)
        XCTAssertNotNil(calls.first?["resultJSON"] as? String)
    }

    func testConfirmedClearOverwritesFutureOriginalAndRecoveryWithoutTouchingSibling() throws {
        let url = location()
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version":999,"preserved":"future data"}"#.utf8).write(to: url)
        let store = CompanionHomeStore(url: url)
        store.composerDraft = "recovery draft"
        let recovery = url.appendingPathExtension("recovery.json")
        let recoveryDraft = recovery.appendingPathExtension("draft.json")
        XCTAssertEqual(try json(Data(contentsOf: recoveryDraft))["text"] as? String, "recovery draft")
        let sibling = url.deletingLastPathComponent().appendingPathComponent("unrelated-user-data.json")
        let untouched = Data("unrelated data".utf8)
        try untouched.write(to: sibling)
        XCTAssertTrue(store.clearLocalData())
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.composerDraft.isEmpty)
        XCTAssertNil(store.errorMessage)
        for known in [url, recovery] {
            let snapshot = try json(Data(contentsOf: known))
            XCTAssertEqual(snapshot["version"] as? Int, 1)
            XCTAssertEqual(snapshot["composerDraft"] as? String, "")
            XCTAssertTrue((snapshot["entries"] as? [Any])?.isEmpty == true)
            XCTAssertTrue((snapshot["toolJournals"] as? [String: Any])?.isEmpty == true)
        }
        XCTAssertEqual(try Data(contentsOf: sibling), untouched)
        let restored = CompanionHomeStore(url: url)
        XCTAssertNil(restored.errorMessage)
        XCTAssertTrue(restored.composerDraft.isEmpty)
        XCTAssertTrue(restored.commitments.isEmpty)
    }

    func testBothCorruptFilesCanBeExplicitlyCleared() throws {
        let url = location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("broken original".utf8).write(to: url)
        try Data("broken recovery".utf8).write(to: url.appendingPathExtension("recovery.json"))
        let store = CompanionHomeStore(url: url)
        store.composerDraft = "unsaved draft"
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.clearLocalData())
        XCTAssertEqual(try json(Data(contentsOf: url))["composerDraft"] as? String, "")
        XCTAssertTrue(CompanionHomeStore(url: url).composerDraft.isEmpty)
    }

    func testFailedClearPreservesRecordsAndExportableDraft() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "应保留的原话")
        store.composerDraft = "应保留的草稿"
        let originalEntries = store.entries
        let directory = url.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("preserved")
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("blocked directory".utf8).write(to: directory)
        XCTAssertFalse(store.clearLocalData())
        XCTAssertEqual(store.entries, originalEntries)
        XCTAssertEqual(store.composerDraft, "应保留的草稿")
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try json(store.exportedSnapshotData())["composerDraft"] as? String, "应保留的草稿")
        XCTAssertEqual(CompanionHomeStore(url: backup.appendingPathComponent("v1.json")).entries, originalEntries)
    }

    func testSecondFileFailureRollsBackFirstFile() async throws {
        let url = location()
        let manager = FileManager.default
        let store = CompanionHomeStore(url: url)
        await store.send(text: "不能部分清空")
        store.composerDraft = "应恢复的草稿"
        let expectedEntries = store.entries
        let recovery = url.appendingPathExtension("recovery.json")
        let oldRecovery = Data("recovery original bytes".utf8)
        try oldRecovery.write(to: recovery)
        do { try manager.setAttributes([.immutable: true], ofItemAtPath: recovery.path) }
        catch { throw XCTSkip("Filesystem does not support this owned temporary file's immutable flag") }
        defer { try? manager.setAttributes([.immutable: false], ofItemAtPath: recovery.path) }
        XCTAssertFalse(store.clearLocalData())
        XCTAssertEqual(store.entries, expectedEntries)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries, expectedEntries)
        XCTAssertEqual(restored.composerDraft, "应恢复的草稿")
        XCTAssertEqual(try Data(contentsOf: recovery), oldRecovery)
    }

    func testLateResponseAfterClearDoesNotReviveMemoryOrDisk() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = CompanionDataSuspendingAgent()
        store.configure(agent: agent)
        let sending = Task { await store.send(text: "正在处理的原话") }
        while agent.resume == nil { await Task.yield() }
        XCTAssertTrue(store.isWorking)
        XCTAssertTrue(store.clearLocalData())
        agent.resume?.resume(returning: .init(text: "迟到的结果"))
        await sending.value
        XCTAssertFalse(store.isWorking)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(CompanionHomeStore(url: url).entries.isEmpty)
    }
}

@MainActor
private final class CompanionDataSuspendingAgent: CompanionHomeResponding {
    var resume: CheckedContinuation<CompanionHomeAgentResult, Error>?
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        try await withCheckedThrowingContinuation { resume = $0 }
    }
}
