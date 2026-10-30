import XCTest
import SwiftData
@testable import SoloCompass

@MainActor
final class AgentMemoryRuntimeTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("agent-memory-tests-\(UUID())")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var url: URL { directory.appendingPathComponent("memory.json") }

    private func turn(session: String = "one", scope: String = "global", id: UUID = UUID(),
                      user: String = "I like quiet coffee", reply: String = "We discussed a cafe",
                      memoryEpoch: UUID? = nil, cityCode: String? = nil) -> AgentCompletedTurn {
        AgentCompletedTurn(identity: .init(session: .init(id: session, scope: scope), turnID: id),
                           userText: user, assistantText: reply, cityCode: cityCode, memoryEpoch: memoryEpoch)
    }

    func testCompletedTurnsReopenWithAttributionAndStableIdentity() {
        let saved = turn()
        XCTAssertTrue(DeviceAgentMemoryStore(fileURL: url).recordCompletedTurn(saved))
        let reopened = DeviceAgentMemoryStore(fileURL: url)
        let hits = reopened.recall(query: "coffee", scope: "global", limit: 3)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.identity, saved.identity)
        XCTAssertTrue(hits.first?.body.contains("Past user statement:") == true)
        XCTAssertTrue(hits.first?.body.contains("Past assistant reply (unverified):") == true)
    }

    func testReplayDeduplicatesAndConflictingIdentityCannotRewriteEvidence() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        let saved = turn()
        XCTAssertTrue(store.recordCompletedTurn(saved))
        XCTAssertTrue(store.recordCompletedTurn(saved))
        XCTAssertFalse(store.recordCompletedTurn(turn(id: saved.identity.turnID, user: "replacement")))
        XCTAssertEqual(store.recall(query: "coffee", scope: "global", limit: 10).count, 1)
    }

    func testScopeIsExactAndIncompleteTurnsAreRejected() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertTrue(store.recordCompletedTurn(turn(scope: "experience:cafe")))
        XCTAssertTrue(store.recordCompletedTurn(turn(session: "two", scope: "experience:park")))
        XCTAssertFalse(store.recordCompletedTurn(turn(user: "coffee", reply: "  ")))
        XCTAssertTrue(store.recall(query: "coffee", scope: "global", limit: 5).isEmpty)
        XCTAssertEqual(store.recall(query: "coffee", scope: "experience:cafe", limit: 5).count, 1)
    }

    func testBoundsTrimRecordsAndUtterances() {
        let store = DeviceAgentMemoryStore(fileURL: url, maxRecords: 2)
        for index in 0..<3 {
            XCTAssertTrue(store.recordCompletedTurn(turn(session: "\(index)", user: "coffee " + String(repeating: "x", count: 3_000))))
        }
        let hits = store.recall(query: "coffee", scope: "global", limit: 10)
        XCTAssertEqual(hits.count, 2)
        XCTAssertTrue(hits.allSatisfy { $0.userText.count == 2_000 })
    }

    func testFailedWriteDoesNotAddVolatileEvidence() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("file")
        try Data("block".utf8).write(to: blocker)
        let store = DeviceAgentMemoryStore(fileURL: blocker.appendingPathComponent("memory.json"))
        XCTAssertFalse(store.recordCompletedTurn(turn()))
        XCTAssertTrue(store.recall(query: "coffee", scope: "global", limit: 5).isEmpty)
    }

    func testCorruptionIsUnavailableAndExplicitForgetCanClearIt() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{bad".utf8).write(to: url)
        let store = DeviceAgentMemoryStore(fileURL: url)
        let session = AgentSessionDescriptor(id: "pending", scope: "global")
        XCTAssertFalse(store.context(for: session).isAvailable)
        XCTAssertFalse(store.recordCompletedTurn(turn()))
        XCTAssertTrue(store.forgetAll())
        XCTAssertTrue(DeviceAgentMemoryStore(fileURL: url).context(for: session).isAvailable)
    }

    func testSessionForgetPersistsTombstoneAndRejectsLateCompletion() {
        let pending = turn(session: "pending")
        let store = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertTrue(store.forget(sessionID: pending.identity.session.id))
        XCTAssertFalse(store.recordCompletedTurn(pending))
        XCTAssertFalse(DeviceAgentMemoryStore(fileURL: url).recordCompletedTurn(pending))
        XCTAssertTrue(store.recordCompletedTurn(turn(session: "new")))
    }

    func testForgetAllInvalidatesObservedPendingSessionsButAllowsNewSession() {
        let pending = turn(session: "pending")
        let store = DeviceAgentMemoryStore(fileURL: url)
        _ = store.context(for: pending.identity.session)
        XCTAssertTrue(store.forgetAll())
        XCTAssertFalse(store.recordCompletedTurn(pending))
        XCTAssertFalse(DeviceAgentMemoryStore(fileURL: url).recordCompletedTurn(pending))
        let freshEpoch = store.context(for: .init(id: "new", scope: "global")).epoch
        XCTAssertTrue(store.recordCompletedTurn(turn(session: "new", memoryEpoch: freshEpoch)))
        XCTAssertEqual(store.recall(query: "coffee", scope: "global", limit: 10).count, 1)
    }

    func testPromptMemoryIsBoundedAndDisclosesOmittedDialogue() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        let saved = turn(user: "coffee " + String(repeating: "u", count: 1_000), reply: String(repeating: "a", count: 1_000))
        XCTAssertTrue(store.recordCompletedTurn(saved))
        let prompt = store.context(for: saved.identity.session).renderForPrompt()
        XCTAssertLessThan(prompt.count, 1_200)
        XCTAssertTrue(prompt.contains("omitted does not mean absent"))
        XCTAssertEqual(store.recall(query: "coffee", scope: "global", limit: 1).first?.assistantText.count, 1_000)
    }

    func testSessionForgetRejectsOldEpochAndAdmitsFreshTurnInSameSession() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        let session = AgentSessionDescriptor(id: "ongoing", scope: "global")
        let originalEpoch = store.context(for: session).epoch
        XCTAssertTrue(store.recordCompletedTurn(turn(session: session.id, memoryEpoch: originalEpoch)))
        XCTAssertTrue(store.forget(sessionID: session.id))
        XCTAssertFalse(store.recordCompletedTurn(turn(session: session.id, memoryEpoch: originalEpoch)))
        let freshEpoch = store.context(for: session).epoch
        XCTAssertNotEqual(freshEpoch, originalEpoch)
        XCTAssertTrue(store.recordCompletedTurn(turn(session: session.id, memoryEpoch: freshEpoch)))
        let reopened = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertEqual(reopened.context(for: session).epoch, freshEpoch)
        XCTAssertEqual(reopened.recall(query: "coffee", scope: "global", limit: 10).count, 1)
        XCTAssertFalse(reopened.recordCompletedTurn(turn(session: session.id)))
    }

    func testForgetAllRotatesGlobalEpochAndAdmitsFreshSameSession() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        let session = AgentSessionDescriptor(id: "ongoing", scope: "global")
        let oldEpoch = store.context(for: session).epoch
        XCTAssertTrue(store.forgetAll())
        XCTAssertFalse(store.recordCompletedTurn(turn(session: session.id, memoryEpoch: oldEpoch)))
        let reopened = DeviceAgentMemoryStore(fileURL: url)
        let newEpoch = reopened.context(for: session).epoch
        XCTAssertNotEqual(oldEpoch, newEpoch)
        XCTAssertTrue(reopened.recordCompletedTurn(turn(session: session.id, memoryEpoch: newEpoch)))
    }

    func testGlobalDeletionRejectsUnobservedLegacyTurnAfterReopen() {
        let legacyTurn = turn(session: "unobserved-legacy")
        XCTAssertTrue(DeviceAgentMemoryStore(fileURL: url).forgetAll())
        let reopened = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertFalse(reopened.recordCompletedTurn(legacyTurn))
        let freshEpoch = reopened.context(for: legacyTurn.identity.session).epoch
        XCTAssertTrue(reopened.recordCompletedTurn(turn(session: "unobserved-legacy", memoryEpoch: freshEpoch)))
    }

    func testFailedGlobalDeletionKeepsPriorEpochAndLegacyAdmission() throws {
        let store = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertTrue(store.recordCompletedTurn(turn()))
        let session = AgentSessionDescriptor(id: "one", scope: "global")
        let previousEpoch = store.context(for: session).epoch
        try FileManager.default.removeItem(at: directory)
        try Data("blocking parent".utf8).write(to: directory)
        XCTAssertFalse(store.forgetAll())
        XCTAssertEqual(store.context(for: session).epoch, previousEpoch)
        XCTAssertEqual(store.recall(query: "coffee", scope: "global", limit: 3).count, 1)
        try FileManager.default.removeItem(at: directory)
        XCTAssertTrue(store.recordCompletedTurn(turn(session: "fresh-legacy")))
    }

    func testCityFilterPrecedesRankingAndLimitThroughCommonProvider() {
        let store = DeviceAgentMemoryStore(fileURL: url)
        XCTAssertTrue(store.recordCompletedTurn(turn(session: "kyoto", user: "coffee", reply: "A Kyoto conversation", cityCode: "kyoto")))
        for index in 0..<3 {
            XCTAssertTrue(store.recordCompletedTurn(turn(session: "tokyo-\(index)", user: "quiet coffee", reply: "A Tokyo conversation", cityCode: "tokyo")))
        }
        let provider: any AgentMemoryProviding = store
        XCTAssertTrue(provider.recall(query: "quiet coffee", scope: "global", limit: 3).allSatisfy { $0.cityCode == "tokyo" })
        let scoped = provider.recall(query: "quiet coffee", scope: "global", limit: 3, cityCode: "kyoto")
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped.first?.cityCode, "kyoto")
    }

    func testDigestGenerationRejectsOldScheduledEvidenceAndAllowsFreshEvidence() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AgentMemorySnapshot.self, TasteProfile.self,
                                           configurations: configuration)
        let service = MemoryDigestService(aiService: AIService(), modelContainer: container)
        let beforeDeletion = service.generation
        MemoryDigestService.invalidatePendingDigests()
        await service.digestConversation([.init(role: .user, content: "erased coffee")], expectedGeneration: beforeDeletion)
        XCTAssertNil(service.currentSnapshot())
        await service.digestConversation([.init(role: .user, content: "fresh coffee")], expectedGeneration: service.generation)
        XCTAssertTrue(service.currentSnapshot()?.recentChatDigest.contains("fresh coffee") == true)
        XCTAssertFalse(service.currentSnapshot()?.recentChatDigest.contains("erased coffee") == true)
    }
}
