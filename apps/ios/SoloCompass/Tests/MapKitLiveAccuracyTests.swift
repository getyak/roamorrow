import XCTest
import MapKit
import UIKit
@testable import SoloCompass

/// Explicit public-landmark acceptance, separate from deterministic CI tests.
/// No GPS request, keys, user account, or precise user-location logging.
@MainActor
final class MapKitLiveAccuracyTests: XCTestCase, MKMapViewDelegate {
    func testPublicAnchorsAndNativeAnnotationAlignment() async throws {
        guard ProcessInfo.processInfo.environment["SOLO_MAP_LIVE_VERIFY"] == "1" else {
            throw XCTSkip("Opt in with SOLO_MAP_LIVE_VERIFY=1; live Apple Maps is not a deterministic CI dependency")
        }
        guard #available(iOS 18.0, *), !MapKitCoordinateSpace.validatedStyles.isEmpty else {
            throw XCTSkip("This runtime has no validated render compatibility receipt")
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        let map = MKMapView(frame: scene.coordinateSpace.bounds)
        map.delegate = self
        controller.view = map
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible(); map.delegate = nil }
        var receipts: [[String: Any]] = []
        for region in [MapKitCoordinateSpace.Region.mainland, .hongKong, .macau] {
            let anchor = try XCTUnwrap(MapKitCoordinateSpace.anchors(for: region).first)
            let space = MapKitCoordinateSpace()
            try await space.prepare(near: anchor.coordinate)
            let profile = space.profile(for: anchor.coordinate)
            XCTAssertNotEqual(profile.searchOutput, .unknown)
            XCTAssertNotEqual(profile.renderInput, .unknown)
            let item = try await MapKitCoordinateSpace.fetchNativeMapItem(anchor)
            let raw = item.placemark.coordinate
            let canonical = try XCTUnwrap(space.canonicalSearchCoordinate(raw, countryCode: item.placemark.isoCountryCode))
            let referenceResidual = CLLocation(latitude: canonical.latitude, longitude: canonical.longitude)
                .distance(from: .init(latitude: anchor.latitude, longitude: anchor.longitude))
            XCTAssertLessThanOrEqual(referenceResidual, 120, "Independent reference classifies datum, not entrance precision")
            for style in MapKitCoordinateSpace.Style.allCases {
                switch style {
                case .standard: map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
                case .imagery: map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
                case .hybrid: map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat)
                }
                map.removeAnnotations(map.annotations)
                let native = try XCTUnwrap(MKMapItemAnnotation(mapItem: item))
                let custom = MKPointAnnotation()
                custom.coordinate = try XCTUnwrap(space.mapCoordinate(canonical, style: style))
                custom.title = "Canonical → MapKit"
                map.setRegion(.init(center: native.coordinate, latitudinalMeters: 800, longitudinalMeters: 800), animated: false)
                map.addAnnotations([native, custom])
                try await Task.sleep(for: .seconds(3))
                map.layoutIfNeeded()
                let nativeView = try XCTUnwrap(map.view(for: native))
                let customView = try XCTUnwrap(map.view(for: custom))
                let scale = window.screen.scale
                let physicalPixels = hypot(nativeView.center.x - customView.center.x, nativeView.center.y - customView.center.y) * scale
                XCTAssertLessThanOrEqual(physicalPixels, 1, "Native/custom alignment uses physical pixels")
                let back = try XCTUnwrap(space.canonicalMapCoordinate(custom.coordinate, style: style))
                XCTAssertEqual(back.latitude, canonical.latitude, accuracy: 0.000001)
                XCTAssertEqual(back.longitude, canonical.longitude, accuracy: 0.000001)
                receipts.append(["region":region.rawValue, "style":style.rawValue, "anchor":anchor.id,
                    "reference":anchor.reference, "referenceResidualMeters":referenceResidual,
                    "searchOutput":profile.searchOutput.rawValue, "renderInput":profile.renderInput.rawValue,
                    "nativeCustomPhysicalPixels":physicalPixels, "screenScale":scale,
                    "runtime":ProcessInfo.processInfo.operatingSystemVersionString, "api":"MKMapItemAnnotation/custom-MKAnnotation-flat-v1"])
                let image = UIGraphicsImageRenderer(bounds: map.bounds).image { _ in map.drawHierarchy(in: map.bounds, afterScreenUpdates: true) }
                let attachment = XCTAttachment(image: image)
                attachment.name = "native-alignment-\(region.rawValue)-\(style.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        // Also exercise the production location-search boundary at the user's
        // concrete town, independently of the landmark identities above.
        let results = try await LocationSearchService().search("湖北省随州市广水市郝店镇人民政府")
        let town = try XCTUnwrap(results.first)
        let space = MapKitCoordinateSpace.shared
        try await space.prepare(near: town.placemark.coordinate, countryCode: town.placemark.isoCountryCode)
        XCTAssertNotNil(space.canonicalSearchCoordinate(town.placemark.coordinate, countryCode: town.placemark.isoCountryCode))
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: receipts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "public-anchor-receipts"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        view.centerOffset = .zero
        let isNative: Bool
        if #available(iOS 18.0, *) { isNative = annotation is MKMapItemAnnotation } else { isNative = false }
        view.backgroundColor = isNative ? .systemBlue : .clear
        view.layer.borderColor = UIColor.systemRed.cgColor
        view.layer.borderWidth = isNative ? 0 : 3
        view.layer.cornerRadius = 10
        view.displayPriority = .required
        view.collisionMode = .none
        return view
    }
}
