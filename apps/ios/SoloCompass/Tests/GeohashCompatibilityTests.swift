import CoreLocation
import XCTest
@testable import SoloCompass

final class GeohashCompatibilityTests: XCTestCase {
    func testPublishedVectorsRemainStableAcrossEncoderEntryPoints() {
        let vectors: [(Double, Double, Int, String)] = [
            (42.6, -5.6, 5, "ezs42"),
            (57.64911, 10.40744, 11, "u4pruydqqvj"),
            (0, 0, 6, "s00000"),
        ]
        for (latitude, longitude, precision, expected) in vectors {
            XCTAssertEqual(Geohash.encode(latitude: latitude, longitude: longitude, precision: precision), expected)
            XCTAssertEqual(GeohashUtils.encode(latitude: latitude, longitude: longitude, precision: precision), expected)
        }
    }

    func testLegacyEncoderKeepsItsPrecisionBehavior() {
        XCTAssertEqual(Geohash.encode(latitude: 0, longitude: 0, precision: 0), "")
        XCTAssertEqual(Geohash.encode(latitude: 0, longitude: 0, precision: -1), "")
        XCTAssertEqual(Geohash.encode(latitude: 0, longitude: 0, precision: 13), "s000000000000")
    }

    func testCompanionDecoderPreservesCaseInsensitiveInput() throws {
        let lowercase = try XCTUnwrap(GeohashDecoder.centre(of: "ezs42"))
        let uppercase = try XCTUnwrap(GeohashDecoder.centre(of: "EZS42"))
        XCTAssertEqual(uppercase.latitude, lowercase.latitude)
        XCTAssertEqual(uppercase.longitude, lowercase.longitude)
        XCTAssertNil(GeohashUtils.decode("EZS42"), "The cache decoder's stricter input contract remains unchanged")
    }

    func testDecoderKeepsEmptyCellCenterAndRejectsInvalidCharacters() throws {
        let empty = try XCTUnwrap(GeohashDecoder.centre(of: ""))
        XCTAssertEqual(empty.latitude, 0)
        XCTAssertEqual(empty.longitude, 0)
        for invalid in ["a", "ezs4!", "🧭", "s00000 "] {
            XCTAssertNil(GeohashDecoder.centre(of: invalid))
            XCTAssertNil(GeohashUtils.decode(invalid))
        }
    }

    func testExtremeCoordinatesStayInsideDecodedCells() throws {
        for latitude in [-90.0, 0.0, 90.0] {
            for longitude in [-180.0, 0.0, 180.0] {
                let hash = GeohashUtils.encode(latitude: latitude, longitude: longitude, precision: 12)
                let cell = try XCTUnwrap(GeohashUtils.decode(hash))
                XCTAssertGreaterThanOrEqual(latitude, cell.latMin)
                XCTAssertLessThanOrEqual(latitude, cell.latMax)
                XCTAssertGreaterThanOrEqual(longitude, cell.lonMin)
                XCTAssertLessThanOrEqual(longitude, cell.lonMax)
            }
        }
    }
}
