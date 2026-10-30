import Foundation
import SwiftData
import XCTest
@testable import SoloCompass

@MainActor
final class LegacyAgentRecoveryTests: XCTestCase {
    private enum Failure: Error { case unavailable }
    private var retainedModels: [MapViewModel] = []

    private func store(save: (() throws -> Void)? = nil) throws -> ChatHistoryStore {
        let container = try ModelContainer(
            for: ChatSessionRecord.self, ChatMessageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let history = ChatHistoryStore(context: ModelContext(container), saveSnapshot: save)
        isolate(history)
        return history
    }

    private func isolate(_ history: ChatHistoryStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-store-\(UUID().uuidString)")
        history.recoveryJournal = FileAgentExecutionJournal(url: root.appendingPathComponent("journal.json"))
        history.recoveryMemory = DeviceAgentMemoryStore(fileURL: root.appendingPathComponent("memory.json"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    }

    private func orchestrator(history: ChatHistoryStore) throws -> VoiceAgentOrchestrator {
        let ai = AIService()
        let preferences = UserPreferences()
        let model = MapViewModel(locationService: LocationService.shared,
                                 experienceService: ExperienceService(), aiService: ai,
                                 preferences: preferences)
        retainedModels.append(model)
        let value = VoiceAgentOrchestrator(aiService: ai, voiceService: VoiceService(),
                                          mapViewModel: model, preferences: preferences,
                                          historyStore: history)
        value.executionJournal = history.recoveryJournal
        value.deviceMemory = history.recoveryMemory
        value.isSpeechSuppressed = true
        value.session.seedSystem("Test")
        value.debug_setReadyForTesting(true)
        return value
    }

    func testFailedSaveRestoresPriorSessionWithoutRollingBackOtherChanges() throws {
        var fail = false
        let container = try ModelContainer(
            for: ChatSessionRecord.self, ChatMessageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let history = ChatHistoryStore(context: context, saveSnapshot: {
            if fail { throw Failure.unavailable }
            try context.save()
        })
        isolate(history)
        let original = VoiceAgentSession.Message(role: .user, content: "Original")
        XCTAssertTrue(history.saveSession(id: "one", messages: [original], scopedExperienceId: nil))
        let unrelated = ChatSessionRecord(id: "other", scopedExperienceId: nil, title: "Keep",
                                          createdAt: "old", updatedAt: "old", messageCount: 1)
        context.insert(unrelated)
        fail = true
        XCTAssertFalse(history.saveSession(id: "one", messages: [
            original, .init(role: .assistant, content: "Unsaved")
        ], scopedExperienceId: "new"))
        XCTAssertEqual(history.messages(sessionId: "one"), [original])
        XCTAssertNil(history.recentSessions().first(where: { $0.id == "one" })?.scopedExperienceId)
        XCTAssertTrue(history.recentSessions().contains(where: { $0.id == unrelated.id }))
    }

    func testAcceptedInputMustSaveBeforeModelOrToolDispatch() async throws {
        let value = try orchestrator(history: store(save: { throw Failure.unavailable }))
        var modelCalls = 0
        value.responseProvider = { _, _ in
            modelCalls += 1
            return .init(content: "Unexpected", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("Save it"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(modelCalls, 0)
        XCTAssertEqual(value.uiState, .error(.network))
    }

    func testFinalReplyRetryKeepsOriginalUserAndNeverDispatchesMutationAgain() async throws {
        let history = try store()
        let value = try orchestrator(history: history)
        var modelCalls = 0
        var toolCalls = 0
        value.responseProvider = { _, tools in
            modelCalls += 1
            if modelCalls == 1 {
                return .init(content: nil, toolCalls: [
                    .init(id: "save-1", name: "save_to_favorites", argumentsJSON: "{\"experience_id\":\"place\"}")
                ])
            }
            if modelCalls == 2 { throw Failure.unavailable }
            XCTAssertTrue(tools.isEmpty, "Recovery may explain saved results, never create new mutations")
            return .init(content: "Saved", toolCalls: [])
        }
        value.toolExecutionProvider = { _ in
            toolCalls += 1
            return ("{\"outcome\":\"ok\"}", nil)
        }
        XCTAssertEqual(value.handleTextInput("Save it"), .accepted)
        await value.waitForCurrentTurn()
        let originalUser = try XCTUnwrap(value.session.transcript.first(where: { $0.role == .user }))
        XCTAssertEqual(toolCalls, 1)
        XCTAssertTrue(value.restartIfNeeded())
        XCTAssertEqual(value.handleTextInput("Save it"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(value.session.transcript.filter { $0.role == .user }.map(\.id), [originalUser.id])
        XCTAssertEqual(toolCalls, 1)
        XCTAssertEqual(value.session.lastAssistantText, "Saved")
        XCTAssertEqual(history.messages(sessionId: value.persistedConversationId), value.session.transcript)
    }

    func testSecondBatchOverBudgetEndsWithToolErrorsAndFinalOnlyReply() async throws {
        let value = try orchestrator(history: store())
        var modelCalls = 0
        var dispatched = 0
        value.toolExecutionProvider = { _ in dispatched += 1; return ("{\"outcome\":\"ok\"}", nil) }
        value.responseProvider = { messages, tools in
            modelCalls += 1
            if modelCalls < 3 {
                return .init(content: nil, toolCalls: (0..<3).map {
                    .init(id: "batch-\(modelCalls)-\($0)", name: "show_details", argumentsJSON: "{}")
                })
            }
            XCTAssertTrue(tools.isEmpty)
            XCTAssertEqual(messages.filter {
                $0.role == .tool && ($0.content ?? "").contains("tool_budget_exhausted")
            }.count, 3)
            return .init(content: "Here are the results so far", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("Show it"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(dispatched, 3)
        XCTAssertEqual(value.uiState, .responding("Here are the results so far"))
        XCTAssertFalse(value.session.isEnded)
    }

    func testPlannedContextDependentRouteIsRefusedDuringRecovery() async throws {
        let value = try orchestrator(history: store())
        let user = VoiceAgentSession.Message(role: .user, content: "A walk")
        let call = VoiceAgentSession.ToolCall(id: "route", name: "build_route", argumentsJSON: "{}")
        let assistant = VoiceAgentSession.Message(role: .assistant, toolCalls: [call])
        let turn = AgentTurnIdentity(session: .init(id: value.persistedConversationId, scope: "global"), turnID: user.id)
        XCTAssertTrue(value.executionJournal.savePlan(.init(id: assistant.id, calls: [
            .init(id: call.id, name: call.name, argumentsJSON: call.argumentsJSON)
        ]), for: turn))
        value.restoreConversation(id: value.persistedConversationId, messages: [user, assistant])
        await waitForSeed(value)
        var dispatched = 0
        value.toolExecutionProvider = { _ in dispatched += 1; return ("{}", nil) }
        value.responseProvider = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertTrue(messages.first(where: { $0.role == .tool })?.content?.contains("interrupted_context_unavailable") == true)
            return .init(content: "Please ask for a new walk", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("A walk"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(dispatched, 0)
    }

    func testForgetMemoryCannotReingestOldTranscriptButNewTurnCanLearn() async throws {
        let value = try orchestrator(history: store())
        var replies = 0
        value.responseProvider = { _, _ in
            replies += 1
            return .init(content: "Reply \(replies)", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("Old words"), .accepted)
        await value.waitForCurrentTurn()
        let descriptor = AgentSessionDescriptor(id: value.persistedConversationId, scope: "global")
        XCTAssertEqual(value.deviceMemory.context(for: descriptor).records.count, 1)
        XCTAssertTrue(value.deviceMemory.forgetAll())
        value.persistConversation()
        XCTAssertTrue(value.deviceMemory.context(for: descriptor).records.isEmpty)
        XCTAssertEqual(value.handleTextInput("New words"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(value.deviceMemory.context(for: descriptor).records.map(\.userText), ["New words"])
    }

    func testReopenRetainsAcceptedContextEpochBeforeAnyToolWasPlanned() async throws {
        let history = try store()
        let first = try orchestrator(history: history)
        first.responseProvider = { _, _ in throw Failure.unavailable }
        XCTAssertEqual(first.handleTextInput("Old words"), .accepted)
        await first.waitForCurrentTurn()
        let original = try XCTUnwrap(first.session.transcript.first(where: { $0.role == .user }))
        let descriptor = AgentSessionDescriptor(id: first.persistedConversationId, scope: "global")
        let identity = AgentTurnIdentity(session: descriptor, turnID: original.id)
        let captured = try XCTUnwrap(first.executionJournal.context(for: identity))
        XCTAssertNotNil(captured.memoryEpoch)
        XCTAssertTrue(first.deviceMemory.forgetAll())
        let reopened = try orchestrator(history: history)
        reopened.restoreConversation(id: descriptor.id, messages: history.messages(sessionId: descriptor.id))
        await waitForSeed(reopened)
        reopened.responseProvider = { _, tools in
            XCTAssertTrue(tools.isEmpty)
            return .init(content: "Recovered reply", toolCalls: [])
        }
        XCTAssertEqual(reopened.handleTextInput("Old words"), .accepted)
        await reopened.waitForCurrentTurn()
        XCTAssertEqual(reopened.executionJournal.context(for: identity), captured)
        XCTAssertTrue(reopened.deviceMemory.context(for: descriptor).records.isEmpty)
    }

    private func waitForSeed(_ value: VoiceAgentOrchestrator) async {
        for _ in 0..<100 where !value.debug_isSeeded { await Task.yield() }
        XCTAssertTrue(value.debug_isSeeded)
    }

    func testReopenHydratesStableCardAndToolReceiptWithoutDispatch() async throws {
        let history = try store()
        let value = try orchestrator(history: history)
        let sessionID = value.persistedConversationId
        let user = VoiceAgentSession.Message(role: .user, content: "Show it")
        let call = VoiceAgentSession.ToolCall(id: "details", name: "show_details", argumentsJSON: "{}")
        let assistant = VoiceAgentSession.Message(role: .assistant, toolCalls: [call])
        let turn = AgentTurnIdentity(session: .init(id: sessionID, scope: "global"), turnID: user.id)
        let place = try XCTUnwrap(ExperienceService.hardcodedSeed.first)
        let cardID = UUID()
        let planned = AgentToolCheckpoint(id: call.id, name: call.name, argumentsJSON: call.argumentsJSON,
                                          cardID: cardID)
        XCTAssertTrue(value.executionJournal.savePlan(.init(id: assistant.id, calls: [planned]), for: turn))
        XCTAssertTrue(value.executionJournal.saveStarted(callID: call.id, for: turn))
        var completed = planned
        completed.state = .completed
        completed.resultJSON = "{\"outcome\":\"ok\"}"
        completed.effectJSON = VoiceAgentToolRouter.encodeEffect(.experiences([place]))
        XCTAssertTrue(value.executionJournal.saveResult(completed, for: turn))
        value.restoreConversation(id: sessionID, messages: [user, assistant])
        await waitForSeed(value)
        XCTAssertEqual(value.cardsByMessageId.values.flatMap { $0 }.map(\.id), [cardID])
        var dispatched = 0
        value.toolExecutionProvider = { _ in dispatched += 1; return ("{}", nil) }
        value.responseProvider = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertEqual(messages.filter { $0.role == .tool }.count, 1)
            XCTAssertEqual(messages.first(where: { $0.role == .tool })?.content, completed.resultJSON)
            return .init(content: "Here it is", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("Show it"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(dispatched, 0)
        XCTAssertEqual(value.cardsByMessageId.values.flatMap { $0 }.map(\.id), [cardID])
    }

    func testStartedNavigationBecomesUncertainWithoutOpeningItAgain() async throws {
        let value = try orchestrator(history: store())
        let user = VoiceAgentSession.Message(role: .user, content: "Go there")
        let call = VoiceAgentSession.ToolCall(id: "navigate", name: "navigate_to", argumentsJSON: "{}")
        let assistant = VoiceAgentSession.Message(role: .assistant, toolCalls: [call])
        let turn = AgentTurnIdentity(session: .init(id: value.persistedConversationId, scope: "global"), turnID: user.id)
        let planned = AgentToolCheckpoint(id: call.id, name: call.name, argumentsJSON: call.argumentsJSON)
        XCTAssertTrue(value.executionJournal.savePlan(.init(id: assistant.id, calls: [planned]), for: turn))
        XCTAssertTrue(value.executionJournal.saveStarted(callID: call.id, for: turn))
        value.restoreConversation(id: value.persistedConversationId, messages: [user, assistant])
        await waitForSeed(value)
        var dispatched = 0
        value.toolExecutionProvider = { _ in dispatched += 1; return ("{}", nil) }
        value.responseProvider = { messages, tools in
            XCTAssertTrue(tools.isEmpty)
            XCTAssertTrue(messages.first(where: { $0.role == .tool })?.content?.contains("uncertain") == true)
            return .init(content: "Please confirm a new navigation request", toolCalls: [])
        }
        XCTAssertEqual(value.handleTextInput("Go there"), .accepted)
        await value.waitForCurrentTurn()
        XCTAssertEqual(dispatched, 0)
        XCTAssertEqual(value.executionJournal.toolBatches(for: turn).first?.calls.first?.state, .uncertain)
    }

    func testRebindDuringToolKeepsOldReceiptOutOfNewConversation() async throws {
        let value = try orchestrator(history: store())
        var continuation: CheckedContinuation<(String, VoiceAgentToolRouter.ToolEffect?), Never>?
        value.responseProvider = { _, _ in
            .init(content: nil, toolCalls: [.init(id: "save", name: "save_to_favorites", argumentsJSON: "{}")])
        }
        value.toolExecutionProvider = { _ in
            await withCheckedContinuation { continuation = $0 }
        }
        XCTAssertEqual(value.handleTextInput("Save it"), .accepted)
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        XCTAssertNotNil(continuation)
        let original = try XCTUnwrap(value.session.transcript.first(where: { $0.role == .user }))
        let oldID = value.persistedConversationId
        let turn = AgentTurnIdentity(session: .init(id: oldID, scope: "global"), turnID: original.id)
        value.rebindContext(nil)
        continuation?.resume(returning: ("{\"outcome\":\"ok\"}", nil))
        await waitForSeed(value)
        for _ in 0..<100 where value.executionJournal.toolBatches(for: turn).first?.calls.first?.state != .completed {
            await Task.yield()
        }
        XCTAssertNotEqual(value.persistedConversationId, oldID)
        XCTAssertTrue(value.session.transcript.isEmpty)
        XCTAssertTrue(value.cardsByMessageId.isEmpty)
        XCTAssertEqual(value.executionJournal.toolBatches(for: turn).first?.calls.first?.state, .completed)
    }

    func testRestoredIncompleteProtocolRowsAreHiddenFromModelButRemainVisible() {
        let session = VoiceAgentSession()
        session.seedSystem("Context")
        let user = VoiceAgentSession.Message(role: .user, content: "Save it")
        let assistant = VoiceAgentSession.Message(role: .assistant, toolCalls: [
            .init(id: "first", name: "show_details", argumentsJSON: "{}"),
            .init(id: "second", name: "navigate_to", argumentsJSON: "{}")
        ])
        let partial = VoiceAgentSession.Message(role: .tool, content: "{}", toolCallId: "first", name: "show_details")
        session.restoreHistory([user, assistant, partial])
        XCTAssertEqual(session.transcript, [user, assistant, partial])
        XCTAssertEqual(session.messages.filter { $0.role != .system }, [user])
    }

    func testRecoveryDoesNotReplaceAnotherTurnsToolWithTheSameCallID() {
        let session = VoiceAgentSession()
        session.seedSystem("Context")
        let call = VoiceAgentSession.ToolCall(id: "reused", name: "show_details", argumentsJSON: "{}")
        let first = VoiceAgentSession.Message(role: .assistant, toolCalls: [call])
        let second = VoiceAgentSession.Message(role: .assistant, toolCalls: [call])
        let firstResult = VoiceAgentSession.Message(role: .tool, content: "first", toolCallId: call.id)
        session.restoreHistory([
            .init(role: .user, content: "First"), first, firstResult,
            .init(role: .assistant, content: "Done"),
            .init(role: .user, content: "Second"), second
        ])
        let secondResult = VoiceAgentSession.Message(role: .tool, content: "second", toolCallId: call.id)
        session.restoreToolResults([secondResult], after: second.id)
        XCTAssertEqual(session.toolResults(after: first.id), [firstResult])
        XCTAssertEqual(session.toolResults(after: second.id), [secondResult])
    }

    func testCompactionKeepsAssistantToolGroupsTogether() {
        let session = VoiceAgentSession()
        session.seedSystem("Context")
        for index in 0..<10 {
            session.beginUserTurn(transcript: "Question \(index)")
            let calls = (0..<3).map {
                VoiceAgentSession.ToolCall(id: "\(index)-\($0)", name: "show_details", argumentsJSON: "{}")
            }
            session.appendAssistantTurn(content: nil, toolCalls: calls)
            for call in calls { session.appendToolResult(toolCallId: call.id, name: call.name, resultJSON: "{}") }
            session.resumeThinkingAfterTools()
            session.appendAssistantTurn(content: "Reply", toolCalls: [])
            session.finishSpeakingTurn()
        }
        var announced = Set<String>()
        for message in session.messages {
            if message.role == .assistant { announced.formUnion(message.toolCalls.map(\.id)) }
            if message.role == .tool { XCTAssertTrue(announced.contains(message.toolCallId ?? "")) }
        }
        XCTAssertEqual(session.transcript.count, 60)
    }
}
