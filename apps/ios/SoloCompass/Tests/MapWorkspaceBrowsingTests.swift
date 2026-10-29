import CoreLocation
import MapKit
import SwiftData
import XCTest
@testable import SoloCompass

/// The map, saved collection and message results are different browsing
/// contexts over one canonical Experience store. Camera settling cannot turn
/// an answer's two candidates into an unrelated nearby result set.
@MainActor
final class MapWorkspaceBrowsingTests: XCTestCase {
    private let chiangMai = CLLocationCoordinate2D(latitude: 18.7877, longitude: 98.9938)
    private let tokyo = CLLocationCoordinate2D(latitude: 35.7148, longitude: 139.7730)

    private func fixture(
        _ id: String, city: String = "cmi", category: ExperienceCategory = .coffee,
        coordinate: CLLocationCoordinate2D? = nil
    ) -> Experience {
        let coordinate = coordinate ?? chiangMai
        let now = Date()
        return Experience(
            id: id, title: id, oneLiner: id, whyItMatters: "Map workspace fixture",
            category: category,
            location: ExperienceLocation(coordinates: [coordinate.longitude, coordinate.latitude], cityCode: city),
            bestTimes: [], durationMinutes: .init(min: 30, max: 60), howTo: [], realInconveniences: [],
            soloScore: SoloScore(overall: 5, breakdown: .init(
                seatingFriendly: 5, soloPatronRatio: 5, staffPressure: 5,
                soloPortioning: 5, ambianceFit: 5, safety: 5
            ), basedOnCount: 1),
            sources: [InformationSource(type: .user, attribution: "isolated test", verifiedAt: now)],
            confidence: Confidence(level: 3, lastVerifiedAt: now, reason: "fixture", signals: .init(
                aiScrapeAgeDays: 1, passiveGpsHits30d: 0, activeReports30d: 0, trustedVerifications: 0
            )),
            nearbyExperienceIds: [], stats: .init(completionCount: 0, averageRating: 0),
            status: .active, createdAt: now, updatedAt: now
        )
    }

    private func makeViewModel(_ experiences: [Experience]) -> (MapViewModel, UserPreferences) {
        let defaults = UserDefaults(suiteName: "map.workspace.\(UUID().uuidString)")!
        let preferences = UserPreferences(defaults: defaults)
        preferences.lastSelectedCity = "cmi"
        preferences.maxDistanceKm = 1
        let repository = ExperienceRepository(
            context: ModelContext(SoloCompassModelContainer.makeInMemory()), preferences: nil
        )
        _ = repository.appendGenerated(experiences)
        let vm = MapViewModel(
            locationService: LocationService(),
            experienceService: ExperienceService(seed: experiences, repository: repository),
            aiService: AIService(), preferences: preferences
        )
        return (vm, preferences)
    }

    func testSmallViewportMoveUpdatesSearchOriginWithoutReplacingAnswerCandidates() {
        let (vm, _) = makeViewModel([fixture("answer"), fixture("other")])
        vm.openMessageResults(["answer"])
        let center = CLLocationCoordinate2D(latitude: chiangMai.latitude + 0.0005, longitude: chiangMai.longitude)
        vm.noteWorkspaceViewport(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        XCTAssertEqual(vm.agentSearchOrigin?.source, "map_viewport")
        XCTAssertEqual(vm.agentSearchOrigin?.coordinate.latitude, center.latitude)
        XCTAssertEqual(vm.messageResultIDs, ["answer"])
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["answer"])
    }

    func testMessageCandidatesKeepTheirOrderAndSurviveCameraSettling() {
        let (vm, _) = makeViewModel([fixture("first"), fixture("second"), fixture("other")])
        vm.openMessageResults(["second", "first", "second", "deleted"], selectedID: "second")

        vm.refreshForLocation(tokyo)
        vm.refreshWorkspaceMapPreservingCamera()

        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["second", "first"])
        XCTAssertEqual(vm.messageResultIDs, ["second", "first", "deleted"])
        XCTAssertEqual(vm.selectedExperience?.id, "second")
    }

    func testEmptyMessageResultStaysEmptyUntilExplicitAreaSearch() {
        let (vm, _) = makeViewModel([fixture("nearby")])
        vm.openMessageResults([])
        vm.refreshForLocation(chiangMai)
        vm.loadNearbyExperiences()
        XCTAssertEqual(vm.messageResultIDs, [])
        XCTAssertTrue(vm.visibleExperiences.isEmpty)
        XCTAssertNil(vm.selectedExperience)

        vm.searchThisArea()
        XCTAssertNil(vm.messageResultIDs)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["nearby"])
    }

    func testExplicitAreaKeepsCachedPlacesFromAnotherCityAndRestoresByMode() {
        let (vm, _) = makeViewModel([
            fixture("home"), fixture("tokyo", city: "tokyo", coordinate: tokyo)
        ])
        vm.openMessageResults(["tokyo"])
        vm.searchThisArea()
        XCTAssertEqual(vm.selectedCity, "cmi")
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["tokyo"])
        vm.setMapBrowseMode(.saved)
        vm.setMapBrowseMode(.nearby)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["tokyo"])
        vm.selectCity("cmi")
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["home"])
    }

    func testCurrentAreaSavedFollowsDistantAnswerWithoutChangingTripCity() {
        let (vm, preferences) = makeViewModel([
            fixture("home"), fixture("tokyo", city: "tokyo", coordinate: tokyo)
        ])
        preferences.toggleFavorite("home")
        preferences.toggleFavorite("tokyo")
        vm.openMessageResults(["tokyo"])
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.selectedCity, "cmi")
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["tokyo"])
        vm.setMapFavoriteScope(.allSaved)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["home", "tokyo"])
    }

    func testCurrentCitySavedPlacesIgnoreViewportDistanceAndAllSavedIncludesOtherCities() {
        let farInCity = CLLocationCoordinate2D(latitude: 18.90, longitude: 99.10)
        let (vm, preferences) = makeViewModel([
            fixture("near"), fixture("far", coordinate: farInCity), fixture("tokyo", city: "tokyo", coordinate: tokyo)
        ])
        for id in ["near", "far", "tokyo"] { preferences.toggleFavorite(id) }

        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["near", "far"])
        vm.setMapFavoriteScope(.allSaved)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["near", "far", "tokyo"])
        vm.refreshForLocation(tokyo)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["near", "far", "tokyo"])
    }

    func testSavedModeAndCategoryCanBeCombined() {
        let (vm, preferences) = makeViewModel([fixture("coffee"), fixture("museum", category: .culture)])
        preferences.toggleFavorite("coffee")
        preferences.toggleFavorite("museum")
        vm.setMapBrowseMode(.saved)
        vm.selectCategory(.culture)
        XCTAssertEqual(vm.mapBrowseMode, .saved)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["museum"])
    }

    func testStandingRecommendationDislikesDoNotHideExplicitSavedOrMessageIDs() {
        let (vm, preferences) = makeViewModel([fixture("saved")])
        preferences.toggleFavorite("saved")
        preferences.dislikedCategories = [.coffee]
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["saved"])
        vm.openMessageResults(["saved"])
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["saved"])
    }

    func testMessageFrameUsesShortArcAcrossTheAntimeridian() {
        let (vm, _) = makeViewModel([
            fixture("east", coordinate: .init(latitude: -17, longitude: 179)),
            fixture("west", coordinate: .init(latitude: -17, longitude: -179))
        ])
        vm.openMessageResults(["east", "west"])
        XCTAssertEqual(abs(vm.cameraPosition.region?.center.longitude ?? 0), 180, accuracy: 0.001)
        XCTAssertLessThan(vm.cameraPosition.region?.span.longitudeDelta ?? 360, 5)
    }

    func testCurrentAreaIncludesNearbyProviderGridCodesWithoutIncludingAnotherCity() {
        let (vm, preferences) = makeViewModel([
            fixture("local-provider", city: "osm_18.8_99.0"),
            fixture("tokyo-provider", city: "osm_35.7_139.8", coordinate: tokyo)
        ])
        preferences.toggleFavorite("local-provider")
        preferences.toggleFavorite("tokyo-provider")
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["local-provider"])
        vm.setMapFavoriteScope(.allSaved)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["local-provider", "tokyo-provider"])
    }

    func testSavedCurrentAreaWorksWithoutGPSOrANamedCityWhenViewportIsKnown() {
        let (vm, preferences) = makeViewModel([
            fixture("tokyo-saved", city: "osm_35.7_139.8", coordinate: tokyo), fixture("far-saved")
        ])
        vm.selectedCity = nil
        vm.cameraPosition = .region(.init(center: tokyo, span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        vm.refreshForLocation(tokyo)
        preferences.toggleFavorite("tokyo-saved")
        preferences.toggleFavorite("far-saved")

        vm.setMapBrowseMode(.saved)

        XCTAssertNil(vm.selectedCity)
        XCTAssertEqual(vm.mapFavoriteScope, .currentCity)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["tokyo-saved"])
        vm.setMapFavoriteScope(.allSaved)
        XCTAssertEqual(Set(vm.visibleExperiences.map(\.id)), ["tokyo-saved", "far-saved"])
    }

    func testRemovingFinalFavoriteClearsItsSelectionAndDetail() {
        let (vm, preferences) = makeViewModel([fixture("saved")])
        preferences.toggleFavorite("saved")
        vm.setMapBrowseMode(.saved)
        vm.openExperienceDetail(vm.visibleExperiences[0])
        preferences.toggleFavorite("saved")

        vm.refreshFavorites()

        XCTAssertTrue(vm.visibleExperiences.isEmpty)
        XCTAssertNil(vm.selectedExperience)
        XCTAssertFalse(vm.isShowingDetail)
    }

    func testOrdinaryRefreshDoesNotFitCameraToTightPins() {
        let (vm, _) = makeViewModel([fixture("first"), fixture("second")])
        let region = MKCoordinateRegion(center: chiangMai, span: .init(latitudeDelta: 0.8, longitudeDelta: 0.7))
        vm.cameraPosition = .region(region)
        vm.refreshWorkspaceMapPreservingCamera()
        XCTAssertEqual(vm.cameraPosition.region?.span.latitudeDelta, 0.8)
        XCTAssertEqual(vm.cameraPosition.region?.span.longitudeDelta, 0.7)
    }

    func testEachModeRestoresItsCategoryAndCamera() {
        let (vm, preferences) = makeViewModel([fixture("coffee"), fixture("museum", category: .culture)])
        preferences.toggleFavorite("museum")
        vm.selectCategory(.coffee)
        vm.cameraPosition = .region(.init(center: chiangMai, span: .init(latitudeDelta: 0.08, longitudeDelta: 0.07)))
        vm.setMapBrowseMode(.saved)
        vm.selectCategory(.culture)
        vm.cameraPosition = .region(.init(center: tokyo, span: .init(latitudeDelta: 0.03, longitudeDelta: 0.02)))

        vm.setMapBrowseMode(.nearby)
        XCTAssertEqual(vm.selectedCategory, .coffee)
        XCTAssertEqual(vm.cameraPosition.region?.center.latitude, chiangMai.latitude)
        XCTAssertEqual(vm.cameraPosition.region?.span.longitudeDelta, 0.07)
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.selectedCategory, .culture)
        XCTAssertEqual(vm.cameraPosition.region?.center.latitude, tokyo.latitude)
        XCTAssertEqual(vm.cameraPosition.region?.span.longitudeDelta, 0.02)
    }

    func testModeReselectionDoesNotRestoreAnOldCamera() {
        let (vm, _) = makeViewModel([fixture("first")])
        vm.setMapBrowseMode(.saved)
        vm.cameraPosition = .region(.init(center: tokyo, span: .init(latitudeDelta: 0.03, longitudeDelta: 0.02)))
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.cameraPosition.region?.center.latitude, tokyo.latitude)
    }

    func testMessageResultsRemainAvailableAfterASavedModeVisit() {
        let (vm, preferences) = makeViewModel([fixture("answer"), fixture("saved")])
        preferences.toggleFavorite("saved")
        vm.openMessageResults(["answer"])
        vm.setMapBrowseMode(.saved)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["saved"])
        vm.setMapBrowseMode(.nearby)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["answer"])
        XCTAssertEqual(vm.messageResultIDs, ["answer"])
    }

    func testSelectingAnotherCityReleasesThePreviousAnswerContext() {
        let (vm, preferences) = makeViewModel([fixture("old"), fixture("new", city: "tokyo", coordinate: tokyo)])
        preferences.maxDistanceKm = 10
        vm.openMessageResults(["old"])
        vm.selectCity("tokyo")
        XCTAssertNil(vm.messageResultIDs)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["new"])
    }

    private func bookstorePOI() -> OverpassService.POI {
        OverpassService.POI(
            osmId: 815_000_001, name: "Existing bookstore", nameEn: nil,
            lat: chiangMai.latitude, lon: chiangMai.longitude,
            tags: ["source": "mapkit", "shop": "books"]
        )
    }

    func testExplicitSearchLocksExistingHitsAndDoesNotMixOldCoffeeResults() async {
        let poi = bookstorePOI()
        let book = AIService.skeletonExperience(from: poi, cityCode: "cmi")
        let (vm, _) = makeViewModel([fixture("old-coffee"), book])
        vm.selectCategory(.coffee)
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["old-coffee"])
        vm.searchPOIsOverride = { _, _ in [poi] }

        let inserted = await vm.webSearchPOIs(
            query: "bookstore", near: chiangMai, constrainWorkspaceResults: true
        )

        XCTAssertEqual(inserted, 0, "An already-known provider hit still belongs to this query")
        XCTAssertTrue(vm.allExperiences.contains { $0.id == "old-coffee" })
        XCTAssertEqual(vm.visibleExperiences.map(\.id), [book.id])
        XCTAssertEqual(vm.messageResultIDs, [book.id])
        XCTAssertNil(vm.selectedCategory, "An old coffee filter cannot silently narrow an explicit bookstore query")
        XCTAssertEqual(vm.lastWebSearchResult, POISearchOutcome(query: "bookstore", status: .found(1)))
    }

    func testExplicitSearchDoesNotStampTheTripCityOnAnotherMapArea() async {
        let (vm, _) = makeViewModel([fixture("old-coffee")])
        let poi = OverpassService.POI(osmId: 815_000_002, name: "Tokyo bookstore", nameEn: nil,
            lat: tokyo.latitude, lon: tokyo.longitude, tags: ["source": "mapkit", "shop": "books"])
        vm.searchPOIsOverride = { _, _ in [poi] }
        await vm.webSearchPOIs(query: "bookstore", near: tokyo, constrainWorkspaceResults: true)
        let result = vm.visibleExperiences.first
        XCTAssertEqual(result?.location.cityCode, MapViewModel.cityCode(for: tokyo))
        XCTAssertEqual(vm.selectedCity, "cmi", "Browsing another area must not change the trip city")
    }

    func testExplicitEmptySearchDoesNotLeaveGenericNearbyResults() async {
        let (vm, _) = makeViewModel([fixture("old-coffee")])
        vm.searchPOIsOverride = { _, _ in [] }
        await vm.webSearchPOIs(query: "bookstore", near: chiangMai, constrainWorkspaceResults: true)
        vm.refreshForLocation(chiangMai)
        XCTAssertTrue(vm.allExperiences.contains { $0.id == "old-coffee" })
        XCTAssertTrue(vm.visibleExperiences.isEmpty)
        XCTAssertEqual(vm.messageResultIDs, [])
        XCTAssertEqual(vm.lastWebSearchResult, POISearchOutcome(query: "bookstore", status: .empty))
    }

    func testExplicitFailedSearchClearsItsMapButPreservesFailureFeedback() async {
        let (vm, _) = makeViewModel([fixture("old-coffee")])
        vm.searchPOIsOverride = { _, _ in throw URLError(.notConnectedToInternet) }
        await vm.webSearchPOIs(query: "bookstore", near: chiangMai, constrainWorkspaceResults: true)
        XCTAssertTrue(vm.allExperiences.contains { $0.id == "old-coffee" })
        XCTAssertTrue(vm.visibleExperiences.isEmpty)
        XCTAssertEqual(vm.messageResultIDs, [])
        XCTAssertEqual(vm.lastWebSearchResult, POISearchOutcome(query: "bookstore", status: .failed))
    }

    func testExplicitCancelledSearchKeepsTheExistingScope() async {
        let (vm, _) = makeViewModel([fixture("existing-scope")])
        vm.openMessageResults(["existing-scope"])
        vm.searchPOIsOverride = { _, _ in throw CancellationError() }
        await vm.webSearchPOIs(query: "bookstore", near: chiangMai, constrainWorkspaceResults: true)
        XCTAssertEqual(vm.messageResultIDs, ["existing-scope"])
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["existing-scope"])
        XCTAssertNil(vm.lastWebSearchResult)
    }

    func testExplicitSearchCannotOverwriteAScopeChosenWhileItWasWaiting() async {
        let (vm, _) = makeViewModel([fixture("new-scope")])
        let poi = bookstorePOI()
        vm.searchPOIsOverride = { _, _ in
            vm.openMessageResults(["new-scope"])
            return [poi]
        }
        await vm.webSearchPOIs(query: "bookstore", near: chiangMai, constrainWorkspaceResults: true)
        XCTAssertEqual(vm.messageResultIDs, ["new-scope"])
        XCTAssertEqual(vm.visibleExperiences.map(\.id), ["new-scope"])
        XCTAssertNil(vm.lastWebSearchResult)
    }
}
