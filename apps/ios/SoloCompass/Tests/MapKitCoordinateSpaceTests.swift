import XCTest
import MapKit
import SwiftUI
@testable import SoloCompass

@MainActor
final class MapKitCoordinateSpaceTests: XCTestCase {
    private let haodian = CLLocationCoordinate2D(latitude: 31.789369, longitude: 113.753576)

    private func sample(_ anchor: MapKitCoordinateSpace.Anchor, search: MapKitCoordinateSpace.Datum = .gcj02,
                        render: MapKitCoordinateSpace.Datum = .gcj02) -> MapKitCoordinateSpace.Sample {
        func value(_ datum: MapKitCoordinateSpace.Datum) -> CLLocationCoordinate2D? {
            switch datum {
            case .wgs84: return anchor.coordinate
            case .gcj02: return CoordinateConverter.applyingGCJ02Offset(anchor.coordinate)
            case .unknown: return nil
            }
        }
        return .init(anchorID: anchor.id, search: value(search) ?? .init(latitude: 0, longitude: 0), nativeAnnotation: value(render))
    }

    func testIndependentInterfacesAndIOS17SearchFallback() async throws {
        let space = MapKitCoordinateSpace(renderStyles: [.standard], fetchSample: { self.sample($0, render: .unknown) })
        try await space.prepare(near: haodian)
        XCTAssertEqual(space.profile(for: haodian).searchOutput, .gcj02)
        XCTAssertEqual(space.profile(for: haodian).renderInput, .unknown)
        XCTAssertNotNil(space.searchCoordinate(haodian), "No render witness must not disable search")
        XCTAssertNil(space.mapCoordinate(haodian))
        let raw = CoordinateConverter.applyingGCJ02Offset(haodian)
        let canonical = try XCTUnwrap(space.canonicalSearchCoordinate(raw, countryCode: "CN"))
        XCTAssertEqual(canonical.latitude, haodian.latitude, accuracy: 0.000001)
    }

    func testSearchAndRendererCanUseDifferentDatums() async throws {
        let space = MapKitCoordinateSpace(renderStyles: [.standard], fetchSample: { self.sample($0, render: .wgs84) })
        try await space.prepare(near: haodian)
        XCTAssertEqual(space.profile(for: haodian).searchOutput, .gcj02)
        XCTAssertEqual(space.profile(for: haodian).renderInput, .wgs84)
        XCTAssertEqual(try XCTUnwrap(space.mapCoordinate(haodian)).longitude, haodian.longitude)
        XCTAssertNil(space.mapCoordinate(haodian, style: .imagery), "Unverified style must fail closed")
    }

    func testCoastIsUnresolvedUntilCountryRoutesCalibration() async throws {
        let coast = CLLocationCoordinate2D(latitude: 24.539495, longitude: 118.13709)
        XCTAssertEqual(MapKitCoordinateSpace.area(for: coast), .unresolved)
        let space = MapKitCoordinateSpace(renderStyles: [.standard], resolveCountry: { _ in "CN" }, fetchSample: { self.sample($0) })
        XCTAssertNil(space.canonicalSearchCoordinate(coast))
        try await space.prepare(near: coast, countryCode: "CN")
        let canonical = try XCTUnwrap(space.canonicalSearchCoordinate(coast, countryCode: "CN"))
        XCTAssertNotEqual(canonical.longitude, coast.longitude)
        XCTAssertNotNil(space.mapCoordinate(canonical), "Country routing survives canonical conversion on reclaimed land")
        for c in [CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978),
                  .init(latitude: 27.7172, longitude: 85.324), .init(latitude: 47.918, longitude: 106.917)] {
            XCTAssertEqual(MapKitCoordinateSpace.area(for: c), .wgs84)
        }
        XCTAssertEqual(MapKitCoordinateSpace.area(for: .init(latitude: 22.28, longitude: 114.16), countryCode: "CN"), .calibrated(.hongKong))
    }

    func testAmapCoastRoutingStillRequiresIndependentDatum() async throws {
        let coast = CLLocationCoordinate2D(latitude: 24.539495, longitude: 118.13709)
        let space = MapKitCoordinateSpace(renderStyles: [.standard], fetchSample: { self.sample($0) })
        XCTAssertEqual(MapKitCoordinateSpace.area(for: coast), .unresolved)
        space.registerMainlandProviderCoordinate(coast)
        XCTAssertNil(space.mapCoordinate(coast))
        try await space.prepare(near: haodian)
        XCTAssertNotNil(space.mapCoordinate(coast))
        let seoul = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        space.registerMainlandProviderCoordinate(seoul)
        XCTAssertEqual(try XCTUnwrap(space.mapCoordinate(seoul)).longitude, seoul.longitude)
    }

    func testFujianAndShenzhenDoNotFallInsideSpecialRegionRectangles() {
        for c in [CLLocationCoordinate2D(latitude: 25.498, longitude: 119.79),
                  .init(latitude: 25.408, longitude: 119.597), .init(latitude: 22.51, longitude: 114.05)] {
            XCTAssertEqual(MapKitCoordinateSpace.area(for: c), .calibrated(.mainland))
            XCTAssertTrue(CoordinateConverter.isInsideChinaMainland(c, countryCode: "CN"))
        }
        let macau = MapKitCoordinateSpace.anchors(for: .macau)[0].coordinate
        XCTAssertEqual(MapKitCoordinateSpace.area(for: macau), .calibrated(.macau))
        XCTAssertFalse(CoordinateConverter.isInsideChinaMainland(macau, countryCode: "CN"))
        let taipei = CLLocationCoordinate2D(latitude: 25.033, longitude: 121.5654)
        XCTAssertEqual(MapKitCoordinateSpace.area(for: taipei, countryCode: "CN"), .wgs84)
        XCTAssertFalse(CoordinateConverter.isInsideChinaMainland(taipei, countryCode: "CN"))
    }

    func testConflictingOrDuplicateAnchorsDoNotActivateProfile() {
        let anchors = MapKitCoordinateSpace.anchors(for: .mainland)
        let conflict = MapKitCoordinateSpace.classify(anchors: anchors,
            samples: [sample(anchors[0]), sample(anchors[1], search: .wgs84)], at: Date())
        XCTAssertEqual(conflict.searchOutput, .unknown)
        let duplicate = MapKitCoordinateSpace.classify(anchors: anchors,
            samples: [sample(anchors[0]), sample(anchors[0])], at: Date())
        XCTAssertEqual(duplicate.searchOutput, .unknown)
        XCTAssertEqual(duplicate.renderInput, .unknown)
    }

    func testCancellingOneWaiterDoesNotEraseSharedSuccess() async throws {
        var calls = 0
        let space = MapKitCoordinateSpace(renderStyles: [.standard], fetchSample: { anchor in
            calls += 1
            try await Task.sleep(for: .milliseconds(20))
            return self.sample(anchor)
        })
        let cancelled = Task { try await space.prepare(near: haodian) }
        await Task.yield()
        let remaining = Task { try await space.prepare(near: haodian) }
        cancelled.cancel()
        try await remaining.value
        _ = try? await cancelled.value
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(space.profile(for: haodian).searchOutput, .gcj02)
        XCTAssertNotNil(space.mapCoordinate(haodian))
    }

    func testCameraEchoDoesNotBecomeAnotherProgrammaticMove() async throws {
        let space = MapKitCoordinateSpace(renderStyles: [.standard], fetchSample: { self.sample($0) })
        try await space.prepare(near: haodian)
        let presentation = MapCoordinatePresentation()
        presentation.request(.region(.init(center: haodian, span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1))), fallback: haodian, space: space)
        let panned = CoordinateConverter.applyingGCJ02Offset(.init(latitude: 31.79, longitude: 113.76))
        let raw = MapCameraPosition.region(.init(center: panned, span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        let canonical = try XCTUnwrap(presentation.receive(raw, space: space))
        presentation.request(canonical, fallback: haodian, space: space)
        XCTAssertEqual(presentation.position, raw)
        XCTAssertEqual(presentation.target?.longitude, haodian.longitude, "Echo must not reset the gesture's preparation target")
    }

    func testExpiryAndInvalidationFreezePresentedCamera() async throws {
        var clock = Date()
        let space = MapKitCoordinateSpace(now: { clock }, renderStyles: [.standard], fetchSample: { self.sample($0) })
        try await space.prepare(near: haodian)
        let camera = MapCameraPosition.region(.init(center: haodian, span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        let presentation = MapCoordinatePresentation()
        presentation.request(camera, fallback: haodian, space: space)
        let rendered = try XCTUnwrap(presentation.position.region?.center)
        XCTAssertNotEqual(rendered.longitude, haodian.longitude)
        clock = clock.addingTimeInterval(301)
        XCTAssertNil(space.mapCoordinate(haodian))
        _ = presentation.recover(camera, fallback: haodian, space: space)
        XCTAssertEqual(presentation.position.region?.center.longitude, rendered.longitude)
        space.invalidate()
        _ = presentation.recover(camera, fallback: haodian, space: space)
        XCTAssertEqual(presentation.position.region?.center.longitude, rendered.longitude)
        let other = CLLocationCoordinate2D(latitude: 22.282, longitude: 114.16128)
        presentation.request(.region(.init(center: other, span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1))), fallback: other, space: space)
        XCTAssertNil(presentation.pendingUserRegion, "A newer programmatic selection invalidates old pending pans")
        XCTAssertEqual(presentation.target?.latitude, other.latitude)
        XCTAssertEqual(presentation.position.region?.center.longitude, rendered.longitude, "Unknown target cannot jump the raw camera")
    }
}
