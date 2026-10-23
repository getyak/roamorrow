import CoreLocation
import XCTest
@testable import SoloCompass

final class CompanionPlacePresentationTests: XCTestCase {
    func testUnknownProseUsesDisclosureWhileChineseAndProperNamesStayOriginal() {
        let unknown = "Mina's unverified moon-view stop 491"
        let otherUnknown = "A previously unseen place with no reviewed translation 827"
        let disclosure = CompanionPlacePresentation.summary(unknown, chinese: true)
        XCTAssertFalse(disclosure.isEmpty)
        XCTAssertNotEqual(disclosure, unknown)
        XCTAssertEqual(disclosure, CompanionPlacePresentation.summary(otherUnknown, chinese: true),
                       "Unknown source prose needs a generic original-material disclosure, not invented facts.")
        XCTAssertFalse(disclosure.contains("491"))
        XCTAssertFalse(disclosure.contains("827"))

        let chinese = "林同学说，Sister Srey 靠窗的地方很安静。"
        XCTAssertEqual(CompanionPlacePresentation.summary(chinese, chinese: true), chinese)
        XCTAssertEqual(CompanionPlacePresentation.summary(unknown, chinese: false), unknown)
        XCTAssertEqual(CompanionPlacePresentation.cityName(code: "unlisted-\(UUID())", fallback: "Mina & Jun's stop"),
                       "Mina & Jun's stop", "An unknown place name must stay as supplied.")
    }

    func testDistanceLabelsDistinguishGPSAndMapCenterWithoutInventingWalkingTime() throws {
        let origin = CLLocationCoordinate2D(latitude: 18.785, longitude: 98.985)
        let destination = CLLocationCoordinate2D(latitude: 18.786, longitude: 98.985)
        let gps = try XCTUnwrap(CompanionPlacePresentation.distance(to: destination, from: origin, usesGPS: true))
        let center = try XCTUnwrap(CompanionPlacePresentation.distance(to: destination, from: origin, usesGPS: false))
        XCTAssertNotEqual(gps, center)
        XCTAssertTrue(gps.contains("距你") || gps.lowercased().contains("you"))
        XCTAssertTrue(center.contains("地图中心") || center.lowercased().contains("map center"))
        for label in [gps, center] {
            XCTAssertTrue(label.contains("直线") || label.lowercased().contains("straight"))
            XCTAssertNil(label.range(of: #"\d+\s*(分钟|mins?\b|minutes?\b)"#,
                                     options: [.regularExpression, .caseInsensitive]),
                         "Coordinate distance alone cannot supply a walking-time estimate.")
        }

        let invalid: [CLLocationCoordinate2D?] = [
            nil,
            CLLocationCoordinate2D(latitude: 91, longitude: 98.985),
            CLLocationCoordinate2D(latitude: 18.785, longitude: 181),
            CLLocationCoordinate2D(latitude: .nan, longitude: 98.985),
            CLLocationCoordinate2D(latitude: 18.785, longitude: .infinity),
        ]
        for coordinate in invalid {
            for usesGPS in [true, false] {
                XCTAssertNil(CompanionPlacePresentation.distance(to: coordinate, from: origin, usesGPS: usesGPS))
                XCTAssertNil(CompanionPlacePresentation.distance(to: destination, from: coordinate, usesGPS: usesGPS))
            }
        }
    }

    func testSourceLabelsRetainProvenanceWithoutClaimingLiveVerification() {
        let oldRecord = Date(timeIntervalSince1970: 1_577_836_800)
        let user = InformationSource(type: .user, attribution: "Mina & Jun", verifiedAt: oldRecord)
        let chinese = InformationSource(type: .fieldVisit, attribution: "小林的到访笔记", verifiedAt: oldRecord)
        let handle = InformationSource(type: .reddit, attribution: "@MinaTravels", verifiedAt: oldRecord)
        let link = URL(string: "https://archive.example.org/travel/original-note")!
        let linked = InformationSource(type: .blog, url: link, verifiedAt: oldRecord)

        XCTAssertEqual(CompanionPlacePresentation.sourceName(user), "Mina & Jun")
        XCTAssertEqual(CompanionPlacePresentation.sourceName(chinese), "小林的到访笔记")
        XCTAssertEqual(CompanionPlacePresentation.sourceName(handle), "@MinaTravels")
        XCTAssertEqual(CompanionPlacePresentation.sourceName(linked), link.host)
        for source in [user, chinese, handle, linked] {
            let label = CompanionPlacePresentation.sourceName(source).lowercased()
            for unearnedClaim in ["实时", "已核验", "live", "verified"] {
                XCTAssertFalse(label.contains(unearnedClaim), "An old attributed source is not live verification.")
            }
        }
    }

    func testShippingSeedSummariesHaveChineseDisplayCoverage() throws {
        // Prefer the host app's shipping resource; the test bundle is a fallback
        // for an unhosted target using the same bundled JSON, never a test fixture.
        let bundles = [Bundle.main, Bundle(for: Self.self)]
        let url = try XCTUnwrap(bundles.lazy.compactMap { bundle in
            bundle.url(forResource: "seed_experiences", withExtension: "json")
                ?? bundle.url(forResource: "seed_experiences", withExtension: "json", subdirectory: "JSON")
        }.first, "The shipping seed_experiences.json must be bundled for this regression.")
        let records = try JSONDecoder.iso8601Decoder.decode([Experience].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(records.count, 34)
        let untranslatedDisclosure = CompanionPlacePresentation.summary("Unknown seed regression probe \(UUID())", chinese: true)
        for record in records {
            let display = CompanionPlacePresentation.summary(record.oneLiner, chinese: true)
            XCTAssertNotEqual(display, untranslatedDisclosure, "Missing reviewed Chinese summary for \(record.id).")
            XCTAssertNotNil(display.range(of: #"\p{Han}"#, options: .regularExpression),
                            "The Chinese place surface must show Chinese summary copy for \(record.id).")
            XCTAssertEqual(CompanionPlacePresentation.summary(record.oneLiner, chinese: false), record.oneLiner)
        }
    }
}
