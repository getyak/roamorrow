import UIKit
import MapKit
import CoreLocation

/// External navigation app target. Listed in the user-facing picker.
@MainActor
public enum NavigationApp: String, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps
    case amap

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleMaps:  return NSLocalizedString("location.openIn.apple",  comment: "Apple Maps menu item")
        case .googleMaps: return NSLocalizedString("location.openIn.google", comment: "Google Maps menu item")
        case .amap:       return NSLocalizedString("location.openIn.amap",   comment: "Amap (Gaode) menu item")
        }
    }

    /// Probe URL used with `canOpenURL` to detect installation.
    /// Apple Maps returns nil — it is always assumed installed.
    var probeURL: URL? {
        switch self {
        case .appleMaps:  return nil
        case .googleMaps: return URL(string: "comgooglemaps://")
        case .amap:       return URL(string: "iosamap://")
        }
    }
}

/// Builds deep-link URLs and opens the user's preferred navigation app for a coordinate.
///
/// All URL construction is pure and unit-testable. Side-effecting `open` calls go through
/// `UIApplication.shared.open` (or `MKMapItem.openInMaps` for Apple Maps).
@MainActor
public enum NavigationLauncher {

    /// Apps available on the current device, in canonical display order.
    /// `canOpen` is injectable for unit tests.
    public static func availableApps(
        canOpen: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }
    ) -> [NavigationApp] {
        NavigationApp.allCases.filter { app in
            guard let url = app.probeURL else { return true }
            return canOpen(url)
        }
    }

    /// The single app to launch directly, or nil when the caller should present
    /// a picker. With exactly one installed maps app (the common case — only
    /// Apple Maps) a one-option picker is a pointless extra tap, so callers can
    /// skip straight to launching it.
    public static func soleApp(
        canOpen: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }
    ) -> NavigationApp? {
        let apps = availableApps(canOpen: canOpen)
        return apps.count == 1 ? apps.first : nil
    }

    /// Deep-link URL for the given app. Returns nil for Apple Maps (use `open(app:...)` instead,
    /// which dispatches to `MKMapItem.openInMaps`).
    public static func url(
        for app: NavigationApp,
        coordinate: CLLocationCoordinate2D,
        name: String?
    ) -> URL? {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        switch app {
        case .appleMaps:
            return nil
        case .googleMaps:
            var components = URLComponents()
            components.scheme = "comgooglemaps"
            components.host = ""
            components.queryItems = [.init(name: "daddr", value: "\(lat),\(lon)"), .init(name: "q", value: name ?? ""),
                                     .init(name: "directionsmode", value: "walking")]
            return components.url
        case .amap:
            // Amap: dev=1 requests conversion of GPS/WGS84 input. dev=0
            // declares already-encrypted GCJ-02 input and would shift the goal.
            // t=2 selects walking mode.
            var components = URLComponents()
            components.scheme = "iosamap"
            components.host = "path"
            components.queryItems = [.init(name: "sourceApplication", value: "SoloCompass"),
                                     .init(name: "dlat", value: String(lat)), .init(name: "dlon", value: String(lon)),
                                     .init(name: "dname", value: name ?? ""), .init(name: "dev", value: "1"), .init(name: "t", value: "2")]
            return components.url
        }
    }

    /// Launches walking directions to an experience in the traveler's chosen maps app.
    public static func open(
        app: NavigationApp,
        coordinate: CLLocationCoordinate2D,
        name: String?
    ) {
        if app == .appleMaps {
            let placemark = MKPlacemark(coordinate: coordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            return
        }
        guard let url = url(for: app, coordinate: coordinate, name: name) else { return }
        UIApplication.shared.open(url)
    }
}
