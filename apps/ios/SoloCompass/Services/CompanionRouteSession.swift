import ActivityKit
import Foundation
import Observation
import SwiftData

/// A real, local route task. Unknown travel times stay unknown.
struct CompanionRouteProgress: Equatable, Sendable {
    var routeID: String
    var title: String
    var placeID: String
    var placeName: String
    var stopIndex: Int
    var totalStops: Int
    var etaText = ""
    var contextID: String { "companion-route:" + routeID }
}

@MainActor
protocol CompanionRoutePublishing {
    func show(_ value: CompanionRouteProgress) async -> Bool
    func end(contextID: String) async
    func reconcile(activeContextID: String?) async
}
extension CompanionRoutePublishing {
    func reconcile(activeContextID: String?) async {}
}

@MainActor
private struct CompanionRouteLivePublisher: CompanionRoutePublishing {
    func show(_ value: CompanionRouteProgress) async -> Bool {
        await LiveActivityService.shared.synchronizeCompanionRoute(value)
    }
    func end(contextID: String) async {
        await LiveActivityService.shared.endCompanionRoute(contextID: contextID)
    }
    func reconcile(activeContextID: String?) async {
        await LiveActivityService.shared.removeOrphanedCompanionRoutes(keeping: activeContextID)
    }
}

/// RouteStore is the durable source of truth; the island is an optional projection.
@MainActor @Observable
final class CompanionRouteSession {
    private(set) var active: CompanionRouteProgress?
    private(set) var errorMessage: String?
    private(set) var islandAvailable = false
    private(set) var isUpdating = false
    private(set) var wantsRoutePresentation = false
    var revealRequest = UUID()
    @ObservationIgnored private let store: RouteStore
    @ObservationIgnored private let publisher: any CompanionRoutePublishing
    @ObservationIgnored private let commit: (() throws -> Void)?
    @ObservationIgnored private var places: [String: Experience] = [:]
    @ObservationIgnored private var generation = UUID()

    init(routeStore: RouteStore? = nil, publisher: (any CompanionRoutePublishing)? = nil,
         commit: (() throws -> Void)? = nil) {
        store = routeStore ?? RouteStore()
        self.publisher = publisher ?? CompanionRouteLivePublisher()
        self.commit = commit
        reload()
    }

    func reveal() { wantsRoutePresentation = true; revealRequest = UUID() }
    func acknowledgeReveal() { wantsRoutePresentation = false }
    func clearError() { errorMessage = nil }

    @discardableResult
    func start(experience: Experience, cityCode: String) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }
        reload()
        if let active {
            if active.placeID == experience.id { reveal(); return true }
            errorMessage = companionText("companion.route.finishFirst", "先结束当前路线，再开始新的路线。")
            return false
        }
        places[experience.id] = experience
        let route = Route(id: RouteId(rawValue: "companion-walk-" + experience.id),
                          title: experience.shortName, summary: experience.oneLiner,
                          experienceIds: [experience.id], cityCode: cityCode, region: "",
                          estimatedDuration: 0, distanceMeters: 0, pace: .relaxed, source: .userCreated)
        do {
            try store.persistCompanionProgress(route: route, index: 0, completed: [], commit: commit)
            errorMessage = nil
            reload()
            reveal()
            await publish()
            return active != nil
        } catch {
            errorMessage = companionText("companion.route.saveFailed", "路线暂时没能保存，请重试；原有资料仍在。")
            return false
        }
    }

    func refresh(experiences: [Experience]) async {
        places = Dictionary(experiences.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard !isUpdating else { return }
        reload()
        await publish()
    }

    @discardableResult
    func arrived() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }
        guard let current = store.loadActiveRoute(), current.stopIndex < current.route.experienceIds.count else { return false }
        let id = current.route.experienceIds[current.stopIndex]
        var completed = current.completedIds
        completed.insert(id)
        let next = current.stopIndex + 1
        return await persist(current.route, index: next < current.route.experienceIds.count ? next : nil,
                             completed: completed)
    }

    @discardableResult
    func end() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }
        guard let current = store.loadActiveRoute() else { return true }
        return await persist(current.route, index: nil, completed: current.completedIds)
    }

    private func persist(_ route: Route, index: Int?, completed: Set<String>) async -> Bool {
        let contextID = active?.contextID
        do {
            try store.persistCompanionProgress(route: route, index: index, completed: completed, commit: commit)
            errorMessage = nil
            reload()
            if let contextID, active == nil {
                await publisher.end(contextID: contextID)
                islandAvailable = false
            } else {
                await publish()
            }
            return true
        } catch {
            errorMessage = companionText("companion.route.updateFailed", "路线状态暂时没能保存，当前进度已保留，请重试。")
            return false
        }
    }

    private func reload() {
        generation = UUID()
        guard let current = store.loadActiveRoute(),
              current.route.experienceIds.indices.contains(current.stopIndex) else { active = nil; return }
        let id = current.route.experienceIds[current.stopIndex]
        active = CompanionRouteProgress(routeID: current.route.id.rawValue, title: current.route.title,
                                        placeID: id, placeName: places[id]?.shortName ?? current.route.title,
                                        stopIndex: current.stopIndex, totalStops: current.route.experienceIds.count)
    }

    private func publish() async {
        let attempt = generation
        await publisher.reconcile(activeContextID: active?.contextID)
        guard attempt == generation, !Task.isCancelled else { return }
        guard let active else { islandAvailable = false; return }
        let available = await publisher.show(active)
        guard attempt == generation else { return }
        islandAvailable = available
    }
}

extension RouteStore {
    /// Update only this route, and restore only these fields if durable saving fails.
    func persistCompanionProgress(route: Route, index: Int?, completed: Set<String>,
                                  commit: (() throws -> Void)? = nil) throws {
        let id = route.id.rawValue
        let descriptor = FetchDescriptor<RouteRecord>(predicate: #Predicate { $0.id == id })
        let prior = try context.fetch(descriptor).first
        let record = prior ?? RouteRecord.fromValue(route)
        let oldStarted = record.activeStartedAt
        let oldIndex = record.currentStopIndex
        let oldCompleted = record.completedStopIdsBlob
        if prior == nil { context.insert(record) }
        record.activeStartedAt = index == nil ? nil : (oldStarted ?? Date())
        record.currentStopIndex = index
        record.completedStopIdsBlob = try JSONEncoder().encode(completed.sorted())
        do {
            if let commit { try commit() } else { try context.save() }
        } catch {
            if prior == nil { context.delete(record) }
            else {
                record.activeStartedAt = oldStarted
                record.currentStopIndex = oldIndex
                record.completedStopIdsBlob = oldCompleted
            }
            throw error
        }
        NotificationCenter.default.post(name: RouteStore.didChange, object: self, userInfo: ["routeId": id])
    }
}
