import MapKit

/// Forward-geocoding search wrapping MKLocalSearch.
/// All methods are `@MainActor` to keep MKLocalSearch on the main thread
/// (required by MapKit) and eliminate any sendability friction.
@MainActor
final class LocationSearchService {

    private var activeSearch: MKLocalSearch?
    private var calibrationTask: Task<Void, Never>?

    /// Search for locations by natural-language query.
    /// Cancels any in-flight search before starting a new one.
    /// - Throws: MKLocalSearch errors (network, no results → empty array)
    func search(_ query: String) async throws -> [MKMapItem] {
        activeSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        activeSearch = search

        do {
            let response = try await search.start()
            calibrationTask?.cancel()
            calibrationTask = Task { @MainActor in
                for item in response.mapItems.prefix(5) {
                    guard !Task.isCancelled else { return }
                    try? await MapKitCoordinateSpace.shared.prepare(near: item.placemark.coordinate, countryCode: item.placemark.isoCountryCode)
                }
            }
            try Task.checkCancellation()
            return response.mapItems
        } catch MKError.placemarkNotFound {
            return []
        } catch MKError.loadingThrottled {
            // Throttled → return empty rather than propagating; the UI will retry on next keystroke.
            return []
        }
        // Other errors (network, cancelled) propagate to the caller.
    }

    func cancelAll() {
        activeSearch?.cancel()
        activeSearch = nil
        calibrationTask?.cancel()
        calibrationTask = nil
    }
}
