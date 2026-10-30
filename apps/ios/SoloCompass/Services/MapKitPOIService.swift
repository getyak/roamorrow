import Foundation
import CoreLocation
import MapKit
import Observation

/// Tertiary POI data source backed by Apple's `MKLocalSearch`. Free, native,
/// key-less — used by the deep-dive enrichment pipeline to thicken the signal
/// set for each place beyond what OSM/Overpass exposes.
///
/// Returns `OverpassService.POI` instances (the canonical POI shape across the
/// app) so results merge through the same dedupe path as Overpass + Foursquare.
/// Apple's `MKMapItem` exposes `pointOfInterestCategory`, `phoneNumber`, and
/// `url`; we map the category to an OSM-style `amenity`/`tourism`/`leisure`
/// tag so `OverpassService.category(for:)` keeps working unchanged. Hours and
/// rating are not part of the public MapItem surface, so those stay nil here
/// (Foursquare is the rating/hours source).
///
/// `@MainActor` because `MKLocalSearch` completion is dispatched on the main
/// queue and the rest of the explore pipeline is main-actor-bound.
@MainActor
@Observable
public final class MapKitPOIService {
    /// Failures that can occur while searching nearby places via MapKit.
    public enum MapKitPOIError: Error, LocalizedError {
        case searchFailed(String)

        public var errorDescription: String? {
            switch self {
            case .searchFailed(let msg):
                return msg
            }
        }
    }

    public private(set) var isFetching: Bool = false

    public init() {}

    /// Search Apple Maps POIs within `radiusMeters` of `coordinate`. `category`
    /// narrows the `MKPointOfInterestCategory` filter when provided; otherwise
    /// the search returns the full POI set in the region. Best-effort — returns
    /// an empty array rather than throwing on an empty result so callers can
    /// treat it as a soft enrichment source.
    public func fetchPOIs(
        near coordinate: CLLocationCoordinate2D,
        radiusMeters: Int = 1000,
        category: ExperienceCategory? = nil
    ) async throws -> [OverpassService.POI] {
        try Task.checkCancellation()
        isFetching = true
        defer { isFetching = false }

        let space = MapKitCoordinateSpace.shared
        try await space.prepare(near: coordinate)
        guard let searchCenter = space.searchCoordinate(coordinate) else { throw MapKitCoordinateSpace.CalibrationError.unavailable }
        let request = MKLocalPointsOfInterestRequest(
            center: searchCenter,
            radius: CLLocationDistance(radiusMeters)
        )
        if let category, let filter = Self.poiFilter(for: category) {
            request.pointOfInterestFilter = filter
        }

        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await Self.performSearch(search)
        } catch {
            try Task.checkCancellation()
            // An empty-result search surfaces as an error on some OS versions;
            // treat that as "no POIs" rather than a hard failure.
            let ns = error as NSError
            if ns.domain == MKError.errorDomain, ns.code == MKError.placemarkNotFound.rawValue {
                return []
            }
            throw MapKitPOIError.searchFailed(String(describing: error))
        }

        for item in response.mapItems {
            try Task.checkCancellation()
            try? await space.prepare(near: item.placemark.coordinate, countryCode: item.placemark.isoCountryCode)
        }
        try Task.checkCancellation()
        return Self.withinRadius(response.mapItems.compactMap { Self.poi(from: $0) }, center: coordinate, meters: radiusMeters)
    }

    /// Free-text POI search — the missing piece the local card filter can't do.
    ///
    /// `MKLocalPointsOfInterestRequest` (used by `fetchPOIs`) can only return
    /// "everything of category X near a point"; it takes no query string. To
    /// answer "find me izakayas" the user must be able to *type* — that's what
    /// `MKLocalSearch.Request.naturalLanguageQuery` is for. We bias the results
    /// toward the user's current map region so "coffee" surfaces nearby cafes
    /// rather than a city across the country.
    ///
    /// Best-effort: an empty MapKit result (which surfaces as an `MKError` on
    /// some OS versions) degrades to `[]` rather than throwing, so the caller
    /// can render an honest "no results" state instead of an error banner.
    ///
    /// - Parameters:
    ///   - query: The raw, user-typed search string. Whitespace-trimmed here;
    ///     an empty query short-circuits to `[]` (no wasted network call).
    ///   - coordinate: Center of the region to bias results toward.
    ///   - radiusMeters: Half-span of the search region (default 20 km — wide
    ///     enough to cover a city, tight enough to stay locally relevant).
    public func search(
        query: String,
        near coordinate: CLLocationCoordinate2D,
        radiusMeters: Int = 20_000
    ) async throws -> [OverpassService.POI] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        try Task.checkCancellation()

        isFetching = true
        defer { isFetching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let space = MapKitCoordinateSpace.shared
        try await space.prepare(near: coordinate)
        guard let searchCenter = space.searchCoordinate(coordinate) else { throw MapKitCoordinateSpace.CalibrationError.unavailable }
        request.region = MKCoordinateRegion(
            center: searchCenter,
            latitudinalMeters: CLLocationDistance(radiusMeters * 2),
            longitudinalMeters: CLLocationDistance(radiusMeters * 2)
        )
        request.resultTypes = .pointOfInterest
        if #available(iOS 18.0, macOS 15.0, *) { request.regionPriority = .required }

        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await Self.performSearch(search)
        } catch {
            try Task.checkCancellation()
            let ns = error as NSError
            if ns.domain == MKError.errorDomain, ns.code == MKError.placemarkNotFound.rawValue {
                return []
            }
            throw MapKitPOIError.searchFailed(String(describing: error))
        }

        for item in response.mapItems {
            try Task.checkCancellation()
            try? await space.prepare(near: item.placemark.coordinate, countryCode: item.placemark.isoCountryCode)
        }
        try Task.checkCancellation()
        return Self.withinRadius(response.mapItems.compactMap { Self.poi(from: $0) }, center: coordinate, meters: radiusMeters)
    }

    /// MKLocalSearch exposes explicit cancellation. Keep the non-Sendable SDK
    /// object behind a main-actor owner; cancellation can originate on any
    /// executor and is marshalled back to that actor without an unsafe capture.
    @MainActor
    private final class SearchOperation {
        let search: MKLocalSearch
        init(_ search: MKLocalSearch) { self.search = search }
        func cancel() { search.cancel() }
    }

    private static func performSearch(_ search: MKLocalSearch) async throws -> MKLocalSearch.Response {
        let operation = SearchOperation(search)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            do {
                let response = try await operation.search.start()
                try Task.checkCancellation()
                return response
            } catch {
                try Task.checkCancellation()
                throw error
            }
        } onCancel: {
            Task { @MainActor in operation.cancel() }
        }
    }

    // MARK: - Mapping

    /// Convert an `MKMapItem` into an `OverpassService.POI`. Returns nil when
    /// the item has no name or usable coordinate.
    static func poi(from item: MKMapItem) -> OverpassService.POI? {
        let placemark = item.placemark
        let name = item.name ?? placemark.name
        guard let name, !name.isEmpty else { return nil }
        guard let coord = MapKitCoordinateSpace.shared.canonicalSearchCoordinate(placemark.coordinate, countryCode: placemark.isoCountryCode) else { return nil }
        guard CLLocationCoordinate2DIsValid(coord) else { return nil }

        var tags: [String: String] = ["name": name, "source": "mapkit"]
        if let osmTag = item.pointOfInterestCategory.flatMap(osmTag(for:)) {
            tags[osmTag.key] = osmTag.value
        }
        if let phone = item.phoneNumber, !phone.isEmpty {
            tags["phone"] = phone
        }
        if let url = item.url?.absoluteString, !url.isEmpty {
            tags["website"] = url
        }
        // A street-level address hint when the placemark carries one — helps
        // the AI write accurate howTo orientation steps.
        if let thoroughfare = placemark.thoroughfare {
            let withNumber = [placemark.subThoroughfare, thoroughfare]
                .compactMap { $0 }
                .joined(separator: " ")
            tags["addr"] = withNumber.isEmpty ? thoroughfare : withNumber
        }

        let stableId = stableInt64Id(forMapItem: item, name: name, coordinate: coord)
        return OverpassService.POI(
            osmId: stableId,
            name: name,
            nameEn: nil,
            lat: coord.latitude,
            lon: coord.longitude,
            tags: tags
        )
    }

    static func withinRadius(_ pois: [OverpassService.POI], center: CLLocationCoordinate2D, meters: Int) -> [OverpassService.POI] {
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return pois.filter { poi in
            let point = CLLocationCoordinate2D(latitude: poi.lat, longitude: poi.lon)
            return CLLocationCoordinate2DIsValid(point) && poi.lat.isFinite && poi.lon.isFinite
                && origin.distance(from: CLLocation(latitude: poi.lat, longitude: poi.lon)) <= Double(max(0, meters))
        }
    }

    /// Map an `MKPointOfInterestCategory` to an OSM-style tag (key, value) so
    /// `OverpassService.category(for:)` resolves it to the right bucket.
    static func osmTag(for category: MKPointOfInterestCategory) -> (key: String, value: String)? {
        switch category {
        case .cafe, .bakery:
            return ("amenity", "cafe")
        case .restaurant, .foodMarket:
            return ("amenity", "restaurant")
        case .nightlife, .brewery, .winery:
            return ("amenity", "bar")
        case .library:
            return ("amenity", "library")
        case .museum:
            return ("tourism", "museum")
        case .nationalPark, .park:
            return ("leisure", "park")
        case .beach:
            return ("natural", "beach")
        case .fitnessCenter:
            return ("leisure", "fitness_centre")
        case .aquarium, .zoo:
            return ("tourism", "zoo")
        default:
            return nil
        }
    }

    /// Build an `MKPointOfInterestFilter` that narrows the search to the
    /// categories matching one of our `ExperienceCategory` buckets. Returns nil
    /// for buckets with no clean MapKit equivalent (caller then searches all).
    static func poiFilter(for category: ExperienceCategory) -> MKPointOfInterestFilter? {
        let categories: [MKPointOfInterestCategory]
        switch category {
        case .coffee:    categories = [.cafe, .bakery]
        case .food:      categories = [.restaurant, .foodMarket]
        case .nightlife: categories = [.nightlife, .brewery, .winery]
        case .work:      categories = [.library]
        case .culture:   categories = [.museum]
        case .nature:    categories = [.nationalPark, .park, .beach, .aquarium, .zoo]
        case .wellness:  categories = [.fitnessCenter]
        case .hidden:    return nil
        }
        return MKPointOfInterestFilter(including: categories)
    }

    /// Hash an Apple Maps item into a stable `Int64`. Apple has no public stable
    /// identifier, so we hash name + rounded coordinate. The high marker bit
    /// (0x2000…) is distinct from the OSM range and Foursquare's 0x4000… bit,
    /// so MapKit ids never collide with the other two sources.
    static func stableInt64Id(
        forMapItem item: MKMapItem,
        name: String,
        coordinate: CLLocationCoordinate2D
    ) -> Int64 {
        // 4-decimal coordinate (~11 m) keeps the id stable across runs even if
        // Apple jitters the coordinate slightly.
        let rLat = (coordinate.latitude * 10_000).rounded() / 10_000
        let rLon = (coordinate.longitude * 10_000).rounded() / 10_000
        let seed = "\(name)|\(rLat)|\(rLon)"
        var hash: UInt64 = 1469598103934665603 // FNV offset basis
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211 // FNV prime
        }
        let positive = hash & 0x7FFF_FFFF_FFFF_FFFF
        return Int64(bitPattern: positive | 0x2000_0000_0000_0000)
    }
}
