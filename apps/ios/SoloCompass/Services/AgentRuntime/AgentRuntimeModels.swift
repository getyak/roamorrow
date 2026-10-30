import Foundation

struct AgentSessionDescriptor: Codable, Equatable, Hashable, Sendable {
    var id: String
    var scope: String
}

struct AgentTurnIdentity: Codable, Equatable, Hashable, Sendable {
    var session: AgentSessionDescriptor
    var turnID: UUID
}

struct AgentTurnContext: Codable, Equatable, Sendable {
    var capturedAt: Date
    var scope: String
    var facts: String
    var selectedAreaFact: String? = nil
    var memoryEpoch: UUID? = nil
}

enum AgentToolExecutionState: String, Codable, Sendable {
    case planned, started, completed, uncertain
}

/// Trusted metadata captured by the adapter before resolving a location-dependent call.
struct AgentToolOriginSnapshot: Codable, Equatable, Sendable {
    var source: String
    var latitude: Double
    var longitude: Double
    var selectedCity: String? = nil
    var interactionRevision: UInt64? = nil
}

/// The original model arguments identify a call; resolved arguments freeze device inputs.
struct AgentToolCheckpoint: Codable, Equatable, Sendable {
    static let currentImplementationVersion = 1

    var id: String
    var name: String
    var argumentsJSON: String
    var resultJSON: String?
    var sourceTitles: [String]
    var placeID: String?
    var placeIDs: [String]
    var state: AgentToolExecutionState
    var resolvedArgumentsJSON: String?
    var resolvedOrigin: AgentToolOriginSnapshot?
    var effectJSON: String?
    var cardID: UUID
    var implementationVersion: Int

    init(id: String, name: String, argumentsJSON: String, resultJSON: String? = nil,
         sourceTitles: [String] = [], placeID: String? = nil, placeIDs: [String] = [],
         state: AgentToolExecutionState? = nil, resolvedArgumentsJSON: String? = nil,
         resolvedOrigin: AgentToolOriginSnapshot? = nil, effectJSON: String? = nil, cardID: UUID = UUID(),
         implementationVersion: Int = AgentToolCheckpoint.currentImplementationVersion) {
        self.id = id
        self.name = name
        self.argumentsJSON = argumentsJSON
        self.resultJSON = resultJSON
        self.sourceTitles = sourceTitles
        self.placeID = placeID
        self.placeIDs = placeIDs
        self.state = state ?? (resultJSON == nil ? .planned : .completed)
        self.resolvedArgumentsJSON = resolvedArgumentsJSON
        self.resolvedOrigin = resolvedOrigin
        self.effectJSON = effectJSON
        self.cardID = cardID
        self.implementationVersion = implementationVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, argumentsJSON, resultJSON, sourceTitles, placeID, placeIDs, state
        case resolvedArgumentsJSON, resolvedOrigin, effectJSON, cardID, implementationVersion
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        argumentsJSON = try values.decode(String.self, forKey: .argumentsJSON)
        resultJSON = try values.decodeIfPresent(String.self, forKey: .resultJSON)
        sourceTitles = try values.decodeIfPresent([String].self, forKey: .sourceTitles) ?? []
        placeID = try values.decodeIfPresent(String.self, forKey: .placeID)
        placeIDs = try values.decodeIfPresent([String].self, forKey: .placeIDs) ?? []
        state = try values.decodeIfPresent(AgentToolExecutionState.self, forKey: .state)
            ?? (resultJSON == nil ? .planned : .completed)
        resolvedArgumentsJSON = try values.decodeIfPresent(String.self, forKey: .resolvedArgumentsJSON)
        resolvedOrigin = try values.decodeIfPresent(AgentToolOriginSnapshot.self, forKey: .resolvedOrigin)
        effectJSON = try values.decodeIfPresent(String.self, forKey: .effectJSON)
        cardID = try values.decodeIfPresent(UUID.self, forKey: .cardID) ?? Self.legacyCardID(id)
        implementationVersion = try values.decodeIfPresent(Int.self, forKey: .implementationVersion)
            ?? Self.currentImplementationVersion
    }

    static func canonicalArguments(_ json: String) throws -> String {
        do {
            let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
            guard value is [String: Any] else { throw AgentRuntimeError.invalidArguments }
            let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
            guard let canonical = String(data: bytes, encoding: .utf8) else {
                throw AgentRuntimeError.invalidArguments
            }
            return canonical
        } catch {
            throw AgentRuntimeError.invalidArguments
        }
    }

    func hasSameIdentity(as other: AgentToolCheckpoint) throws -> Bool {
        guard id == other.id, name == other.name else { return false }
        return try Self.canonicalArguments(argumentsJSON) == Self.canonicalArguments(other.argumentsJSON)
    }

    func matchesIdentity(_ other: AgentToolCheckpoint) -> Bool {
        (try? hasSameIdentity(as: other)) == true
    }

    // Stable fallback for pre-runtime snapshots, which never persisted a card identity.
    private static func legacyCardID(_ id: String) -> UUID {
        if let uuid = UUID(uuidString: id) { return uuid }
        var left: UInt64 = 14695981039346656037
        var right: UInt64 = 1099511628211
        for byte in id.utf8 {
            left = (left ^ UInt64(byte)) &* 1099511628211
            right = (right ^ UInt64(byte)) &* 14695981039346656037
        }
        let bytes = (0..<8).map { UInt8(truncatingIfNeeded: left >> (56 - $0 * 8)) }
            + (0..<8).map { UInt8(truncatingIfNeeded: right >> (56 - $0 * 8)) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

struct AgentToolBatch: Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var assistantContent: String?
    var calls: [AgentToolCheckpoint]
    var context: AgentTurnContext?
}

@MainActor
protocol AgentExecutionJournal: AnyObject {
    func toolBatches(for turn: AgentTurnIdentity) -> [AgentToolBatch]
    func savePlan(_ batch: AgentToolBatch, for turn: AgentTurnIdentity) -> Bool
    func saveStarted(callID: String, for turn: AgentTurnIdentity) -> Bool
    func saveResult(_ result: AgentToolCheckpoint, for turn: AgentTurnIdentity) -> Bool
}

enum AgentRuntimeError: Error, Equatable {
    case invalidArguments
    case identityConflict
    case toolNotAllowed
    case unsupportedVersion
    case budgetExceeded
    case persistenceFailed
    case invalidResult
    case executionInProgress
}
