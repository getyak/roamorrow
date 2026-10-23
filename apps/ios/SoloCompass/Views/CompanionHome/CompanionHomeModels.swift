import Foundation

/// Ephemeral request activity, never restored as a supposedly running task.
enum CompanionActivity: Equatable, Sendable {
    case idle, working(UUID), completed(UUID), failed(UUID)
    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }
}

struct CompanionHomeEntry: Identifiable, Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, companion }
    enum Status: String, Codable, Sendable { case queued, working, delivered, failed }
    var id: UUID = UUID()
    var role: Role
    var text: String
    var createdAt: Date = Date()
    var status: Status = .queued
    var sourceTitles: [String] = []
    var placeID: String?
    var reaction: String? = nil
    var attachments: [CompanionMediaAttachment]? = nil
    var quotedMessage: CompanionQuotedMessage? = nil
    /// Stable parent association allows a retry to replace its response, not append duplicates.
    var replyToID: UUID?
}

struct CompanionHomePerson: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var isExample: Bool = false
}

struct CompanionHomeInvite: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case draft, confirmed }
    var id: UUID = UUID()
    var placeID: String
    var placeName: String
    var date: Date
    /// Missing in old v1 records: nil is preserved rather than inventing a past creation time.
    var createdAt: Date? = nil
    var durationMinutes: Int
    var people: [CompanionHomePerson]
    var note: String
    var status: Status = .draft
}

/// A locally persisted intention; message delivery never changes its lifecycle.
struct CompanionHomeCommitment: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, done, cancelled }
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var status: Status = .active
    var updatedAt: Date = Date()
    var dueAt: Date?
    /// Retried turns can recognize their own previously persisted create operation.
    var originEntryID: UUID?
}

struct CompanionHomeFollowUpRequest: Sendable {
    enum Action: String, Sendable { case create, update, complete, cancel }
    enum Invalid: Error { case arguments }
    var action: Action
    var id: UUID?
    var title: String?
    var note: String?
    var dueAt: Date?
    var hasDueAt = false

    init(argumentsJSON: String) throws {
        guard argumentsJSON.utf8.count <= 12_000,
              let data = argumentsJSON.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["action", "id", "title", "note", "dueAt"]),
              let rawAction = object["action"] as? String, let action = Action(rawValue: rawAction) else { throw Invalid.arguments }
        self.action = action
        if let rawID = object["id"], !(rawID is NSNull) {
            guard let string = rawID as? String, let id = UUID(uuidString: string) else { throw Invalid.arguments }
            self.id = id
        }
        if let rawTitle = object["title"], !(rawTitle is NSNull) {
            guard let title = rawTitle as? String else { throw Invalid.arguments }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 160 else { throw Invalid.arguments }
            self.title = trimmed
        }
        if let rawNote = object["note"], !(rawNote is NSNull) {
            guard let note = rawNote as? String, note.count <= 2_000 else { throw Invalid.arguments }
            self.note = note
        }
        hasDueAt = object.keys.contains("dueAt")
        if let rawDate = object["dueAt"], !(rawDate is NSNull) {
            guard let raw = rawDate as? String, raw.count <= 40 else { throw Invalid.arguments }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { throw Invalid.arguments }
            dueAt = date
        }
        guard action != .create || (title != nil && id == nil),
              action == .create || id != nil else { throw Invalid.arguments }
        if action == .update, title == nil && note == nil && !hasDueAt { throw Invalid.arguments }
        if action == .complete || action == .cancel {
            guard title == nil, note == nil, !hasDueAt else { throw Invalid.arguments }
        }
    }
}

struct CompanionHomeFollowUpResult: Codable, Sendable {
    var success: Bool
    var commitment: CompanionHomeCommitment?
    var error: String?
}

/// Persisted before execution. Tool identities and arguments survive a failed model continuation.
struct CompanionHomeToolCheckpoint: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var argumentsJSON: String
    var resultJSON: String?
    var sourceTitles: [String] = []
    var placeID: String?
}

struct CompanionHomeToolBatch: Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var assistantContent: String?
    var calls: [CompanionHomeToolCheckpoint]
}

/// A public city/map center chosen in the UI, never a device-location reading.
struct CompanionHomeSearchArea: Codable, Equatable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var cityCode: String? = nil

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120 &&
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
