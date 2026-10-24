import Foundation
import SwiftData

/// SwiftData-backed CRUD for `Itinerary` values.
///
/// `@MainActor` because SwiftData `ModelContext` is single-actor and the
/// rest of the iOS code is main-thread-bound. Owns its `ModelContext`;
/// pass a context from `SoloCompassModelContainer.makeInMemory()` in tests.
///
/// US-007: every mutation enqueues an outbox row via `SyncService` when
/// `FF_COMPANION` is on. When the flag is off, the row is still written to
/// SwiftData but the outbox is skipped — flipping the flag later replays
/// nothing (itineraries are not event-sourced), but new mutations will sync
/// from that point forward.
@MainActor
public final class ItineraryStore {
    private let context: ModelContext
    private let saveContext: () throws -> Void

    public init(context: ModelContext, saveContext: (() throws -> Void)? = nil) {
        self.context = context
        self.saveContext = saveContext ?? { try context.save() }
    }

    /// Convenience init using the shared on-disk container.
    public convenience init() {
        self.init(context: ModelContext(SoloCompassModelContainer.shared))
    }

    // MARK: - CRUD

    /// Persist a new itinerary. Silently replaces an existing record with the
    /// same id (delete-then-insert to avoid SwiftData's implicit upsert gaps).
    public func save(_ itinerary: Itinerary) throws {
        if record(for: itinerary.id.rawValue) != nil {
            try update(itinerary)
            return
        }
        let inserted = ItineraryRecord(from: itinerary)
        context.insert(inserted)
        do {
            try saveContext()
        } catch {
            context.delete(inserted)
            throw error
        }
        enqueueSync(itinerary, isDeleted: false)
    }

    /// All stored itineraries, ordered by `createdAt` descending.
    public func loadAll() -> [Itinerary] {
        var descriptor = FetchDescriptor<ItineraryRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.propertiesToFetch = []
        return (try? context.fetch(descriptor))?.map(\.asValue) ?? []
    }

    /// Fetch a single itinerary by id. Returns nil if not found.
    public func load(id: ItineraryId) -> Itinerary? {
        record(for: id.rawValue)?.asValue
    }

    /// Update mutable fields of an existing itinerary. No-op if id not found.
    /// Throws when the durable write fails; in that case only this record's
    /// field mutations are rolled back (never `context.rollback()`, which
    /// would wipe unrelated pending edits).
    public func update(_ itinerary: Itinerary) throws {
        let rawId = itinerary.id.rawValue
        guard let existing = record(for: rawId) else { return }
        // Snapshot the prior value so a failed commit can restore this
        // record's own pending field changes.
        let prior = existing.asValue
        let fresh = ItineraryRecord(from: itinerary)
        existing.ownerId = fresh.ownerId
        existing.title = fresh.title
        existing.cityCode = fresh.cityCode
        existing.startDate = fresh.startDate
        existing.endDate = fresh.endDate
        existing.experienceIdsBlob = fresh.experienceIdsBlob
        existing.note = fresh.note
        existing.openToCompanions = fresh.openToCompanions
        existing.updatedAt = fresh.updatedAt
        do {
            try saveContext()
        } catch {
            existing.ownerId = prior.ownerId
            existing.title = prior.title
            existing.cityCode = prior.cityCode
            existing.startDate = prior.startDate
            existing.endDate = prior.endDate
            existing.experienceIdsBlob = ItineraryRecord(from: prior).experienceIdsBlob
            existing.note = prior.note
            existing.openToCompanions = prior.openToCompanions
            existing.updatedAt = prior.updatedAt
            throw error
        }
        enqueueSync(itinerary, isDeleted: false)
    }

    /// Delete an itinerary by id. No-op if not found.
    public func delete(id: ItineraryId) throws {
        guard let rec = record(for: id.rawValue) else { return }
        let value = rec.asValue
        context.delete(rec)
        do {
            try saveContext()
        } catch {
            context.insert(ItineraryRecord(from: value))
            throw error
        }
        // Enqueue a tombstone so the row is soft-deleted on the server.
        enqueueSync(value, isDeleted: true)
    }

    /// Append `experienceId` to the itinerary's list (idempotent — skips if already present).
    /// Returns the updated `Itinerary` value, or nil if the itinerary was not found.
    @discardableResult
    public func addExperience(_ experienceId: String, to itineraryId: ItineraryId) throws -> Itinerary? {
        try addExperiences([experienceId], to: itineraryId)
    }

    /// Append several experience ids in ONE durable save (route add-to-
    /// itinerary writes every stop together). Idempotent per id; returns the
    /// updated value or nil when the itinerary doesn't exist. On write failure
    /// the record's own pending blob change is rolled back and the error
    /// rethrown so callers can retain the selection and retry.
    @discardableResult
    public func addExperiences(_ experienceIds: [String], to itineraryId: ItineraryId) throws -> Itinerary? {
        guard let rec = record(for: itineraryId.rawValue) else { return nil }
        var ids = (try? JSONDecoder().decode([String].self, from: rec.experienceIdsBlob)) ?? []
        var seen = Set(ids)
        let toAdd = experienceIds.filter { seen.insert($0).inserted }
        guard !toAdd.isEmpty else { return rec.asValue }
        let priorBlob = rec.experienceIdsBlob
        let priorUpdatedAt = rec.updatedAt
        ids.append(contentsOf: toAdd)
        rec.experienceIdsBlob = (try? JSONEncoder().encode(ids)) ?? priorBlob
        rec.updatedAt = ISO8601DateFormatter().string(from: Date())
        do {
            try saveContext()
        } catch {
            rec.experienceIdsBlob = priorBlob
            rec.updatedAt = priorUpdatedAt
            throw error
        }
        let updated = rec.asValue
        enqueueSync(updated, isDeleted: false)
        return updated
    }

    /// Replace `experienceIds` with a reordered list. No-op if the itinerary is not found
    /// or the set of IDs differs from the current set (prevents accidental drops).
    /// Rolls back its own pending blob change on write failure before rethrowing.
    public func reorderExperiences(_ orderedIds: [String], in itineraryId: ItineraryId) throws {
        guard let rec = record(for: itineraryId.rawValue) else { return }
        let current = Set((try? JSONDecoder().decode([String].self, from: rec.experienceIdsBlob)) ?? [])
        guard Set(orderedIds) == current else { return }
        let priorBlob = rec.experienceIdsBlob
        let priorUpdatedAt = rec.updatedAt
        rec.experienceIdsBlob = (try? JSONEncoder().encode(orderedIds)) ?? priorBlob
        rec.updatedAt = ISO8601DateFormatter().string(from: Date())
        do {
            try saveContext()
        } catch {
            rec.experienceIdsBlob = priorBlob
            rec.updatedAt = priorUpdatedAt
            throw error
        }
        enqueueSync(rec.asValue, isDeleted: false)
    }

    /// Import a set of favorited experience IDs into an itinerary, skipping duplicates.
    /// Returns the number of IDs actually added.
    @discardableResult
    public func importFavorites(_ favoriteIds: Set<String>, into itineraryId: ItineraryId) throws -> Int {
        guard let rec = record(for: itineraryId.rawValue) else { return 0 }
        var ids = (try? JSONDecoder().decode([String].self, from: rec.experienceIdsBlob)) ?? []
        let existing = Set(ids)
        let toAdd = favoriteIds.filter { !existing.contains($0) }.sorted()
        if !toAdd.isEmpty { _ = try addExperiences(toAdd, to: itineraryId) }
        return toAdd.count
    }

    // MARK: - Private helpers

    private func record(for id: String) -> ItineraryRecord? {
        let descriptor = FetchDescriptor<ItineraryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Enqueue an upsert (or soft-delete tombstone) to the SyncService outbox.
    /// No-op when `FF_COMPANION` is off or when no authenticated session exists.
    private func enqueueSync(_ itinerary: Itinerary, isDeleted: Bool) {
        guard FeatureFlags.companion else { return }
        guard let userId = SupabaseClient.shared.currentSession?.userId else { return }
        let payload = SyncService.SyncItineraryPayload(
            id: itinerary.id.rawValue,
            user_id: userId,
            owner_id: itinerary.ownerId,
            title: itinerary.title,
            city_code: itinerary.cityCode,
            start_date: itinerary.startDate,
            end_date: itinerary.endDate,
            experience_ids: itinerary.experienceIds,
            note: itinerary.note,
            open_to_companions: itinerary.openToCompanions,
            is_deleted: isDeleted,
            device_id: DeviceIdentityService.shared.deviceID,
            created_at: itinerary.createdAt,
            updated_at: itinerary.updatedAt
        )
        SyncService.shared.enqueue(
            tableName: "itineraries",
            operation: "upsert",
            payload: payload,
            context: context
        )
    }
}
