import XCTest
import CoreLocation
import SwiftData
import SwiftUI
import Observation
@testable import SoloCompass

@MainActor
final class MapFoodAccuracyTests: XCTestCase {
    func testCoordinateRatingAndVenueIdentityBoundaries() {
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            XCTAssertTrue(condition(), label)
        }
        func fixture(_ id: Int64, _ name: String, _ lat: Double = 31.78001,
                     _ lon: Double = 113.75001, _ tags: [String: String] = [:]) -> POI {
            POI(osmId: id, name: name, nameEn: nil, lat: lat, lon: lon, tags: tags)
        }
        let cn = CLLocationCoordinate2D(latitude: 31.787312, longitude: 113.759462)
        check(CoordinateConverter.isInsideChinaMainland(cn), "Haodian uses mainland provider boundary")
        check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 37.5665, longitude: 126.9780)), "Seoul is not mainland")
        check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 27.7172, longitude: 85.3240)), "Kathmandu is not mainland")
        check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 47.918, longitude: 106.917)), "Ulaanbaatar is not mainland")
        check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 22.2810, longitude: 114.1580)), "Hong Kong excluded")
        check(CoordinateConverter.isInsideChinaMainland(.init(latitude: 20.044, longitude: 110.199)), "Hainan included")

        let different = POIMerger.enrichMerge(
            base: [fixture(1, "Restaurant A")],
            enrichment: [fixture(2, "Restaurant B", 31.78002, 113.75002, ["fsq_rating": "9.5"])])
        check(different.count == 2, "different same-cell venues survive")
        check(different.first?.tags["fsq_rating"] == nil, "neighbor rating is not borrowed")
        let same = POIMerger.enrichMerge(
            base: [fixture(1, "Haodian Private Kitchen", 31.78001, 113.75001, ["phone": "+86 722 1234567"])],
            enrichment: [fixture(2, "Haodian Private Kitchen", 31.78020, 113.75001, ["phone": "867221234567", "fsq_rating": "9.5"])])
        check(same.count == 1, "same venue merges across coordinate cells")
        check(same.first?.tags["fsq_rating"] == "9.5", "verified identity can share rating")
        let floors = POIMerger.enrichMerge(
            base: [fixture(1, "Cafe", 31.78001, 113.75001, ["phone": "12345678", "addr": "Floor 1"])],
            enrichment: [fixture(2, "Cafe", 31.78001, 113.75001, ["phone": "87654321", "addr": "Floor 2"])])
        check(floors.count == 2, "conflicting phones/floors remain distinct")
        let normalized = CoordinateConverter.removingGCJ02Offset(cn)
        check(CLLocation(latitude: cn.latitude, longitude: cn.longitude).distance(from: CLLocation(latitude: normalized.latitude, longitude: normalized.longitude)) > 500, "Explicit GCJ fixture has a substantial offset (not a geographic accuracy test)")
        let roundTrip = CoordinateConverter.wgs84ToGcj02(normalized)
        check(abs(roundTrip.latitude - cn.latitude) < 0.00001 && abs(roundTrip.longitude - cn.longitude) < 0.00001, "Haodian conversion round trips within one metre")
        check(CoordinateConverter.gcj02ToWgs84(cn, countryCode: "KR").latitude == cn.latitude, "explicit foreign country never transforms")
        check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: .nan, longitude: 113)), "invalid coordinates fail closed")
        check(POIRating.normalized10(value: 4.5, scale: 5) == 9, "Amap 4.5/5 becomes 9/10")
        check(POIRating.normalized10(value: 9, scale: 10) == 9, "Foursquare 9/10 remains 9/10")
        for value in [Double.nan, .infinity, -1, 0, 6] {
            check(POIRating.normalized10(value: value, scale: 5) == nil, "invalid rating rejected: \(value)")
        }
        check(!POIMerger.sameVenue(fixture(10, "星巴克"), fixture(11, "星巴克", 31.78002)), "chain branches need corroborating identity")
        let pudong = CLLocationCoordinate2D(latitude: 31.1504353, longitude: 121.8059071)
        let xiamen = CLLocationCoordinate2D(latitude: 24.544, longitude: 118.127)
        check(CoordinateConverter.isInsideChinaMainland(pudong), "Pudong airport routes to mainland despite coastal geometry")
        check(CoordinateConverter.isInsideChinaMainland(xiamen, countryCode: "CN"), "Xiamen airport uses mainland routing with geocoded country evidence")
        let reclaimed = CLLocationCoordinate2D(latitude: 31.14, longitude: 121.83)
        check(CoordinateConverter.gcj02ToWgs84(reclaimed, countryCode: "CN").latitude != reclaimed.latitude, "explicit CN evidence overrides generalized coastlines")
    }

    func testAuthoritativeProviderIdsPreventBranchRatingTransfer() {
        let base = POI(osmId: 100, name: "郝店面馆", nameEn: nil, lat: 31.78001, lon: 113.75001,
                       tags: ["source":"amap", "amap_id":"A100", "addr":"Mall", "phone":"4000000"])
        let other = POI(osmId: 101, name: "郝店面馆", nameEn: nil, lat: 31.78002, lon: 113.75001,
                        tags: ["source":"amap", "amap_id":"A101", "addr":"Mall", "phone":"4000000", "fsq_rating":"9.6"])
        let merged = POIMerger.enrichMerge(base: [base], enrichment: [other])
        XCTAssertEqual(merged.count, 2)
        XCTAssertNil(merged[0].tags["fsq_rating"])
        let renamed = POI(osmId: 100, name: "New name", nameEn: nil, lat: 31.78002, lon: 113.75001,
                          tags: ["source":"amap", "amap_id":"A100", "phone":"new number"])
        XCTAssertEqual(POIMerger.merge(primary: [base], secondary: [renamed]).count, 1)
        for source in ["mapkit", "amap"] {
            let a = POI(osmId: 200, name: "Town Cafe", nameEn: nil, lat: 31.78004, lon: 113.75, tags: ["source":source])
            let b = POI(osmId: 201, name: "Town Cafe", nameEn: nil, lat: 31.78006, lon: 113.75, tags: ["source":source])
            XCTAssertEqual(POIMerger.merge(primary: [a], secondary: [b]).count, 1, "Synthetic IDs allow proximity matching")
        }
    }

    func testFractionalRadiusFormattingKeepsPlaceCount() {
        let format = NSLocalizedString("explore.toast.multiRing.addedNamed", comment: "Explore count and radius")
        let text = String(format: format, "Test", 12, 1.5)
        XCTAssertTrue(text.contains("12"))
        XCTAssertTrue(text.contains("1.5"))
    }

    func testUnassessedCardVisualEvidence() throws {
        let poi = POI(osmId: 123, name: "Haodian restaurant", nameEn: nil,
                      lat: 31.78, lon: 113.75, tags: ["amenity": "restaurant"])
        let experience = AIService.skeletonExperience(from: poi, cityCode: "test")
        let host = UIHostingController(rootView: ExperiencePreviewCard(experience: experience, distanceMeters: 240)
            .frame(maxHeight: .infinity, alignment: .top))
        host.view.frame = CGRect(x: 0, y: 0, width: 260, height: 330)
        host.view.backgroundColor = .white
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let previous = scene?.windows.first { $0.isKeyWindow }
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: host.view.frame)
        window.frame = host.view.frame
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { context in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 5_000)
        let attachment = XCTAttachment(image: image)
        attachment.name = "unassessed-restaurant-card"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRemoteMapSelectionKeepsItsPreciseQueryAnchor() throws {
        let name = "map-accuracy-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let vm = MapViewModel(locationService: LocationService(), experienceService: ExperienceService(),
                              aiService: AIService(), preferences: UserPreferences(defaults: defaults))
        let cameraChanged = expectation(description: "Canonical camera changes notify the rendered map")
        withObservationTracking { _ = vm.cameraPosition } onChange: { cameraChanged.fulfill() }
        let town = CLLocationCoordinate2D(latitude: 31.787312, longitude: 113.759462)
        vm.selectCustomLocation(coordinate: town, label: "Haodian", cityCode: "custom_haodian")
        wait(for: [cameraChanged], timeout: 1)
        XCTAssertEqual(vm.exploreAnchorCoordinate.latitude, town.latitude)
        XCTAssertEqual(vm.exploreAnchorCoordinate.longitude, town.longitude)
        let panned = CLLocationCoordinate2D(latitude: 31.789, longitude: 113.761)
        vm.refreshForLocation(panned)
        XCTAssertEqual(vm.exploreAnchorCoordinate.latitude, panned.latitude)
        XCTAssertEqual(vm.exploreAnchorCoordinate.longitude, panned.longitude)
        vm.selectCustomLocation(coordinate: town, label: "Haodian", cityCode: "custom_haodian")
        XCTAssertEqual(vm.exploreAnchorCoordinate.latitude, town.latitude, "same city code must still restore the chosen town point")
    }

    func testSearchRadiusRejectsDistantProviderResults() {
        let center = CLLocationCoordinate2D(latitude: 31.78, longitude: 113.75)
        let near = POI(osmId: 1, name: "Near", nameEn: nil, lat: 31.78, lon: 113.75, tags: [:])
        let far = POI(osmId: 2, name: "Far", nameEn: nil, lat: 32.0, lon: 113.75, tags: [:])
        XCTAssertEqual(MapKitPOIService.withinRadius([near, far], center: center, meters: 500).map(\.osmId), [1])
    }

    func testUnknownSoloPriorDoesNotHalveRealSurveyEvidence() throws {
        let container = SoloCompassModelContainer.makeInMemory()
        let repo = ExperienceRepository(context: ModelContext(container), preferences: nil)
        repo.recordSurvey(experienceId: "unknown", comfort: 3, pressure: 3, recommend: "yes", anonDeviceId: "test")
        XCTAssertEqual(try XCTUnwrap(repo.aggregatedSoloScore(experienceId: "unknown", seedOverall: 0)).overall, 6.5)
        XCTAssertEqual(try XCTUnwrap(repo.aggregatedSoloScore(experienceId: "unknown", seedOverall: 8)).overall, 7.5)
    }

    func testProviderIdentityDecodesLargeStringsAndLegacyNumbers() throws {
        struct Item: Decodable { @LosslessInt64 var id: Int64 }
        let large = try JSONDecoder().decode(Item.self, from: Data(#"{"id":"4611686018427387905"}"#.utf8))
        let legacy = try JSONDecoder().decode(Item.self, from: Data(#"{"id":123}"#.utf8))
        XCTAssertEqual(large.id, 4_611_686_018_427_387_905)
        XCTAssertEqual(legacy.id, 123)
    }

    func testSkeletonDoesNotInventHoursOrSoloAssessment() {
        let poi = POI(osmId: 123, name: "Test restaurant", nameEn: nil,
                      lat: 31.78, lon: 113.75, tags: ["amenity": "restaurant"])
        let experience = AIService.skeletonExperience(from: poi, cityCode: "test")
        XCTAssertTrue(experience.bestTimes.isEmpty)
        XCTAssertEqual(experience.soloScore.overall, 0)
        XCTAssertEqual(AIService.validSoloEstimate(nil), 0)
        XCTAssertEqual(AIService.validSoloEstimate(.nan), 0)
        XCTAssertEqual(AIService.validSoloEstimate(11), 0)
        XCTAssertEqual(AIService.validSoloEstimate(3), 3)
        XCTAssertTrue(AIService.verifiedVisitWindows(start: nil, end: 21).isEmpty)
        XCTAssertTrue(AIService.verifiedVisitWindows(start: 9, end: nil).isEmpty)
        XCTAssertTrue(AIService.verifiedVisitWindows(start: 24, end: 9).isEmpty)
        XCTAssertEqual(AIService.verifiedVisitWindows(start: 22, end: 2).count, 1)
    }
    func testSynthesisCacheBindsFactsRatherThanOnlyIds() {
        let a = POI(osmId: 1, name: "Cafe", nameEn: nil, lat: 31.78, lon: 113.75,
                    tags: ["amenity": "cafe", "opening_hours": "09:00-18:00"])
        let b = POI(osmId: 1, name: "Cafe", nameEn: nil, lat: 31.78, lon: 113.75,
                    tags: ["opening_hours": "10:00-18:00", "amenity": "cafe"])
        XCTAssertNotEqual(AIService.synthesisCacheKey(pois: [a], cityCode: "test", locale: .init(identifier: "en"), modelName: "deepseek-flash"),
                          AIService.synthesisCacheKey(pois: [b], cityCode: "test", locale: .init(identifier: "en"), modelName: "deepseek-flash"))
    }

    func testPartialPaginationIsRetainedAndRetried() async throws {
        let rows: [[String: Any]] = (0..<25).map { index in
            ["id": "accuracy-\(index)", "name": "Test restaurant \(index)",
             "location": "113.759462,31.787312", "typecode": "050100"]
        }
        let success = try JSONSerialization.data(withJSONObject: ["status": "1", "pois": rows])
        AccuracyAmapProtocol.handler = { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page_num" }?.value
            return page == "1" ? success : Data(#"{"status":"0","infocode":"10003","info":"DAILY_QUERY_OVER_LIMIT"}"#.utf8)
        }
        AccuracyAmapProtocol.requestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccuracyAmapProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); AccuracyAmapProtocol.handler = nil }
        let service = AmapPOIService(session: session, maxResults: 50, keyProvider: { "test" })
        let center = CoordinateConverter.gcj02ToWgs84(.init(latitude: 31.787312, longitude: 113.759462))
        let first = try await service.fetchPOIs(near: center)
        XCTAssertEqual(first.count, 25)
        XCTAssertTrue(service.lastFetchWasPartial)
        _ = try await service.fetchPOIs(near: center)
        XCTAssertEqual(AccuracyAmapProtocol.requestCount, 4, "partial pages must not masquerade as a complete cache")
    }

    func testCacheRestoresConsumedTransientSignals() async throws {
        AccuracyAmapProtocol.handler = { _ in
            Data(#"{"status":"1","pois":[{"id":"cached","name":"Test cafe","location":"113.759462,31.787312","typecode":"050500","business":{"rating":"4.5"}}]}"#.utf8)
        }
        AccuracyAmapProtocol.requestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccuracyAmapProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); AccuracyAmapProtocol.handler = nil }
        let service = AmapPOIService(session: session, keyProvider: { "test" })
        let center = CoordinateConverter.gcj02ToWgs84(.init(latitude: 31.787312, longitude: 113.759462))
        let pois = try await service.fetchPOIs(near: center)
        XCTAssertEqual(service.consumeEnrichments(for: pois.map(\.osmId)).count, 1)
        _ = try await service.fetchPOIs(near: center)
        XCTAssertEqual(service.consumeEnrichments(for: pois.map(\.osmId)).count, 1)
        XCTAssertEqual(AccuracyAmapProtocol.requestCount, 1)
    }

}


private final class AccuracyAmapProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> Data)?
    nonisolated(unsafe) static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.handler?(request) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
