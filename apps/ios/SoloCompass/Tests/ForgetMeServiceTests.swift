import XCTest
import SwiftData
@testable import SoloCompass

@MainActor
final class ForgetMeServiceTests: XCTestCase {
    func testForgetUsesInjectedMemoryAndInvalidatesPendingDigest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("forget-me-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let memory = DeviceAgentMemoryStore(fileURL: directory.appendingPathComponent("memory.json"))
        let identity = AgentTurnIdentity(session: .init(id: "isolated", scope: "global"), turnID: UUID())
        let epoch = memory.context(for: identity.session).epoch
        XCTAssertTrue(memory.recordCompletedTurn(.init(identity: identity, userText: "coffee", assistantText: "A past reply", memoryEpoch: epoch)))
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: VisitRecord.self, TasteProfile.self, TimeCapsule.self,
                                           AgentMemorySnapshot.self, configurations: configuration)
        let service = ForgetMeService(modelContainer: container)
        service.memoryProvider = memory
        let digest = MemoryDigestService(aiService: AIService(), modelContainer: container)
        digest.memoryProvider = memory
        let generation = digest.generation
        XCTAssertTrue(service.forgetEverything().didSave)
        XCTAssertTrue(memory.recall(query: "coffee", scope: "global", limit: 3).isEmpty)
        XCTAssertNotEqual(digest.generation, generation)
        XCTAssertFalse(memory.recordCompletedTurn(.init(identity: identity, userText: "coffee", assistantText: "Late reply", memoryEpoch: epoch)))
    }
}
