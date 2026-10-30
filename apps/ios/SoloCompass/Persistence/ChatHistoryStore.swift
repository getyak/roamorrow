import Foundation
import SwiftData

/// SwiftData-backed persistence for chat conversations so history survives app
/// restarts and the user can reopen a past conversation.
///
/// `@MainActor` because SwiftData's `ModelContext` is single-actor, matching
/// `RouteStore` / `ItineraryStore`. A conversation is stored as one
/// `ChatSessionRecord` plus N `ChatMessageRecord` rows linked by `sessionId`.
/// `saveSession` is an idempotent upsert: it replaces the session's existing
/// message rows so the latest snapshot always wins (a turn-by-turn save just
/// overwrites the prior partial conversation under the same id).
@MainActor
public final class ChatHistoryStore {
    /// Posted after any successful mutation so observers can refresh the
    /// history list without holding a strong reference to the store.
    public static let didChange = Notification.Name("SoloCompass.ChatHistoryStore.didChange")

    public static let didDelete = Notification.Name("SoloCompass.ChatHistoryStore.didDelete")

    let context: ModelContext
    /// Failure-injection seam run immediately before the isolated deletion
    /// context saves. It must not save or mutate the caller's context.
    private let saveDeletion: (() throws -> Void)?
    private let saveSnapshot: () throws -> Void
    var recoveryJournal = FileAgentExecutionJournal.shared
    var recoveryMemory: any AgentMemoryProviding = DeviceAgentMemoryStore.shared

    /// `saveDeletion` is an optional pre-commit failure hook for tests. The
    /// store always commits deletions with its own isolated ModelContext; the
    /// hook must not save or modify the caller's context.
    public init(
        context: ModelContext,
        saveDeletion: (() throws -> Void)? = nil,
        saveSnapshot: (() throws -> Void)? = nil
    ) {
        self.context = context
        self.saveDeletion = saveDeletion
        self.saveSnapshot = saveSnapshot ?? { try context.save() }
    }

    /// Convenience init using the shared on-disk container.
    public convenience init() {
        self.init(context: ModelContext(SoloCompassModelContainer.shared))
    }

    private static func nowISO() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - Save

    /// Persist (upsert) a whole conversation under `sessionId`. Skips sessions
    /// that have no real user content yet so an opened-but-unused chat doesn't
    /// litter history. Returns true when something was written.
    @discardableResult
    public func saveSession(
        id sessionId: String,
        messages: [VoiceAgentSession.Message],
        scopedExperienceId: String?,
        createdAt: String? = nil
    ) -> Bool {
        // Only persist conversations the user actually had — at least one user
        // message present.
        let conversational = messages.filter { $0.role == .user || $0.role == .assistant }
        guard conversational.contains(where: { $0.role == .user }) else { return false }

        guard !recoveryJournal.isForgotten(sessionID: sessionId) else { return false }
        let descriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        guard let oldRows = try? context.fetch(descriptor) else { return false }
        let oldSession = existingSession(sessionId)
        let oldMetadata = oldSession.map {
            ($0.scopedExperienceId, $0.title, $0.createdAt, $0.updatedAt, $0.messageCount)
        }
        let oldValues = oldRows.map { row in
            (row, row.asMessage, row.orderIndex, row.createdAt)
        }
        let now = Self.nowISO()
        let session = oldSession ?? ChatSessionRecord(
            id: sessionId, scopedExperienceId: scopedExperienceId,
            title: Self.deriveTitle(from: messages), createdAt: createdAt ?? now,
            updatedAt: now, messageCount: conversational.count
        )
        if oldSession == nil { context.insert(session) }
        session.scopedExperienceId = scopedExperienceId
        session.title = Self.deriveTitle(from: messages)
        session.updatedAt = now
        session.messageCount = conversational.count
        var oldByID = Dictionary(uniqueKeysWithValues: oldRows.map { ($0.id, $0) })
        var inserted: [ChatMessageRecord] = []
        for (index, message) in messages.enumerated() where message.role != .system {
            let replacement = ChatMessageRecord.fromMessage(
                message, sessionId: sessionId, orderIndex: index, createdAt: now
            )
            if let row = oldByID.removeValue(forKey: replacement.id) {
                Self.copyMessage(replacement, to: row)
            } else {
                context.insert(replacement)
                inserted.append(replacement)
            }
        }
        let deleted = Array(oldByID.values)
        for row in deleted { context.delete(row) }
        do {
            try saveSnapshot()
        } catch {
            // Undo only this upsert. ModelContext.rollback() would discard
            // unrelated pending edits owned by another screen sharing it.
            for row in inserted { context.delete(row) }
            let deletedIDs = Set(deleted.map(\.id))
            for (row, message, index, created) in oldValues {
                let replacement = ChatMessageRecord.fromMessage(
                    message, sessionId: sessionId, orderIndex: index, createdAt: created
                )
                if deletedIDs.contains(row.id) {
                    // Reinserting the same deleted SwiftData instance does
                    // not undelete it. Restore a fresh model with the same
                    // durable id; a later caller save retains the old value.
                    context.insert(replacement)
                } else {
                    Self.copyMessage(replacement, to: row)
                }
            }
            if let oldMetadata {
                session.scopedExperienceId = oldMetadata.0
                session.title = oldMetadata.1
                session.createdAt = oldMetadata.2
                session.updatedAt = oldMetadata.3
                session.messageCount = oldMetadata.4
            } else {
                context.delete(session)
            }
            return false
        }
        postChange()
        return true
    }

    // MARK: - Fetch

    /// Saved sessions, most-recently-updated first, capped at `limit`.
    public func recentSessions(limit: Int = 30) -> [ChatSessionRecord] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<ChatSessionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// All non-system messages for a session, in stored order, as domain values
    /// ready to seed back into a `VoiceAgentSession`.
    public func messages(sessionId: String) -> [VoiceAgentSession.Message] {
        let descriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.sessionId == sessionId },
            // #85: secondary sort on createdAt so two messages that ended up
            // with the same orderIndex (rare — only possible after a crash
            // during a turn commit) still render in a deterministic order
            // instead of shuffling between launches. SwiftData's sort is
            // otherwise unstable for equal keys.
            sortBy: [SortDescriptor(\.orderIndex), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor))?.map(\.asMessage) ?? []
    }

    // MARK: - Delete

    /// Delete one session and all of its messages. No-op if not found.
    public func delete(sessionId: String) {
        try? deletePersisted(sessionId: sessionId)
    }

    /// Persist deletion intent before removing visible history. Cleanup failure
    /// leaves the row available for retry while late turns remain invalidated.
    /// The deletion uses its own context, so failure never marks caller models
    /// deleted and saving the target cannot flush unrelated caller edits.
    public func deletePersisted(sessionId: String) throws {
        guard recoveryJournal.forget(sessionID: sessionId) else {
            throw DeletionError.recoveryCleanupFailed
        }
        NotificationCenter.default.post(name: Self.didDelete, object: sessionId)
        guard recoveryMemory.forget(sessionID: sessionId) else {
            throw DeletionError.recoveryCleanupFailed
        }
        let messageDescriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        let sessionDescriptor = FetchDescriptor<ChatSessionRecord>(
            predicate: #Predicate { $0.id == sessionId }
        )
        let callerRows = try context.fetch(messageDescriptor)
        let callerSessions = try context.fetch(sessionDescriptor)
        let deletionContext = ModelContext(context.container)
        deletionContext.autosaveEnabled = false
        let persistedRows = try deletionContext.fetch(messageDescriptor)
        let persistedSessions = try deletionContext.fetch(sessionDescriptor)
        for row in persistedRows { deletionContext.delete(row) }
        for session in persistedSessions { deletionContext.delete(session) }
        do {
            try saveDeletion?()
            try deletionContext.save()
        } catch {
            // This context owns only the target deletion. Its rollback cannot
            // discard pending data from the caller's separate context.
            deletionContext.rollback()
            throw error
        }
        // Invalidate the caller's cached/pending target rows only after the
        // durable commit. Keep its unrelated changes unsaved for their owner.
        for row in callerRows { context.delete(row) }
        for session in callerSessions { context.delete(session) }
        postChange()
    }

    private enum DeletionError: Error { case recoveryCleanupFailed }

    // MARK: - Private helpers

    private func existingSession(_ id: String) -> ChatSessionRecord? {
        let descriptor = FetchDescriptor<ChatSessionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private static func copyMessage(_ source: ChatMessageRecord, to target: ChatMessageRecord) {
        target.sessionId = source.sessionId
        target.role = source.role
        target.content = source.content
        target.orderIndex = source.orderIndex
        target.createdAt = source.createdAt
        target.toolCallsBlob = source.toolCallsBlob
        target.toolCallId = source.toolCallId
        target.toolName = source.toolName
    }

    private func postChange() {
        NotificationCenter.default.post(name: ChatHistoryStore.didChange, object: self)
    }

    /// Derive a short title from the first user message (trimmed to one line,
    /// capped). Falls back to nil so the list can show a default.
    static func deriveTitle(from messages: [VoiceAgentSession.Message]) -> String? {
        guard let firstUser = messages.first(where: { $0.role == .user })?.content else {
            return nil
        }
        let oneLine = ChatDisplayText.removingContextEnvelopes(firstUser)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oneLine.isEmpty else { return nil }
        return oneLine.count > 40 ? String(oneLine.prefix(40)) + "…" : oneLine
    }
}
