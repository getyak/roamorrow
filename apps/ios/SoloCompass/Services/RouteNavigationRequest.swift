import Foundation

// MARK: - RouteNavigationRequest

/// Unified "start this route on the map" navigation request (R2-03).
///
/// `RouteDetailView` is presented from many sites — the map's route sheet, the
/// chat's pinned route header, walked/requested/discovered route lists inside
/// Me / Settings / chat surfaces. Only the map host can actually draw the
/// polyline and fly the camera, and it must first dismiss whatever surface is
/// presenting the detail (Me sheet, chat workspace, route sheets). Sites that
/// pass an explicit `onStartRoute` callback keep using it (the main map does);
/// every other site posts this request and CompassMapView consumes it.
public enum RouteNavigationRequest {
    /// Posted on `NotificationCenter.default` with the `Route` under
    /// `"route"` in `userInfo`.
    public static let didRequestStart = Notification.Name("SoloCompass.RouteNavigationRequest.didRequestStart")

    /// Ask the map host to draw `route` on the map and surface it.
    /// Call from the main actor; the consumer reads the Route synchronously.
    public static func requestStart(route: Route) {
        NotificationCenter.default.post(
            name: didRequestStart,
            object: nil,
            userInfo: ["route": route]
        )
    }

    /// Extract a posted route from a notification.
    public static func route(from notification: Notification) -> Route? {
        notification.userInfo?["route"] as? Route
    }

    // MARK: - City selection request

    /// Posted on `NotificationCenter.default` when a screen that needs a city
    /// context asks the map host to open the CITY PICKER (round 2 review,
    /// closure 2). No payload — the map host owns the picker and the current
    /// city; the poster never switches cities on its own.
    ///
    /// Contract for the root-owned CompassMapView handler: on receipt, dismiss
    /// presenting Me/chat/route/settings surfaces, then present the existing
    /// city picker (`viewModel.isShowingCityPicker` / the same first-launch
    /// picker entry the map already uses). This event never draws routes and
    /// never invents a city.
    public static let didRequestCitySelection =
        Notification.Name("SoloCompass.RouteNavigationRequest.didRequestCitySelection")

    /// Ask the map host to surface the city picker.
    public static func requestCitySelection() {
        NotificationCenter.default.post(name: didRequestCitySelection, object: nil)
    }
}
