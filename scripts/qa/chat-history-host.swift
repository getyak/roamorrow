import Foundation
import SwiftData

// The host check uses the real store, models, journal and memory. Only the
// app-wide container bootstrap is excluded because it references every iOS model.
// Each scenario constructs a real SwiftData ModelContainer with the chat schema.
@MainActor enum SoloCompassModelContainer {
    static var shared: ModelContainer { fatalError("Production singleton must not be used by host check") }
}

@main struct HistoryDeleteCheck {
    enum Failure: Error { case full }
    @MainActor static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { print("FAIL: \(message)"); exit(1) }
    }
    @MainActor static func checkSnapshotRollback() throws {
        let container = try ModelContainer(for: ChatSessionRecord.self, ChatMessageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chat-snapshot-host-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = FileAgentExecutionJournal(url: root.appendingPathComponent("journal.json"))
        let memory = DeviceAgentMemoryStore(fileURL: root.appendingPathComponent("memory.json"))
        let store = ChatHistoryStore(context: context)
        store.recoveryJournal = journal
        store.recoveryMemory = memory
        let messages: [VoiceAgentSession.Message] = [
            .init(role: .user, content: "Original"), .init(role: .assistant, content: "Keep the reply")
        ]
        require(store.saveSession(id: "shrink", messages: messages, scopedExperienceId: nil), "initial two-message save")
        context.insert(ChatSessionRecord(id: "pending", scopedExperienceId: nil, title: "Pending",
                                         createdAt: "old", updatedAt: "old", messageCount: 0))
        let failing = ChatHistoryStore(context: context, saveSnapshot: { throw Failure.full })
        failing.recoveryJournal = journal
        failing.recoveryMemory = memory
        require(!failing.saveSession(id: "shrink", messages: [messages[0]], scopedExperienceId: nil), "snapshot failure must surface")
        require(failing.messages(sessionId: "shrink") == messages, "failed shrink lost a trailing message in caller context")
        require(Set(failing.recentSessions().map(\.id)) == ["shrink", "pending"], "failed shrink changed unrelated pending edit")
        let reader = ChatHistoryStore(context: ModelContext(container))
        require(reader.messages(sessionId: "shrink") == messages, "failed shrink changed durable messages")
        require(reader.recentSessions().map(\.id) == ["shrink"], "failed shrink flushed unrelated edit")
        try context.save()
        let afterCallerSave = ChatHistoryStore(context: ModelContext(container))
        require(afterCallerSave.messages(sessionId: "shrink") == messages, "later caller save lost restored trailing message")
        require(Set(afterCallerSave.recentSessions().map(\.id)) == ["shrink", "pending"], "later caller save lost unrelated edit")
    }

    @MainActor static func main() throws {
        try checkSnapshotRollback()
        let container = try ModelContainer(for: ChatSessionRecord.self, ChatMessageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-history-host-state-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = FileAgentExecutionJournal(url: root.appendingPathComponent("journal.json"))
        let memory = DeviceAgentMemoryStore(fileURL: root.appendingPathComponent("memory.json"))
        let original = ChatHistoryStore(context: context)
        original.recoveryJournal = journal
        original.recoveryMemory = memory
        require(original.saveSession(id: "retain", messages: [.init(role: .user, content: "Retain my history")], scopedExperienceId: nil), "initial history save")
        let pending = ChatSessionRecord(id: "pending", scopedExperienceId: nil, title: "Keep pending", createdAt: "old", updatedAt: "old", messageCount: 0)
        context.insert(pending)
        let failing = ChatHistoryStore(context: context, saveDeletion: { throw Failure.full })
        failing.recoveryJournal = journal
        failing.recoveryMemory = memory
        do { try failing.deletePersisted(sessionId: "retain"); require(false, "delete should throw") } catch Failure.full {}
        require(Set(failing.recentSessions().map(\.id)) == Set(["retain", "pending"]), "failed deletion lost a row in original context")
        require(failing.messages(sessionId: "retain").first?.content == "Retain my history", "failed deletion lost message")
        let reader = ChatHistoryStore(context: ModelContext(container))
        require(reader.recentSessions().map(\.id) == ["retain"], "failure flushed unrelated pending edit")
        try original.deletePersisted(sessionId: "retain")
        require(original.messages(sessionId: "retain").isEmpty, "success did not clear caller cached rows")
        require(original.recentSessions().map(\.id) == ["pending"], "success discarded unrelated pending edit")
        let fresh = ChatHistoryStore(context: ModelContext(container))
        require(fresh.recentSessions().isEmpty, "success flushed unrelated pending edit")
        try context.save()
        let afterCallerSave = ChatHistoryStore(context: ModelContext(container))
        require(afterCallerSave.recentSessions().map(\.id) == ["pending"], "later caller save resurrected deleted history or lost pending edit")
        require(afterCallerSave.messages(sessionId: "retain").isEmpty, "later caller save resurrected deleted messages")
        print("PASS: actual SwiftData failed shrink and deletion preserve messages/unrelated pending edits; successful deletion commits only target; later caller save loses no messages and resurrects no history")
    }
}
