import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class ChatHistoryDeletionTests: XCTestCase {
    private enum StorageFailure: Error { case full }

    func testDeleteCommitsOnlyTheSelectedConversation() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let store = ChatHistoryStore(context: ModelContext(container))
        for id in ["delete", "keep"] {
            XCTAssertTrue(store.saveSession(id: id, messages: [.init(role: .user, content: id)], scopedExperienceId: nil))
        }
        try store.deletePersisted(sessionId: "delete")
        let reader = ChatHistoryStore(context: ModelContext(container))
        XCTAssertEqual(reader.recentSessions().map(\.id), ["keep"])
        XCTAssertTrue(reader.messages(sessionId: "delete").isEmpty)
        XCTAssertEqual(reader.messages(sessionId: "keep").first?.content, "keep")
    }

    func testFailedDeleteRetainsMessagesAndUnrelatedPendingEdits() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let context = ModelContext(container)
        let original = ChatHistoryStore(context: context)
        XCTAssertTrue(original.saveSession(id: "retain", messages: [.init(role: .user, content: "Retain my history")], scopedExperienceId: nil))
        let unrelated = ChatSessionRecord(id: "pending", scopedExperienceId: nil, title: "Keep pending", createdAt: "2026-10-16T00:00:00Z", updatedAt: "2026-10-16T00:00:00Z", messageCount: 0)
        context.insert(unrelated)
        let failing = ChatHistoryStore(context: context, saveDeletion: { throw StorageFailure.full })
        XCTAssertThrowsError(try failing.deletePersisted(sessionId: "retain"))
        XCTAssertEqual(Set(failing.recentSessions().map(\.id)), Set(["retain", "pending"]))
        XCTAssertEqual(failing.messages(sessionId: "retain").first?.content, "Retain my history")
        let reader = ChatHistoryStore(context: ModelContext(container))
        XCTAssertEqual(reader.recentSessions().map(\.id), ["retain"])
        XCTAssertEqual(reader.messages(sessionId: "retain").first?.content, "Retain my history")
    }
}
