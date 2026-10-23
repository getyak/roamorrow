import XCTest
@testable import SoloCompass

@MainActor
final class CompanionCharacterTests: XCTestCase {
    func testAvatarMotionUsesConversationViewportInsteadOfWholeScreen() {
        let viewport = CGRect(x: 0, y: 120, width: 393, height: 400)
        XCTAssertFalse(CompanionCharacterMotion.isVisible(frame: CGRect(x: 16, y: 60, width: 32, height: 32), viewport: viewport))
        XCTAssertFalse(CompanionCharacterMotion.isVisible(frame: CGRect(x: 16, y: 540, width: 32, height: 32), viewport: viewport))
        XCTAssertTrue(CompanionCharacterMotion.isVisible(frame: CGRect(x: 16, y: 150, width: 32, height: 32), viewport: viewport))
        XCTAssertFalse(CompanionCharacterMotion.isVisible(frame: CGRect(x: 16, y: 150, width: 32, height: 32), viewport: .zero))
    }
    func testSemanticParagraphsKeepOneSentenceAndUnicodeIntact() {
        XCTAssertEqual(CompanionReplyLayout.parts("今天慢一点就好。"), ["今天慢一点就好。"])
        XCTAssertEqual(CompanionReplyLayout.parts("好，先歇一会儿。\n\n找个有窗的位置。\n\n想聊聊今天吗？🌿"),
                       ["好，先歇一会儿。", "找个有窗的位置。", "想聊聊今天吗？🌿"])
        XCTAssertEqual(CompanionReplyLayout.parts("一句话。下一句。"), ["一句话。下一句。"])
        XCTAssertEqual(CompanionReplyLayout.parts(""), [])
    }

    func testStructuredAndLongRepliesAreNotMechanicallyChopped() {
        for text in ["说明\n\n- 第一项\n- 第二项", "```swift\nlet a = 1\n\nprint(a)\n```",
                     "> 原话\n\n> 仍是引用", "标题\n\n| A | B |\n|---|---|", "# 标题\n\n正文",
                     "一\n\n二\n\n三\n\n四", "[详情](https://example.com/a)\n\n说明",
                     "[详情][guide]\n\n[guide]: https://example.com", "    code\n\nexplanation"] {
            XCTAssertEqual(CompanionReplyLayout.parts(text), [text])
        }
        let long = String(repeating: "需要完整解释的内容。", count: 30)
        XCTAssertEqual(CompanionReplyLayout.parts(long), [long])
    }

    func testSoftLineBreaksStayWithinTheSameMeaning() {
        XCTAssertEqual(CompanionReplyLayout.parts("第一行\n接着说\n\n第二个意思"), ["第一行\n接着说", "第二个意思"])
    }

    func testActualWorkFailureRetryAndRestorationAreHonest() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("character-\(UUID())/v1.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CompanionHomeStore(url: url)
        let agent = CharacterPendingAgent()
        store.configure(agent: agent)
        let send = Task { await store.send(text: "帮我想想今晚做什么") }
        while agent.pending.isEmpty { await Task.yield() }
        let id = store.entries[0].id
        XCTAssertEqual(store.activity, .working(id))
        XCTAssertEqual(CompanionHomeStore(url: url).activity, .idle)
        agent.pending.removeFirst().resume(throwing: URLError(.notConnectedToInternet))
        await send.value
        XCTAssertEqual(store.activity, .failed(id))
        let retry = Task { await store.retry(id: id) }
        while agent.pending.isEmpty { await Task.yield() }
        XCTAssertEqual(store.activity, .working(id))
        agent.pending.removeFirst().resume(returning: .init(text: "先吃点东西。\n\n再慢慢走回去。"))
        await retry.value
        XCTAssertEqual(store.activity, .completed(id))
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries[1].replyToID, id)
        XCTAssertEqual(store.entries[1].text, "先吃点东西。\n\n再慢慢走回去。")
        XCTAssertEqual(CompanionHomeStore(url: url).entries, store.entries)
        XCTAssertEqual(CompanionHomeStore(url: url).activity, .idle)
    }

    func testCancelledStaleAttemptCannotAnimateCompletionOfRetry() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("character-\(UUID())/v1.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CompanionHomeStore(url: url)
        let agent = CharacterPendingAgent()
        store.configure(agent: agent)
        let first = Task { await store.send(text: "同一条请求") }
        while agent.pending.isEmpty { await Task.yield() }
        let id = store.entries[0].id
        store.cancel()
        XCTAssertEqual(store.activity, .idle)
        let retry = Task { await store.retry(id: id) }
        while agent.pending.count < 2 { await Task.yield() }
        agent.pending[0].resume(returning: .init(text: "过期结果"))
        await first.value
        XCTAssertEqual(store.activity, .working(id))
        agent.pending[1].resume(returning: .init(text: "这次结果"))
        await retry.value
        XCTAssertEqual(store.activity, .completed(id))
        XCTAssertEqual(store.entries[1].text, "这次结果")
    }

    func testFinalSaveFailureRetriesExistingReplyWithoutRegenerating() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("save-retry-\(UUID())")
        let backup = directory.appendingPathExtension("checkpoint")
        let url = directory.appendingPathComponent("v1.json")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: backup)
        }
        let store = CompanionHomeStore(url: url)
        let agent = CharacterSaveFailureAgent {
            try FileManager.default.moveItem(at: directory, to: backup)
            try Data("unavailable storage".utf8).write(to: directory)
        }
        store.configure(agent: agent)
        await store.send(text: "保留这轮原话与回复")
        let id = try XCTUnwrap(store.entries.first?.id)
        let reply = try XCTUnwrap(store.entries.first(where: { $0.replyToID == id }))
        XCTAssertEqual(store.entries.first?.status, .failed)
        XCTAssertEqual(store.activity, .failed(id))
        XCTAssertNotNil(store.errorMessage)
        await store.retry(id: id) // Still blocked: keep the same response and retry available.
        XCTAssertEqual(agent.calls, 1)
        XCTAssertEqual(store.entries.first?.status, .failed)
        XCTAssertEqual(store.entries.first(where: { $0.replyToID == id }), reply)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        await store.retry(id: id)
        XCTAssertEqual(agent.calls, 1, "Saving an existing reply must not execute the model/tools again")
        XCTAssertEqual(store.entries.first?.status, .delivered)
        XCTAssertEqual(store.entries.first(where: { $0.replyToID == id }), reply)
        XCTAssertEqual(store.activity, .completed(id))
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(CompanionHomeStore(url: url).entries, store.entries)
    }
}

@MainActor
private final class CharacterSaveFailureAgent: CompanionHomeResponding {
    var calls = 0
    let blockStorage: () throws -> Void
    init(blockStorage: @escaping () throws -> Void) { self.blockStorage = blockStorage }
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        calls += 1
        if calls == 1 { try blockStorage() }
        return .init(text: calls == 1 ? "这轮已经收到的原始回复" : "不应重新生成")
    }
}

@MainActor
private final class CharacterPendingAgent: CompanionHomeResponding {
    var pending: [CheckedContinuation<CompanionHomeAgentResult, Error>] = []
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
}
