import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeV4ContinuityTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("home-v4-\(UUID())/v1.json")
    }

    func testAcceptedPlaceQuestionPersistsScopeOnceWithoutChangingUserWords() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = V4ScopeRecordingAgent()
        store.configure(agent: agent)
        let place = ExperienceService.hardcodedSeed[0]
        store.composerDraft = "  这里安静吗？  "
        XCTAssertTrue(store.setNextTurnExperience(place))
        await store.send()
        let first = try XCTUnwrap(store.entries.first(where: { $0.role == .user }))
        XCTAssertEqual(first.text, "  这里安静吗？  ")
        XCTAssertEqual(first.placeScope?.experienceID, place.id)
        XCTAssertNil(first.searchArea)
        XCTAssertNil(store.nextTurnPlace)
        XCTAssertEqual(agent.inputs.first?.last?.placeScope?.experienceID, place.id)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries.first?.placeScope, first.placeScope)
        XCTAssertNil(restored.nextTurnPlace)
        await store.send(text: "今天先这样")
        XCTAssertNil(agent.inputs.last?.last?.placeScope)
        XCTAssertEqual(store.entries.first?.placeScope, first.placeScope)
    }

    func testRejectedEmptyAndBusySendsKeepNextScopeAndDraft() async {
        let store = CompanionHomeStore(url: location())
        let place = ExperienceService.hardcodedSeed[0]
        XCTAssertTrue(store.setNextTurnExperience(place))
        await store.send()
        XCTAssertEqual(store.nextTurnPlace?.experienceID, place.id)
        let agent = V4SuspendingScopeAgent()
        store.configure(agent: agent)
        let sending = Task { await store.send(text: "第一个问题") }
        while agent.pending.isEmpty { await Task.yield() }
        XCTAssertTrue(store.setNextTurnExperience(place))
        store.composerDraft = "稍后关于这里的问题"
        await store.send()
        XCTAssertEqual(store.composerDraft, "稍后关于这里的问题")
        XCTAssertEqual(store.nextTurnPlace?.experienceID, place.id)
        agent.pending[0].resume(returning: .init(text: "第一个回答"))
        await sending.value
        XCTAssertEqual(store.nextTurnPlace?.experienceID, place.id)
        XCTAssertEqual(store.composerDraft, "稍后关于这里的问题")
    }

    func testStorageRejectedSendKeepsPendingPlaceAndOriginalMedia() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        store.composerDraft = "保留原草稿"
        XCTAssertTrue(store.setNextTurnExperience(ExperienceService.hardcodedSeed[0]))
        let attachment = CompanionMediaAttachment(kind: .file, name: "notes.txt", mimeType: "text/plain", data: Data([1]))
        XCTAssertTrue(store.stageAttachment(attachment))
        let directory = url.deletingLastPathComponent()
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("saved"))
        try Data("blocked".utf8).write(to: directory)
        await store.send()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.composerDraft, "保留原草稿")
        XCTAssertEqual(store.draftAttachments, [attachment])
        XCTAssertNotNil(store.nextTurnPlace)
    }

    func testAreaQuestionFreezesQueryAndViewportAndIsExclusiveWithPlace() async throws {
        let store = CompanionHomeStore(url: location())
        store.configure(agent: V4ScopeRecordingAgent())
        XCTAssertTrue(store.setNextTurnExperience(ExperienceService.hardcodedSeed[0]))
        let area = CompanionHomeSearchArea(name: "上野周边", latitude: 35.714, longitude: 139.774, cityCode: "TYO")
        XCTAssertTrue(store.setNextTurnArea(area, query: "书店", category: "culture", experienceIDs: ["book", "book"], latitudeDelta: 0.02, longitudeDelta: 0.03))
        XCTAssertNil(store.nextTurnPlace)
        await store.send(text: "看看这片区域")
        let question = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(question.searchArea?.area, area)
        XCTAssertEqual(question.searchArea?.query, "书店")
        XCTAssertEqual(question.searchArea?.experienceIDs, ["book"])
        XCTAssertEqual(question.searchArea?.latitudeDelta, 0.02)
        XCTAssertNil(question.placeScope)
        XCTAssertNil(store.nextTurnArea)
        XCTAssertTrue(store.setNextTurnArea(.init(name: "京都", latitude: 35.01, longitude: 135.76)))
        XCTAssertEqual(store.entries.first?.searchArea, question.searchArea)
        XCTAssertTrue(store.clearNextTurnScope())
        XCTAssertNil(store.nextTurnPlace)
        XCTAssertNil(store.nextTurnArea)
    }

    func testMapReturnUsesStableEntryAndPreservesCurrentDraftAndReading() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = V4ScopeRecordingAgent()
        agent.result = .init(text: "两处地点", placeID: "park", placeIDs: ["park", "lane"])
        store.configure(agent: agent)
        await store.send(text: "安静的地方")
        let reply = try XCTUnwrap(store.entries.first(where: { $0.role == .companion }))
        let anchor = "message:\(reply.id)"
        store.noteReadingPosition(anchorID: anchor, followsLatest: false, hasUnread: false)
        store.composerDraft = "原来的草稿"
        XCTAssertTrue(store.captureMapSource(messageID: reply.id, experienceIDs: ["park", "lane", "unrelated"]))
        XCTAssertEqual(store.mapSource?.experienceIDs, ["park", "lane"])
        store.composerDraft = "在别处更新过的草稿"
        XCTAssertTrue(store.restoreMapSource())
        XCTAssertEqual(store.composerDraft, "在别处更新过的草稿")
        XCTAssertEqual(store.readingState.anchorID, anchor)
        XCTAssertFalse(store.readingState.followsLatest)
        XCTAssertEqual(store.entries.first(where: { $0.id == reply.id }), reply)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.conversationID, store.conversationID)
        XCTAssertEqual(restored.mapSource, store.mapSource)
        XCTAssertEqual(restored.composerDraft, "在别处更新过的草稿")
    }

    func testResponseWhileReadingHistoryPersistsUnreadAndExplicitSendResetsIt() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let agent = V4SuspendingScopeAgent()
        store.configure(agent: agent)
        let sending = Task { await store.send(text: "等待回复") }
        while agent.pending.isEmpty { await Task.yield() }
        let user = try XCTUnwrap(store.entries.first)
        let anchor = "message:\(user.id)"
        store.noteReadingPosition(anchorID: anchor, followsLatest: false, hasUnread: false)
        agent.pending[0].resume(returning: .init(text: "回复到了"))
        await sending.value
        XCTAssertEqual(store.readingState.anchorID, anchor)
        XCTAssertFalse(store.readingState.followsLatest)
        XCTAssertTrue(store.readingState.hasUnread)
        // No SwiftUI callback participates: the completed response's own save
        // must contain the reading position and unread state after a restart.
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.readingState.anchorID, anchor)
        XCTAssertFalse(restored.readingState.followsLatest)
        XCTAssertTrue(restored.readingState.hasUnread)
        restored.configure(agent: V4ScopeRecordingAgent())
        await restored.send(text: "接着问下一句")
        let afterSend = CompanionHomeStore(url: url)
        XCTAssertEqual(afterSend.readingState.anchorID, "stream-bottom")
        XCTAssertTrue(afterSend.readingState.followsLatest)
        XCTAssertFalse(afterSend.readingState.hasUnread)
    }

    func testClearLocalDataInvalidatesSourceScopeAndRestoredReadingIdentity() async throws {
        let store = CompanionHomeStore(url: location())
        store.configure(agent: V4ScopeRecordingAgent())
        await store.send(text: "一条原话")
        let id = try XCTUnwrap(store.entries.first?.id)
        XCTAssertTrue(store.captureMapSource(messageID: id, experienceIDs: []))
        XCTAssertTrue(store.setNextTurnExperience(ExperienceService.hardcodedSeed[0]))
        let conversationID = store.conversationID
        XCTAssertTrue(store.clearLocalData())
        XCTAssertNotEqual(store.conversationID, conversationID)
        XCTAssertNil(store.nextTurnPlace)
        XCTAssertNil(store.mapSource)
        XCTAssertFalse(store.restoreMapSource())
        XCTAssertEqual(store.readingState.anchorID, "stream-bottom")
    }

    func testInvalidReadingAnchorAndPlaceScopeDoNotGetRestoredAsFacts() throws {
        let url = location()
        let payload = #"{"version":1,"entries":[],"composerDraft":"old draft","people":[],"selectedPeopleIDs":[],"invites":[],"nextTurnPlace":{"experienceID":"","name":"bad","cityCode":"TYO"},"readingState":{"anchorID":"message:missing","followsLatest":false,"hasUnread":false}}"#
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(payload.utf8).write(to: url)
        let store = CompanionHomeStore(url: url)
        XCTAssertEqual(store.composerDraft, "old draft")
        XCTAssertNil(store.nextTurnPlace)
        XCTAssertEqual(store.readingState.anchorID, "stream-bottom")
    }
}

@MainActor
private final class V4ScopeRecordingAgent: CompanionHomeResponding {
    var inputs: [[CompanionHomeEntry]] = []
    var result = CompanionHomeAgentResult(text: "已收到")
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        inputs.append(entries)
        return result
    }
}

@MainActor
private final class V4SuspendingScopeAgent: CompanionHomeResponding {
    var pending: [CheckedContinuation<CompanionHomeAgentResult, Error>] = []
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
}
