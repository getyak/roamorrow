import XCTest
import MapKit
import UIKit
@testable import SoloCompass

/// Explicit public-landmark acceptance, separate from deterministic CI tests.
/// No GPS request, keys, user account, or precise user-location logging.
@MainActor
final class MapKitLiveAccuracyTests: XCTestCase, MKMapViewDelegate {
    private var renderPasses = 0
    private var fullyRenderedPasses = 0

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        renderPasses += 1
        if fullyRendered { fullyRenderedPasses += 1 }
        print("PUBLIC_MAP_RENDER", renderPasses, "fully", fullyRendered)
    }

    private func inspectCandidates(_ anchor: MapKitCoordinateSpace.Anchor) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = anchor.query
        request.resultTypes = .pointOfInterest
        request.region = .init(center: anchor.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
        if #available(iOS 18.0, *) { request.regionPriority = .required }
        let search = MKLocalSearch(request: request)
        defer { withExtendedLifetime(search) {} }
        do {
            let response = try await search.start()
            print("PUBLIC_ANCHOR_CANDIDATES", anchor.id, response.mapItems.prefix(8).map { $0.name ?? "nil" })
        } catch {
            let ns = error as NSError
            print("PUBLIC_ANCHOR_QUERY_ERROR", anchor.id, String(reflecting: error), ns.domain, ns.code)
        }
    }

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
            print("PUBLIC_ANCHOR_STAGE region", region.rawValue, "area", String(describing: MapKitCoordinateSpace.area(for: anchor.coordinate)))
            let space = MapKitCoordinateSpace(fetchSample: { publicAnchor in
                print("PUBLIC_ANCHOR_STAGE fetching", publicAnchor.id)
                do {
                    let sample = try await MapKitCoordinateSpace.fetchNativeSample(publicAnchor)
                    print("PUBLIC_ANCHOR_STAGE fetched", publicAnchor.id)
                    return sample
                } catch {
                    let ns = error as NSError
                    print("PUBLIC_ANCHOR_STAGE error", publicAnchor.id, String(reflecting: error), ns.domain, ns.code)
                    if case MapKitCoordinateSpace.CalibrationError.identityUnverified = error {
                        await self.inspectCandidates(publicAnchor)
                    }
                    throw error
                }
            })
            do { try await space.prepare(near: anchor.coordinate) }
            catch {
                XCTFail("Public anchor calibration failed: \(String(reflecting: error))")
                return
            }
            let profile = space.profile(for: anchor.coordinate)
            XCTAssertNotEqual(profile.searchOutput, .unknown)
            XCTAssertNotEqual(profile.renderInput, .unknown)
            let item = try await MapKitCoordinateSpace.fetchNativeMapItem(anchor)
            let raw = item.placemark.coordinate
            let canonical = try XCTUnwrap(space.canonicalSearchCoordinate(raw, countryCode: item.placemark.isoCountryCode))
            let referenceResidual = CLLocation(latitude: canonical.latitude, longitude: canonical.longitude)
                .distance(from: .init(latitude: anchor.latitude, longitude: anchor.longitude))
            XCTAssertLessThanOrEqual(referenceResidual, 120, "Independent reference classifies datum, not entrance precision")
            for style in MapKitCoordinateSpace.validatedStyles.sorted(by: { $0.rawValue < $1.rawValue }) {
                let previousRender = renderPasses
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
                // Standard tiles are inspected in the saved image. The SDK
                // does not guarantee a new fullyRendered=true event per style.
                // Imagery/hybrid remain outside the production compatibility
                // receipt until their actual tile rendering is independently verified.
                let deadline = Date().addingTimeInterval(8)
                while renderPasses <= previousRender, Date() < deadline {
                    try await Task.sleep(for: .milliseconds(100))
                }
                try await Task.sleep(for: .seconds(2))
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
                    "nativeCustomPhysicalPixels":physicalPixels, "screenScale":scale, "renderPasses":renderPasses, "fullyRenderedPasses":fullyRenderedPasses,
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
