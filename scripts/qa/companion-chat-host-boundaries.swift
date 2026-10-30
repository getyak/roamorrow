import Foundation

// Only platform/model transport boundaries are replaced. The complete production
// store, timeline, runtime records and file persistence execute in this host.
struct Experience {
    struct Location { var cityCode = "fixture" }
    struct Coordinate { var latitude: Double; var longitude: Double }
    var id: String
    var shortName: String
    var location = Location()
    var coordinate: Coordinate?
}
@MainActor final class AIService {}
@MainActor final class ExperienceService {}
@MainActor final class VoiceAgentToolRouter {}
@MainActor protocol CompanionHomeResponding {
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult
}
struct CompanionHomeAgentResult: Sendable {
    var text: String
    var sourceTitles: [String] = []
    var placeID: String?
    var placeIDs: [String] = []
}
@MainActor final class CompanionHomeAgent: CompanionHomeResponding {
    enum Progress: Equatable, Sendable { case thinking, tool(String) }
    weak var journalStore: CompanionHomeStore?
    var memory: (any AgentMemoryProviding)?
    var toolRouter: VoiceAgentToolRouter?
    var searchArea: (() -> CompanionHomeSearchArea?)?
    var activeCommitments: (() -> [CompanionHomeCommitment])?
    var onProgress: (@MainActor @Sendable (Progress) -> Void)?
    init(aiService: AIService, experienceService: ExperienceService) {}
    func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
        throw URLError(.notConnectedToInternet)
    }
}
