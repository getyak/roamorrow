import Foundation
import SwiftData

/// ISO 8601 UTC timestamp for "now". File-level (non-isolated) so the nested
/// seed descriptors can call it synchronously under strict concurrency.
private func travelerNoteNowISO() -> String {
    ISO8601DateFormatter().string(from: Date())
}

/// ISO 8601 UTC timestamp `days` in the past — gives seeded notes believable
/// relative times ("3 天前") without absolute dates baked into source.
private func travelerNoteISODaysAgo(_ days: Int) -> String {
    let date = Date().addingTimeInterval(TimeInterval(-days) * 86_400)
    return ISO8601DateFormatter().string(from: date)
}

/// SwiftData-backed persistence for the traveler co-build layer: per-experience
/// notes (`TravelerNoteRecord`) and pending field corrections
/// (`PlaceCorrectionRecord`). Mirrors `ChatHistoryStore`: `@MainActor` (the
/// `ModelContext` is single-actor), a `didChange` notification after mutations,
/// and a `convenience init()` over the shared container plus a DI `init(context:)`
/// for tests.
///
/// Production never manufactures community notes or corrections. Tests and
/// previews may opt into design fixtures; historical fixture IDs are hidden
/// from normal reads without deleting stored data.
@Observable
@MainActor
public final class TravelerNoteStore {
    /// Posted after any successful mutation so views can refresh without holding
    /// a strong reference to the store.
    @ObservationIgnored
    public static let didChange = Notification.Name("SoloCompass.TravelerNoteStore.didChange")

    @ObservationIgnored
    let context: ModelContext

    private let saveContext: () throws -> Void
    private let includeDemonstrationContent: Bool

    public init(context: ModelContext, includeDemonstrationContent: Bool = false, saveContext: (() throws -> Void)? = nil) {
        self.context = context
        self.includeDemonstrationContent = includeDemonstrationContent
        self.saveContext = saveContext ?? { try context.save() }
    }

    /// Convenience init using the shared on-disk container.
    public convenience init() {
        self.init(context: ModelContext(SoloCompassModelContainer.shared))
    }

    // MARK: - Notes: fetch

    /// Notes for an experience, AI-adopted and most-confirmed first, then newest.
    /// `SortDescriptor` can't sort on a `Bool` key path, so the AI-adopted
    /// priority is applied in Swift after the store-side confirm/date sort.
    public func notes(for experienceId: String) -> [TravelerNote] {
        seedIfNeeded(for: experienceId)
        let descriptor = FetchDescriptor<TravelerNoteRecord>(
            predicate: #Predicate { $0.experienceId == experienceId },
            sortBy: [
                SortDescriptor(\.confirms, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        let records = includeDemonstrationContent ? fetched : fetched.filter { !Self.demonstrationNoteIDs.contains($0.id) }
        // Stable partition: AI-adopted first, each group keeping the store's
        // confirm/date order (Swift's `sorted` isn't guaranteed stable).
        let adopted = records.filter { $0.aiAdopted }
        let rest = records.filter { !$0.aiAdopted }
        return (adopted + rest).map(\.asValue)
    }

    // MARK: - Notes: mutate

    /// Insert a new note authored by the current user ("你"). Returns the value
    /// that was stored so the caller can optimistically prepend it.
    @discardableResult
    public func addNote(
        experienceId: String,
        text: String,
        kind: TravelerNote.Kind = .experience
    ) -> TravelerNote? {
        do { return try addNotePersisted(experienceId: experienceId, text: text, kind: kind) }
        catch { return nil }
    }

    /// Returns only after durable storage acknowledges the new note. Failed
    /// inserts remove only this method's staged record, preserving other edits.
    @discardableResult
    public func addNotePersisted(
        experienceId: String,
        text: String,
        kind: TravelerNote.Kind = .experience
    ) throws -> TravelerNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = TravelerNote(
            id: "nu_\(UUID().uuidString)",
            experienceId: experienceId,
            authorInitial: NSLocalizedString("notes.author.you", comment: "Current-user author initial"),
            authorColor: nil,            // nil → accent disc
            text: trimmed,
            kind: kind,
            createdAt: travelerNoteNowISO(),
            confirms: 0,
            aiAdopted: false,
            isMine: true
        )
        let record = TravelerNoteRecord(from: note)
        context.insert(record)
        do { try commit() }
        catch { context.delete(record); throw error }
        return note
    }

    /// Increment a note's confirm count by one. No-op if the note is missing.
    @discardableResult
    public func confirmNote(id: String) -> Bool {
        guard let record = noteRecord(id) else { return false }
        let previous = record.confirms
        record.confirms += 1
        do { try commit(); return true }
        catch { record.confirms = previous; return false }
    }

    // MARK: - Corrections

    /// Pending corrections for an experience (resolved ones are filtered out).
    public func corrections(for experienceId: String) -> [PlaceCorrection] {
        seedIfNeeded(for: experienceId)
        let pending = PlaceCorrection.Status.pending.rawValue
        let descriptor = FetchDescriptor<PlaceCorrectionRecord>(
            predicate: #Predicate { $0.experienceId == experienceId && $0.status == pending },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        return (includeDemonstrationContent ? fetched : fetched.filter { !Self.demonstrationCorrectionIDs.contains($0.id) }).map(\.asValue)
    }

    /// Record a local acceptance decision. This does not mutate the shared
    /// experience or publish a correction to the server.
    @discardableResult
    public func acceptCorrection(id: String) -> Bool {
        setCorrectionStatus(id: id, status: .accepted)
    }

    /// Mark a correction dismissed ("不准确").
    @discardableResult
    public func dismissCorrection(id: String) -> Bool {
        setCorrectionStatus(id: id, status: .dismissed)
    }

    // MARK: - Private

    private func setCorrectionStatus(id: String, status: PlaceCorrection.Status) -> Bool {
        guard let record = correctionRecord(id) else { return false }
        let previous = record.status
        record.status = status.rawValue
        do { try commit(); return true }
        catch { record.status = previous; return false }
    }

    private func noteRecord(_ id: String) -> TravelerNoteRecord? {
        let descriptor = FetchDescriptor<TravelerNoteRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func correctionRecord(_ id: String) -> PlaceCorrectionRecord? {
        let descriptor = FetchDescriptor<PlaceCorrectionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func commit() throws {
        try saveContext()
        NotificationCenter.default.post(name: TravelerNoteStore.didChange, object: self)
    }

    private func save() {
        // Demonstration seeding is best effort. User mutations use acknowledged
        // APIs above; a full disk should never crash the app's feedback flow.
        try? commit()
    }

    // MARK: - Seeding

    /// True once any record for `experienceId` exists — used as the idempotency
    /// marker so demo content seeds at most once per place.
    private func hasAnyRecords(for experienceId: String) -> Bool {
        var noteDesc = FetchDescriptor<TravelerNoteRecord>(
            predicate: #Predicate { $0.experienceId == experienceId }
        )
        noteDesc.fetchLimit = 1
        if let count = try? context.fetchCount(noteDesc), count > 0 { return true }
        var corrDesc = FetchDescriptor<PlaceCorrectionRecord>(
            predicate: #Predicate { $0.experienceId == experienceId }
        )
        corrDesc.fetchLimit = 1
        if let count = try? context.fetchCount(corrDesc), count > 0 { return true }
        return false
    }

    /// Seed demonstration notes + corrections for a known POI the first time it's
    /// opened. Content is lifted from the design handoff's NOTES_BANK /
    /// PENDING_CORRECTIONS. No-op for unknown ids or already-seeded places.
    private func seedIfNeeded(for experienceId: String) {
        guard includeDemonstrationContent, let seed = Self.seedBank[experienceId] else { return }
        guard !hasAnyRecords(for: experienceId) else { return }

        for note in seed.notes {
            context.insert(TravelerNoteRecord(from: note.materialize(experienceId: experienceId)))
        }
        for corr in seed.corrections {
            context.insert(PlaceCorrectionRecord(from: corr.materialize(experienceId: experienceId)))
        }
        try? context.save()
    }

    // Filter only exact IDs reserved by the design fixtures. Real user rows
    // are preserved; legacy demo rows are neither deleted nor counted as evidence.
    private static var demonstrationNoteIDs: Set<String> {
        Set(seedBank.flatMap { experienceID, bundle in bundle.notes.map { "seed_\(experienceID)_\($0.id)" } })
    }
    private static var demonstrationCorrectionIDs: Set<String> {
        Set(seedBank.flatMap { experienceID, bundle in bundle.corrections.map { "seed_\(experienceID)_\($0.id)" } })
    }

    /// Lightweight seed descriptors — `daysAgo` is resolved to an ISO timestamp
    /// at seed time so we don't bake absolute dates into the source.
    private struct SeedNote {
        let id: String
        let initial: String
        let color: String?
        let text: String
        let daysAgo: Int
        let kind: TravelerNote.Kind
        let confirms: Int
        let aiAdopted: Bool

        func materialize(experienceId: String) -> TravelerNote {
            TravelerNote(
                id: "seed_\(experienceId)_\(id)",
                experienceId: experienceId,
                authorInitial: initial,
                authorColor: color,
                text: text,
                kind: kind,
                createdAt: travelerNoteISODaysAgo(daysAgo),
                confirms: confirms,
                aiAdopted: aiAdopted,
                isMine: false
            )
        }
    }

    private struct SeedCorrection {
        let id: String
        let field: String
        let oldVal: String
        let newVal: String
        let sourceNote: String
        let daysAgo: Int

        func materialize(experienceId: String) -> PlaceCorrection {
            PlaceCorrection(
                id: "seed_\(experienceId)_\(id)",
                experienceId: experienceId,
                field: field,
                oldVal: oldVal,
                newVal: newVal,
                sourceNote: sourceNote,
                status: .pending,
                createdAt: travelerNoteISODaysAgo(daysAgo)
            )
        }
    }

    private struct SeedBundle {
        let notes: [SeedNote]
        let corrections: [SeedCorrection]
    }

    /// Demo content keyed by experience id. Mirrors the design handoff
    /// (sheet.jsx NOTES_BANK / PENDING_CORRECTIONS). Only known seed POIs appear;
    /// everything else opens with an empty, addable feed.
    private static let seedBank: [String: SeedBundle] = [
        "x10kup": SeedBundle(
            notes: [
                SeedNote(id: "n1", initial: "J", color: "#9B6A3A",
                         text: "週二下午兩點過去，二樓大窗位空著，待了 3 小時沒人理我。咖啡 30,000 ₭。",
                         daysAgo: 2, kind: .experience, confirms: 12, aiAdopted: true),
                SeedNote(id: "n2", initial: "M", color: "#2F7DD1",
                         text: "WiFi 偶爾會斷，大約 5 分鐘自動重連一次。需要連續工作的人留意。",
                         daysAgo: 7, kind: .correction, confirms: 1, aiAdopted: false),
                SeedNote(id: "n3", initial: "A", color: "#E89530",
                         text: "老闆會說一點英語，點單沒問題，可以指菜單。",
                         daysAgo: 21, kind: .experience, confirms: 5, aiAdopted: true),
                SeedNote(id: "n4", initial: "R", color: "#2FA46A",
                         text: "巷子有點難找，跟著地圖走最後 100 米要看門牌。",
                         daysAgo: 30, kind: .experience, confirms: 8, aiAdopted: true),
            ],
            corrections: [
                SeedCorrection(id: "pc1", field: NSLocalizedString("notes.field.hours", comment: "Opening hours field"),
                               oldVal: "09:00 – 21:00", newVal: "09:30 – 21:00",
                               sourceNote: NSLocalizedString("notes.correction.source.demo", comment: "Seed correction source"),
                               daysAgo: 4),
            ]
        ),
        "sunset-vp": SeedBundle(
            notes: [
                SeedNote(id: "n1", initial: "K", color: "#2FA46A",
                         text: "雨季傍晚經常陰天，看不到正經日落，建議查天氣再去。",
                         daysAgo: 5, kind: .correction, confirms: 7, aiAdopted: true),
                SeedNote(id: "n2", initial: "L", color: "#7A5BCC",
                         text: "河邊有蚊子，記得帶驅蚊液。日落後 30 分鐘最舒服。",
                         daysAgo: 7, kind: .experience, confirms: 4, aiAdopted: false),
            ],
            corrections: []
        ),
    ]
}
