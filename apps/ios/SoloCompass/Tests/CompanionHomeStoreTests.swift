import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeStoreTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("companion-tests-\(UUID().uuidString)/v1.json")
    }

    func testStorageFailureRollsBackSubmissionInviteAndPeople() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let person = CompanionHomePerson(id: "local-person", name: "本人填写")
        XCTAssertTrue(store.updatePeople([person]))
        XCTAssertTrue(store.selectPeople([person.id]))
        store.composerDraft = "尚未保存的原话"
        // Preserve the previously saved directory and replace only this test's path
        // with a regular file, making subsequent atomic writes deterministically fail.
        let directory = url.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("storage unavailable".utf8).write(to: directory)
        await store.send()
        await store.send()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.composerDraft, "尚未保存的原话")
        XCTAssertNotNil(store.errorMessage)
        let invite = CompanionHomeInvite(placeID: "record", placeName: "地点", date: Date(),
                                         durationMinutes: 30, people: [person], note: "草稿")
        let saved = await store.saveInvite(invite)
        XCTAssertFalse(saved)
        XCTAssertTrue(store.invites.isEmpty)
        XCTAssertFalse(store.selectPeople([]))
        XCTAssertEqual(store.selectedPeopleIDs, [person.id])
        XCTAssertFalse(store.updatePeople([], selectedIDs: []))
        XCTAssertEqual(store.people, [person])
        XCTAssertEqual(store.selectedPeopleIDs, [person.id])
        store.people = []
        XCTAssertEqual(store.people, [person])
    }

    func testPeopleAndSelectionArePersistedTogether() {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let person = CompanionHomePerson(id: "local-person", name: "本人填写")
        XCTAssertTrue(store.updatePeople([person], selectedIDs: [person.id]))
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.people, [person])
        XCTAssertEqual(restored.selectedPeopleIDs, [person.id])
    }

    func testFailureRetryPreservesOriginalAndStableID() async {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = CompanionTestAgent()
        store.configure(agent: agent)
        store.composerDraft = "  保留我的原话  "
        await store.send()
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.text, "  保留我的原话  ")
        XCTAssertEqual(store.entries.first?.status, .failed)
        let id = store.entries[0].id
        agent.shouldFail = false
        await store.retry(id: id)
        await store.retry(id: id)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries[0].id, id)
        XCTAssertEqual(store.entries[1].replyToID, id)
        XCTAssertEqual(agent.calls, 2)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries, store.entries)
    }

    func testCorruptionPreservesBytesAndRecoversNewDraftOnNextLaunch() throws {
        let url = location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let broken = Data("broken original".utf8)
        try broken.write(to: url)
        let store = CompanionHomeStore(url: url)
        XCTAssertNotNil(store.errorMessage)
        store.composerDraft = "新草稿"
        XCTAssertEqual(try Data(contentsOf: url), broken)
        XCTAssertEqual(CompanionHomeStore(url: url).composerDraft, "新草稿")
    }

    func testInviteAlwaysRemainsUnsentDraft() async {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let invite = CompanionHomeInvite(placeID: "real-record", placeName: "本机地点", date: Date(),
                                         durationMinutes: 45, people: [], note: "一起散步", status: .confirmed)
        await store.saveInvite(invite)
        await store.saveInvite(invite)
        XCTAssertEqual(store.invites.count, 1)
        XCTAssertEqual(store.invites.first?.status, .draft)
        XCTAssertEqual(CompanionHomeStore(url: url).invites.first?.status, .draft)
        store.selectPeople(["unknown-person"])
        XCTAssertTrue(store.selectedPeopleIDs.isEmpty)
    }

    func testCancelledAttemptCannotCompleteItsRetry() async {
        let store = CompanionHomeStore(url: location())
        let agent = CompanionSuspendingTestAgent()
        store.configure(agent: agent)
        let first = Task { await store.send(text: "同一条原话") }
        while agent.pending.count < 1 { await Task.yield() }
        let id = store.entries[0].id
        store.cancel()
        let retry = Task { await store.retry(id: id) }
        while agent.pending.count < 2 { await Task.yield() }
        agent.pending[0].resume(returning: .init(text: "旧结果"))
        await first.value
        XCTAssertTrue(store.isWorking)
        XCTAssertEqual(store.entries.count, 1)
        agent.pending[1].resume(returning: .init(text: "重试结果"))
        await retry.value
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries[1].text, "重试结果")
    }

    func testInputTypedDuringRequestSurvivesCompletion() async {
        let store = CompanionHomeStore(url: location())
        let agent = CompanionTestAgent()
        agent.shouldFail = false
        agent.onResponse = { store.composerDraft = "下一句话" }
        store.configure(agent: agent)
        store.composerDraft = "第一句话"
        await store.send()
        XCTAssertEqual(store.composerDraft, "下一句话")
    }
}

@MainActor
private final class CompanionTestAgent: CompanionHomeResponding {
    var shouldFail = true
    var calls = 0
    var onResponse: (() -> Void)?
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        calls += 1
        onResponse?()
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return .init(text: "已收到", sourceTitles: ["测试来源"])
    }
}

@MainActor
private final class CompanionSuspendingTestAgent: CompanionHomeResponding {
    var pending: [CheckedContinuation<CompanionHomeAgentResult, Error>] = []
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
}
