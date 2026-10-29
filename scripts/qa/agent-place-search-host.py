#!/usr/bin/env python3
"""Compile real agent search handlers against isolated, network-free boundaries.

This is a host regression test, not an iOS build or live MapKit acceptance.
The extracted Swift functions are production source; only platform/store/POI
transport boundaries are stubbed. Pass an artifact directory to retain evidence.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/ios/SoloCompass"
router = (APP / "Services/VoiceAgentToolRouter.swift").read_text()
model = (APP / "ViewModels/MapViewModel.swift").read_text()
enrichment_source = (APP / "Services/Agents/EnrichmentAgent.swift").read_text()
progressive_radii = next(line.strip() for line in enrichment_source.splitlines() if line.strip().startswith("public static let progressiveRadii:"))


def block(source, signature):
    start = source.index(signature)
    indent = len(signature) - len(signature.lstrip())
    closing = "\n" + " " * indent + "}"
    end = source.index(closing, start) + len(closing)
    return source[start:end]


members = [
    "    private struct ExploreNearbyArgs:",
    "    private func executeExploreNearby(",
    "    private func recordAddedEffect(",
    "    private struct SearchPlacesArgs:",
    "    private func executeSearchPlaces(",
    "    private static func buildFilter<",
    "    private static func decode<",
    "    private static func successJSON(",
]
optional_members = ["    private func resolveSearchOrigin("]
extracted = "\n".join(block(router, member) for member in members)
extracted += "\n" + "\n".join(block(router, member) for member in optional_members if member in router)
origin = block(model, "    var agentSearchOrigin:") if "    var agentSearchOrigin:" in model else "    var agentSearchOrigin: (coordinate: CLLocationCoordinate2D, source: String)? { nil }"
quality_protocol = router[router.index("private protocol QualityArgsProvider"):router.index("/// Maps DeepSeek")]
filter_source = (APP / "Models/ExperienceFilter.swift").read_text()
experience_source = (APP / "Models/Experience.swift").read_text().split("    /// Returns a new Experience with selected fields overridden.")[0] + "\n}\n"
experience_source = experience_source.replace("import SwiftUI", "")
for signature in ["    public var color: Color {", "    public var scoreColor: Color {"]:
    while signature in experience_source:
        experience_source = experience_source.replace(block(experience_source, signature), "", 1)
ai_source = (APP / "Services/AIService.swift").read_text()
skeleton = block(ai_source, "    static func skeletonExperience(")
policy = (APP / "Models/DiscoveryRefreshPolicy.swift").read_text()
badge_source = (APP / "Views/Shared/TrustBadge.swift").read_text()
badge_level = block(badge_source, "    public enum Level:")
for signature in ["        var dotColor: Color {", "        var textColor: Color {"]:
    badge_level = badge_level.replace(block(badge_level, signature), "")
badge = "public enum TrustBadge {\n" + badge_level + "\n}\nextension Experience {\n" + block(badge_source, "    var trustBadgeLevel:") + "\n}\n"

stubs = r'''
import Foundation
import CoreLocation

enum ExperienceCategory: String, Sendable { case culture, nature, food, coffee, work, wellness, nightlife, hidden }
enum OverpassService {
    struct POI: Sendable {
        let osmId: Int64
        let name: String
        let nameEn: String? = nil
        let lat: Double
        let lon: Double
        let tags: [String: String]
    }
    static func category(for tags: [String: String]) -> ExperienceCategory { .food }
}
// ENRICHMENT_RADII
enum Authorization { case notDetermined, denied, authorizedWhenInUse, authorizedAlways }
@MainActor final class LocationService {
    var authorizationStatus = Authorization.notDetermined
    var currentLocation: CLLocation?
}
@MainActor final class MapKitPOIService {
    struct Request { let query: String; let coordinate: CLLocationCoordinate2D; let radius: Int }
    static var requests: [Request] = []
    static var responses: [[OverpassService.POI]] = []
    static var onRequest: (() throws -> Void)?
    func search(query: String, near coordinate: CLLocationCoordinate2D, radiusMeters: Int = 20000) async throws -> [OverpassService.POI] {
        Self.requests.append(.init(query: query, coordinate: coordinate, radius: radiusMeters))
        try Self.onRequest?()
        return Self.responses.isEmpty ? [] : Self.responses.removeFirst()
    }
    static func reset() { requests = []; responses = []; onRequest = nil }
}
@MainActor final class MapViewModel {
    static let defaultCenter = CLLocationCoordinate2D(latitude: 18.7877, longitude: 98.9938)
    static let knownCityCenters = ["tokyo": CLLocationCoordinate2D(latitude: 35.6817, longitude: 139.7708)]
    static let cityCodeAliases: [String: String] = [:]
    var selectedCity: String? = nil
    var cityPickedExplicitlyThisSession = false
    var lastVisibleMapCenter: CLLocationCoordinate2D? = nil
    var customCoordinates: CLLocationCoordinate2D? = nil
    var availableCities: [(code: String, name: String, center: CLLocationCoordinate2D)] = []
    let locationService = LocationService()
    var visibleExperiences: [Experience] = []
    var allExperiences: [Experience] = []
    var lastExploreAddedCount = 0
    var genericRequests: [CLLocationCoordinate2D] = []
    var isSearchingWeb = false
    static func cityCodeMatches(_ lhs: String, selected rhs: String) -> Bool { lhs == rhs }
    static func cityCode(for coordinate: CLLocationCoordinate2D) -> String { "geo_\(coordinate.longitude)_\(coordinate.latitude)" }
    func exploreProgressively(at coordinate: CLLocationCoordinate2D, startingRadiusMeters: Int?, category: ExperienceCategory?, filter: ExperienceFilter?) async { genericRequests.append(coordinate) }
    func exploreNearby(at coordinate: CLLocationCoordinate2D, radiusMeters: Int, category: ExperienceCategory?) async { genericRequests.append(coordinate) }
    func mergeDiscoveryBatch(_ experiences: [Experience]) -> DiscoveryMergeResult {
        var inserted: Set<String> = []
        for value in experiences {
            switch DiscoveryRefreshPolicy.decision(existing: allExperiences.first { $0.id == value.id }, incoming: value) {
            case .insert(let added): allExperiences.append(added); visibleExperiences.append(added); inserted.insert(added.id)
            case .refresh, .skip: break
            }
        }
        return .init(insertedIDs: inserted)
    }
'''
wrapper = r'''
}
@MainActor final class VoiceAgentToolRouter {
    enum RouterError: Error { case invalidArguments(tool: String, reason: String); case dependencyUnavailable(tool: String, dependency: String, hint: String); case underlying(tool: String, message: String) }
    enum ToolEffect { case experiences([Experience]) }
    var lastEffect: ToolEffect?
    var isSearchingPlaces = false
    private lazy var placeSearchService = MapKitPOIService()
    let vm: MapViewModel
    init(vm: MapViewModel) { self.vm = vm }
    private static let maxCardExperiences = 6
    private static let maxAutoExpandStages = 6
    private func requireMapVM(tool: String) throws -> MapViewModel { vm }
    private func autoExpandUntilResults(vm: MapViewModel) async -> (stagesExpanded: Int, exhausted: Bool) { (0, false) }
'''
cases = r'''
    func search(_ args: String) async throws -> [String: Any] {
        let json = try await executeSearchPlaces(args: args)
        return try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }
    func explore(_ args: String = "{}") async throws -> [String: Any] {
        let json = try await executeExploreNearby(args: args)
        return try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }
}
@MainActor var failures = 0
@MainActor var checks = 0
@MainActor func check(_ value: Bool, _ label: String) {
    checks += 1
    if !value { failures += 1; print("FAIL: \(label)") }
}
@main struct Regression {
    @MainActor static func main() async throws {
        let tokyo = CLLocationCoordinate2D(latitude: 35.6817, longitude: 139.7708)
        let poi = OverpassService.POI(osmId: 101, name: "Ramen fixture", lat: tokyo.latitude, lon: tokyo.longitude, tags: ["source": "mapkit"])
        let skeleton = AIService.skeletonExperience(from: poi, cityCode: "tokyo")
        check(skeleton.sources.first?.attribution == "Apple Maps", "MapKit result retains Apple Maps provenance")
        check(skeleton.sources.first?.url == nil, "MapKit synthetic id never generates fake OSM node URL")
        check(skeleton.confidence.reason == "Apple Maps entry, no AI enrichment", "MapKit confidence names actual unassessed source")
        check(skeleton.oneLiner == "explore.skeleton.oneLiner.mapkit", "MapKit one-liner uses its localized source")
        check(skeleton.trustBadgeLevel.label == "location.openIn.apple", "provenance badge prefers Apple Maps over legacy id namespace")
        if case .insert = DiscoveryRefreshPolicy.decision(existing: nil, incoming: skeleton) { check(true, "real merge policy accepts sourced provider result") }
        else { check(false, "real merge policy accepts sourced provider result") }
        check(!skeleton.isAIEnriched && !skeleton.isUserCreated && skeleton.soloScore.overall == 0, "unassessed MapKit result is neither AI-enriched nor user-uploaded")
        func fixture() -> (MapViewModel, VoiceAgentToolRouter) {
            MapKitPOIService.reset()
            let vm = MapViewModel()
            vm.lastVisibleMapCenter = tokyo
            return (vm, VoiceAgentToolRouter(vm: vm))
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            let json = try await router.search(#"{"query":"  ramen  ","radius_meters":1200,"progressive":false}"#)
            check(MapKitPOIService.requests.first?.query == "ramen", "query reaches real text-search boundary")
            check(MapKitPOIService.requests.first?.radius == 1200, "explicit radius reaches provider")
            check(vm.genericRequests.isEmpty, "specific query never becomes generic explore")
            check(json["found_count"] as? Int == 1 && json["added_count"] as? Int == 1, "found and inserted counts are separate")
            check(json["origin_source"] as? String == "map_viewport", "map scope is labelled, never called current location")
            check(vm.allExperiences.first?.location.coordinates == [tokyo.longitude, tokyo.latitude], "stored coordinates stay GeoJSON longitude/latitude")
            if case .experiences(let cards) = router.lastEffect { check(cards.first?.title == poi.name, "query result becomes inline card") }
            else { check(false, "query result has inline card") }
        }
        do {
            let (_, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            let json = try await router.search(#"{"query":"ramen","latitude":22.5431,"longitude":114.0579,"progressive":false}"#)
            let request = MapKitPOIService.requests.first
            check(request?.coordinate.latitude == 22.5431 && request?.coordinate.longitude == 114.0579, "explicit coordinate pair overrides map scope intact")
            check(json["origin_source"] as? String == "explicit_coordinates", "explicit coordinates are not attributed to live GPS")
        }
        do {
            let (_, router) = fixture()
            let json = try await router.search(#"{"query":"nonexistent fixture","radius_meters":100000}"#)
            check(json["found_count"] as? Int == 0 && json["search_exhausted"] as? Bool == true, "completed empty query has honest terminal result")
            check(MapKitPOIService.requests.count == 1, "maximum radius never expands beyond 100km")
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            let json = try await router.search(#"{"query":"ramen","rating_min":8,"progressive":false}"#)
            check(json["found_count"] as? Int == 1 && json["eligible_count"] as? Int == 0, "unknown rating is not invented to satisfy quality filter")
            check(MapKitPOIService.requests.count == 1 && vm.allExperiences.isEmpty, "quality mismatch does not add places or replace query with generic explore")
        }
        for (category, constraint) in [(ExperienceCategory.food, #""rating_min":8"#), (.coffee, #""categories":["coffee"]"#)] {
            let (vm, router) = fixture()
            let outer = OverpassService.POI(osmId: 102, name: "Outer matching fixture", lat: tokyo.latitude + 0.02, lon: tokyo.longitude, tags: ["source": "mapkit"])
            let rich = Experience(id: "exp_osm_102", title: "Existing qualified fixture", category: category,
                location: .init(coordinates: [outer.lon, outer.lat], cityCode: "tokyo", rating: 9))
            vm.allExperiences = [rich]
            MapKitPOIService.responses = [[poi], [poi, outer]]
            let json = try await router.search("{\"query\":\"ramen\",\"radius_meters\":1200,\(constraint)}")
            check(MapKitPOIService.requests.map(\.radius) == [1200, 1500] && MapKitPOIService.requests.allSatisfy { $0.query == "ramen" }, "nonempty but ineligible first ring expands the same query")
            check(json["found_count"] as? Int == 2 && json["eligible_count"] as? Int == 1 && json["added_count"] as? Int == 0, "outer qualified repeat hit stops search with distinct found/eligible/inserted counts")
            check(vm.allExperiences.count == 1 && vm.genericRequests.isEmpty, "ineligible inner results are never inserted or replaced by generic explore")
            if case .experiences(let cards) = router.lastEffect { check(cards.map(\.title) == [rich.title], "outer hit displays qualified canonical content") }
            else { check(false, "outer qualified repeat hit has inline card") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = Array(repeating: [poi], count: 4)
            let json = try await router.search(#"{"query":"ramen","rating_min":8}"#)
            check(MapKitPOIService.requests.map(\.radius) == [2000, 3000, 6000, 12000], "complete search sequence follows production EnrichmentAgent radii")
            check(json["search_exhausted"] as? Bool == true, "exhausted quality search is terminal even when last provider ring is nonempty")
            check(json["found_count"] as? Int == 1 && json["eligible_count"] as? Int == 0 && vm.allExperiences.isEmpty, "repeated ineligible provider hits are deduplicated without inventing eligible matches")
        }
        do {
            let (vm, router) = fixture()
            let rich = Experience(id: "exp_osm_101", title: "Existing curated fixture", category: .food, location: .init(coordinates: [tokyo.longitude, tokyo.latitude], cityCode: "tokyo"))
            vm.allExperiences = [rich]
            MapKitPOIService.responses = [[], [poi]]
            let json = try await router.search(#"{"query":"7-Eleven","radius_meters":1200}"#)
            check(MapKitPOIService.requests.map(\.query) == ["7-Eleven", "7-Eleven"], "every expanded ring retains the query")
            check(MapKitPOIService.requests.map(\.radius) == [1200, 1500], "progressive radius advances only after empty results")
            check(json["found_count"] as? Int == 1 && json["added_count"] as? Int == 0, "existing provider hit stops expansion without claiming new rows")
            if case .experiences(let cards) = router.lastEffect { check(cards.first?.title == rich.title, "cards use canonical stored content") }
            else { check(false, "existing hit has inline card") }
        }
        do {
            let (_, router) = fixture()
            MapKitPOIService.onRequest = { throw URLError(.notConnectedToInternet) }
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "provider failure must not become successful empty result") }
            catch { check(MapKitPOIService.requests.count == 1, "provider failure does not trigger generic fallback or more rings") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = { vm.selectedCity = "another-city" }
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "city change discards stale search") }
            catch { check(vm.allExperiences.isEmpty && router.lastEffect == nil, "stale city results cannot mutate store or cards") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = { throw CancellationError() }
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "cancelled provider must not report success") }
            catch { check(vm.allExperiences.isEmpty, "cancelled request never writes results") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = { vm.lastVisibleMapCenter = CLLocationCoordinate2D(latitude: 35.7, longitude: 139.8) }
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "viewport change discards stale search") }
            catch { check(vm.allExperiences.isEmpty, "stale viewport response never writes results") }
        }
        for source in ["selected_city", "authorized_location"] {
            let (vm, router) = fixture()
            vm.lastVisibleMapCenter = nil
            if source == "selected_city" {
                vm.selectedCity = "tokyo"
                vm.cityPickedExplicitlyThisSession = true
            } else {
                vm.locationService.authorizationStatus = .authorizedWhenInUse
                vm.locationService.currentLocation = CLLocation(latitude: tokyo.latitude, longitude: tokyo.longitude)
            }
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = { vm.lastVisibleMapCenter = CLLocationCoordinate2D(latitude: 35.7, longitude: 139.8) }
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "same-city pan invalidates implicit \(source) snapshot") }
            catch { check(vm.allExperiences.isEmpty && router.lastEffect == nil, "changed implicit \(source) scope cannot write results/cards") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = {
                vm.selectedCity = "another-city"
                vm.lastVisibleMapCenter = CLLocationCoordinate2D(latitude: 35.7, longitude: 139.8)
            }
            do {
                let json = try await router.search(#"{"query":"ramen","latitude":35.6817,"longitude":139.7708,"progressive":false}"#)
                check(json["eligible_count"] as? Int == 1 && json["origin_source"] as? String == "explicit_coordinates", "explicit coordinate search retains requested scope when map changes")
            } catch { check(false, "explicit coordinate search must not be invalidated by map changes") }
        }
        do {
            let (vm, router) = fixture()
            MapKitPOIService.responses = [[poi]]
            MapKitPOIService.onRequest = { withUnsafeCurrentTask { $0?.cancel() } }
            let task = Task<Void, Error> { @MainActor in _ = try await router.search(#"{"query":"ramen"}"#) }
            do { _ = try await task.value; check(false, "task cancellation after provider response is checked before merge") }
            catch { check(vm.allExperiences.isEmpty, "post-provider cancellation never writes results") }
        }
        do {
            let (vm, router) = fixture()
            vm.isSearchingWeb = true
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "overlapping map text searches do not run concurrently") }
            catch { check(MapKitPOIService.requests.isEmpty, "busy search does not send duplicate provider request") }
        }
        for args in [#"{"query":"   "}"#, #"{"query":"ramen","latitude":35}"#, #"{"query":"ramen","latitude":91,"longitude":139}"#, #"{"query":"ramen","radius_meters":0}"#] {
            let (_, router) = fixture()
            do { _ = try await router.search(args); check(false, "invalid query/coordinate/radius rejected: \(args)") }
            catch { check(MapKitPOIService.requests.isEmpty, "invalid request never reaches provider") }
        }
        do {
            let (vm, router) = fixture()
            vm.lastVisibleMapCenter = nil
            do { _ = try await router.search(#"{"query":"ramen"}"#); check(false, "missing location must not default to Chiang Mai") }
            catch { check(MapKitPOIService.requests.isEmpty, "missing location sends no fabricated origin") }
            do { _ = try await router.explore(); check(false, "generic explore must also require real map/location context") }
            catch { check(vm.genericRequests.isEmpty, "generic explore never silently uses Chiang Mai") }
            vm.selectedCity = "tokyo"
            check(vm.agentSearchOrigin == nil, "persisted/default city is not an explicit current selection")
            vm.cityPickedExplicitlyThisSession = true
            check(vm.agentSearchOrigin?.source == "selected_city", "explicit valid selected city is usable")
            vm.selectedCity = "unknown-city"
            check(vm.agentSearchOrigin == nil, "unresolvable city does not fall back to Chiang Mai")
            vm.cityPickedExplicitlyThisSession = false
            vm.locationService.currentLocation = CLLocation(latitude: tokyo.latitude, longitude: tokyo.longitude)
            check(vm.agentSearchOrigin == nil, "unauthorized cached location is not used")
            vm.locationService.authorizationStatus = .authorizedWhenInUse
            check(vm.agentSearchOrigin?.source == "authorized_location", "authorized valid GPS is a distinct source")
            vm.locationService.currentLocation = CLLocation(latitude: 91, longitude: 139)
            check(vm.agentSearchOrigin == nil, "invalid GPS coordinate is rejected")
        }
        print("Agent place search: \(checks - failures)/\(checks) host checks passed (stubbed platform/store/network boundaries).")
        if failures != 0 { exit(1) }
    }
}
'''

temporary = tempfile.TemporaryDirectory(prefix="agent-place-search-host-") if len(sys.argv) == 1 else None
artifact = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(temporary.name)
artifact.mkdir(parents=True, exist_ok=True)
source = artifact / "agent-place-search.swift"
fixture_extension = r'''
extension Experience {
    init(id: String, title: String, category: ExperienceCategory, location: ExperienceLocation) {
        let now = Date()
        self.init(id: id, title: title, oneLiner: title, whyItMatters: title, category: category, location: location,
            bestTimes: [], durationMinutes: .init(min: 30, max: 60), howTo: [], realInconveniences: [],
            soloScore: .init(overall: 8, breakdown: .init(seatingFriendly: 8, soloPatronRatio: 8, staffPressure: 0, soloPortioning: 8, ambianceFit: 8, safety: 8), basedOnCount: 0),
            sources: [.init(type: .user, attribution: "© OpenStreetMap contributors", verifiedAt: now)],
            confidence: .init(level: 1, lastVerifiedAt: now, reason: "OpenStreetMap entry, no AI enrichment", signals: .init(aiScrapeAgeDays: 0, passiveGpsHits30d: 0, activeReports30d: 0, trustedVerifications: 0)),
            nearbyExperienceIds: [], stats: .init(completionCount: 0, averageRating: 0), status: .candidate, createdAt: now, updatedAt: now)
    }
}
@MainActor enum AIService {
    static func enrichedLocation(from poi: OverpassService.POI, cityCode: String) -> ExperienceLocation {
        .init(coordinates: [poi.lon, poi.lat], cityCode: cityCode)
    }
'''
stubs = stubs.replace("enum ExperienceCategory: String, Sendable { case culture, nature, food, coffee, work, wellness, nightlife, hidden }", "")
stubs = stubs.replace("// ENRICHMENT_RADII", "enum EnrichmentAgent { " + progressive_radii + " }")
source.write_text(experience_source + fixture_extension + skeleton + "\n}\n" + policy + badge + stubs + origin + "\n}\n" + quality_protocol + filter_source + wrapper[wrapper.index("@MainActor final class VoiceAgentToolRouter"):] + extracted + cases)
command = ["xcrun", "swiftc", "-parse-as-library", "-strict-concurrency=complete", "-warnings-as-errors", "-module-cache-path", str(artifact / "ModuleCache"), str(source), "-o", str(artifact / "agent-place-search")]
subprocess.run(command, check=True)
subprocess.run([str(artifact / "agent-place-search")], check=True)
