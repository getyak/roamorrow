import SwiftUI
import MapKit
import Observation

extension MapKitCoordinateSpace {
    func mapRegion(_ canonical: MKCoordinateRegion, style: Style = .standard) -> MKCoordinateRegion? {
        guard let center = mapCoordinate(canonical.center, style: style) else { return nil }
        return .init(center: center, span: canonical.span)
    }

    func canonicalRegion(_ raw: MKCoordinateRegion, style: Style = .standard) -> MKCoordinateRegion? {
        guard let center = canonicalMapCoordinate(raw.center, style: style) else { return nil }
        return .init(center: center, span: raw.span)
    }

    /// The ViewModel keeps a WGS84 camera; MapKit owns its presentation space.
    func mapPosition(_ canonical: MapCameraPosition, style: Style = .standard) -> MapCameraPosition? {
        if let region = canonical.region { return mapRegion(region, style: style).map(MapCameraPosition.region) }
        if let camera = canonical.camera {
            guard let center = mapCoordinate(camera.centerCoordinate, style: style) else { return nil }
            return .camera(.init(centerCoordinate: center, distance: camera.distance, heading: camera.heading, pitch: camera.pitch))
        }
        return canonical
    }

    func canonicalPosition(_ raw: MapCameraPosition, style: Style = .standard) -> MapCameraPosition? {
        if let region = raw.region { return canonicalRegion(region, style: style).map(MapCameraPosition.region) }
        if let camera = raw.camera {
            guard let center = canonicalMapCoordinate(camera.centerCoordinate, style: style) else { return nil }
            return .camera(.init(centerCoordinate: center, distance: camera.distance, heading: camera.heading, pitch: camera.pitch))
        }
        return raw
    }
}

/// Owns the camera actually handed to MapKit. Unknown calibration retains that
/// camera instead of accidentally sending a canonical WGS84 camera as raw input.
@MainActor @Observable
final class MapCoordinatePresentation {
    var position: MapCameraPosition = .automatic
    private(set) var target: CLLocationCoordinate2D?
    private(set) var pendingUserRegion: MKCoordinateRegion?
    private var userMoved = false

    func request(_ canonical: MapCameraPosition, fallback: CLLocationCoordinate2D,
                 space: MapKitCoordinateSpace, style: MapKitCoordinateSpace.Style = .standard) {
        pendingUserRegion = nil
        userMoved = false
        target = canonical.region?.center ?? canonical.camera?.centerCoordinate ?? fallback
        if let rendered = space.mapPosition(canonical, style: style) { position = rendered }
    }
    func receive(_ raw: MapCameraPosition) {
        position = raw
        if raw.positionedByUser { userMoved = true }
    }
    func finish(_ raw: MKCoordinateRegion, space: MapKitCoordinateSpace,
                style: MapKitCoordinateSpace.Style = .standard) -> MKCoordinateRegion? {
        let moved = userMoved
        userMoved = false
        // A programmatic/automatic camera settling must not replace a pending
        // city selection with an unverified viewport from the previous city.
        if moved { target = raw.center }
        if let canonical = space.canonicalRegion(raw, style: style) { return canonical }
        if moved { pendingUserRegion = raw }
        return nil
    }
    func recover(_ canonical: MapCameraPosition, fallback: CLLocationCoordinate2D,
                 space: MapKitCoordinateSpace, style: MapKitCoordinateSpace.Style = .standard) -> MKCoordinateRegion? {
        if let pending = pendingUserRegion {
            guard let result = space.canonicalRegion(pending, style: style) else { return nil }
            pendingUserRegion = nil
            return result
        }
        if let rendered = space.mapPosition(canonical, style: style) { position = rendered }
        return nil
    }
}

/// Unknown positions remain a usable list; retry is explicit and bounded.
struct MapCoordinateStatus: View {
    let retry: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("map.coordinates.unavailable", comment: "Unverified map coordinates"))
                .font(.caption)
            Button(NSLocalizedString("common.retry", comment: "Retry"), action: retry)
                .font(.caption.weight(.semibold))
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
