import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class ChatHistoryDeletionTests: XCTestCase {
    private enum StorageFailure: Error { case full }

    private func isolate(_ store: ChatHistoryStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("history-delete-\(UUID().uuidString)")
        store.recoveryJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("journal.json"))
        store.recoveryMemory = DeviceAgentMemoryStore(fileURL: root.appendingPathComponent("memory.json"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    }

    private func reuseRecoverySources(from source: ChatHistoryStore, in target: ChatHistoryStore) {
        target.recoveryJournal = source.recoveryJournal
        target.recoveryMemory = source.recoveryMemory
    }

    func testDeleteCommitsOnlyTheSelectedConversation() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let store = ChatHistoryStore(context: ModelContext(container))
        isolate(store)
        for id in ["delete", "keep"] {
            XCTAssertTrue(store.saveSession(id: id, messages: [.init(role: .user, content: id)], scopedExperienceId: nil))
        }
        try store.deletePersisted(sessionId: "delete")
        let reader = ChatHistoryStore(context: ModelContext(container))
        reuseRecoverySources(from: store, in: reader)
        XCTAssertEqual(reader.recentSessions().map(\.id), ["keep"])
        XCTAssertTrue(reader.messages(sessionId: "delete").isEmpty)
        XCTAssertEqual(reader.messages(sessionId: "keep").first?.content, "keep")
        XCTAssertFalse(store.saveSession(id: "delete", messages: [.init(role: .user, content: "Late reply")], scopedExperienceId: nil))
    }

    func testDeleteWithNoRowsStillRejectsLateSave() throws {
        let store = ChatHistoryStore(context: ModelContext(SoloCompassModelContainer.makeInMemory()))
        isolate(store)
        try store.deletePersisted(sessionId: "not-yet-saved")
        XCTAssertTrue(store.recoveryJournal.isForgotten(sessionID: "not-yet-saved"))
        XCTAssertFalse(store.saveSession(id: "not-yet-saved", messages: [
            .init(role: .user, content: "A suspended turn")
        ], scopedExperienceId: nil))
    }

    @MainActor
    private final class RefusingMemoryDeletion: AgentMemoryProviding {
        let base: any AgentMemoryProviding
        init(base: any AgentMemoryProviding) { self.base = base }
        func context(for session: AgentSessionDescriptor) -> AgentMemoryContext { base.context(for: session) }
        func recordCompletedTurn(_ turn: AgentCompletedTurn) -> Bool { base.recordCompletedTurn(turn) }
        func recall(query: String, scope: String, limit: Int, cityCode: String?) -> [AgentMemoryRecall] {
            base.recall(query: query, scope: scope, limit: limit, cityCode: cityCode)
        }
        func forget(sessionID: String) -> Bool { false }
        func forgetAll() -> Bool { base.forgetAll() }
    }

    func testFailedMemoryCleanupKeepsHistoryVisibleForRetryAndBlocksLateWrites() throws {
        let store = ChatHistoryStore(context: ModelContext(SoloCompassModelContainer.makeInMemory()))
        isolate(store)
        let user = VoiceAgentSession.Message(role: .user, content: "Keep a visible retry")
        let answer = VoiceAgentSession.Message(role: .assistant, content: "Saved evidence")
        XCTAssertTrue(store.saveSession(id: "retry-delete", messages: [user, answer], scopedExperienceId: nil))
        let memory = store.recoveryMemory
        let descriptor = AgentSessionDescriptor(id: "retry-delete", scope: "global")
        let epoch = memory.context(for: descriptor).epoch
        XCTAssertTrue(memory.recordCompletedTurn(.init(
            identity: .init(session: descriptor, turnID: user.id), userText: "Keep a visible retry",
            assistantText: "Saved evidence", memoryEpoch: epoch
        )))
        store.recoveryMemory = RefusingMemoryDeletion(base: memory)
        XCTAssertThrowsError(try store.deletePersisted(sessionId: descriptor.id))
        XCTAssertEqual(store.messages(sessionId: descriptor.id), [user, answer])
        XCTAssertTrue(store.recentSessions().contains(where: { $0.id == descriptor.id }))
        XCTAssertEqual(memory.context(for: descriptor).records.count, 1)
        XCTAssertTrue(store.recoveryJournal.isForgotten(sessionID: descriptor.id))
        XCTAssertFalse(store.saveSession(id: descriptor.id, messages: [user, answer,
            .init(role: .assistant, content: "Late result")
        ], scopedExperienceId: nil))
        store.recoveryMemory = memory
        try store.deletePersisted(sessionId: descriptor.id)
        XCTAssertTrue(store.messages(sessionId: descriptor.id).isEmpty)
        XCTAssertFalse(store.recentSessions().contains(where: { $0.id == descriptor.id }))
        XCTAssertTrue(memory.context(for: descriptor).records.isEmpty)
    }

    func testFailedDeleteRetainsMessagesAndUnrelatedPendingEdits() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let original = ChatHistoryStore(context: context)
        isolate(original)
        XCTAssertTrue(original.saveSession(id: "retain", messages: [.init(role: .user, content: "Retain my history")], scopedExperienceId: nil))
        let unrelated = ChatSessionRecord(id: "pending", scopedExperienceId: nil, title: "Keep pending", createdAt: "2026-10-16T00:00:00Z", updatedAt: "2026-10-16T00:00:00Z", messageCount: 0)
        context.insert(unrelated)
        let failing = ChatHistoryStore(context: context, saveDeletion: { throw StorageFailure.full })
        reuseRecoverySources(from: original, in: failing)
        XCTAssertThrowsError(try failing.deletePersisted(sessionId: "retain"))
        XCTAssertEqual(Set(failing.recentSessions().map(\.id)), Set(["retain", "pending"]))
        XCTAssertEqual(failing.messages(sessionId: "retain").first?.content, "Retain my history")
        let reader = ChatHistoryStore(context: ModelContext(container))
        reuseRecoverySources(from: original, in: reader)
        XCTAssertEqual(reader.recentSessions().map(\.id), ["retain"])
        XCTAssertEqual(reader.messages(sessionId: "retain").first?.content, "Retain my history")
    }
}
