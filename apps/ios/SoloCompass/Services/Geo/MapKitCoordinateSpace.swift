import Foundation
import CoreLocation
import MapKit
import Observation

/// Session-scoped boundary between canonical WGS84 and the two MapKit APIs.
/// Country/geometry route verification; neither establishes a coordinate datum.
@MainActor @Observable
final class MapKitCoordinateSpace {
    enum Datum: String, Sendable { case wgs84, gcj02, unknown }
    enum Region: String, Sendable { case mainland, hongKong, macau }
    enum Style: String, CaseIterable, Sendable { case standard, imagery, hybrid }
    enum Area: Equatable { case calibrated(Region), wgs84, unresolved }

    struct Anchor: Sendable {
        let id: String
        let query: String
        let aliases: [String]
        let latitude: Double
        let longitude: Double
        let reference: String
        var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    }
    struct Sample: Sendable {
        let anchorID: String
        let search: CLLocationCoordinate2D
        let nativeAnnotation: CLLocationCoordinate2D?
    }
    struct Profile: Sendable {
        let searchOutput: Datum
        let renderInput: Datum
        let verifiedAt: Date
    }
    enum CalibrationError: Error, LocalizedError {
        case unavailable, identityUnverified
        var errorDescription: String? {
            NSLocalizedString("map.coordinates.unavailable", comment: "Unverified map position")
        }
    }

    static let shared = MapKitCoordinateSpace()
    static let lifetime: TimeInterval = 300
    private(set) var profiles: [Region: Profile] = [:]
    private(set) var generation: UInt = 0
    private(set) var revision: UInt = 0
    /// The compatibility receipt is scoped to the runtime, public annotation
    /// API and flat map styles actually exercised in the native acceptance run.
    /// Other runtimes retain search/list/navigation and fail closed for pins.
    static var validatedStyles: Set<Style> {
        #if os(iOS)
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return os.majorVersion == 26 && os.minorVersion == 5 ? [.standard] : []
        #else
        return []
        #endif
    }
    @ObservationIgnored private let renderStyles: Set<Style>
    @ObservationIgnored private var inFlight: [Region: Task<Profile, Error>] = [:]
    @ObservationIgnored private var retryAfter: [Region: Date] = [:]
    @ObservationIgnored private var routingHints: [String: Area] = [:]
    @ObservationIgnored private let fetchSample: @MainActor (Anchor) async throws -> Sample
    @ObservationIgnored private let resolveCountry: @MainActor (CLLocationCoordinate2D) async throws -> String?
    @ObservationIgnored private let now: () -> Date

    init(now: @escaping () -> Date = Date.init,
         renderStyles: Set<Style>? = nil,
         resolveCountry: (@MainActor (CLLocationCoordinate2D) async throws -> String?)? = nil,
         fetchSample: (@MainActor (Anchor) async throws -> Sample)? = nil) {
        self.now = now
        self.renderStyles = renderStyles ?? Self.validatedStyles
        self.fetchSample = fetchSample ?? Self.fetchNativeSample
        self.resolveCountry = resolveCountry ?? { c in
            let geocoder = CLGeocoder()
            let result = try await geocoder.reverseGeocodeLocation(.init(latitude: c.latitude, longitude: c.longitude))
            return result.first?.isoCountryCode
        }
    }

    static func area(for c: CLLocationCoordinate2D, countryCode: String? = nil) -> Area {
        guard valid(c) else { return .unresolved }
        switch MainlandChinaBoundary.specialRegion(c) {
        case "HKG": return .calibrated(.hongKong)
        case "MAC": return .calibrated(.macau)
        case "TWN": return .wgs84
        default: break
        }
        if let code = countryCode?.uppercased(), !code.isEmpty {
            switch code {
            case "CN": return .calibrated(.mainland)
            case "HK": return .calibrated(.hongKong)
            case "MO": return .calibrated(.macau)
            default: return .wgs84
            }
        }
        if MainlandChinaBoundary.contains(c) { return .calibrated(.mainland) }
        if MainlandChinaBoundary.isForeignLand(c) { return .wgs84 }
        // Generalized coastlines omit reclaimed land. Absence from the China
        // polygon is not positive evidence that a point uses WGS84.
        if (72...137).contains(c.longitude), (17...55).contains(c.latitude) { return .unresolved }
        return .wgs84
    }
    static func region(for c: CLLocationCoordinate2D) -> Region? {
        if case .calibrated(let region) = area(for: c) { return region }
        return nil
    }
    static func valid(_ c: CLLocationCoordinate2D) -> Bool {
        c.latitude.isFinite && c.longitude.isFinite && CLLocationCoordinate2DIsValid(c)
    }
    private func key(_ c: CLLocationCoordinate2D) -> String { "\(c.latitude),\(c.longitude)" }
    private func area(for c: CLLocationCoordinate2D, countryCode: String? = nil) -> Area {
        let geographical = Self.area(for: c, countryCode: countryCode)
        if geographical == .unresolved { return routingHints[key(c)] ?? .unresolved }
        return geographical
    }
    func profile(for c: CLLocationCoordinate2D, countryCode: String? = nil) -> Profile {
        let unknown = Profile(searchOutput: .unknown, renderInput: .unknown, verifiedAt: now())
        switch area(for: c, countryCode: countryCode) {
        case .wgs84: return .init(searchOutput: .wgs84, renderInput: .wgs84, verifiedAt: now())
        case .unresolved: return unknown
        case .calibrated(let region):
            guard let p = profiles[region], (0..<Self.lifetime).contains(now().timeIntervalSince(p.verifiedAt)) else { return unknown }
            return p
        }
    }

    /// Shared producer owns publication/backoff. Cancelling one caller cannot
    /// cancel another caller's calibration or erase a successfully loaded profile.
    func prepare(near c: CLLocationCoordinate2D, countryCode: String? = nil) async throws {
        guard Self.valid(c) else { throw CalibrationError.unavailable }
        var target = area(for: c, countryCode: countryCode)
        if target == .unresolved {
            let code = try await resolveCountry(c)
            try Task.checkCancellation()
            target = Self.area(for: c, countryCode: code)
            guard target != .unresolved else { throw CalibrationError.unavailable }
            if routingHints.count > 256 { routingHints.removeAll() }
            routingHints[key(c)] = target
            revision &+= 1
        } else if countryCode != nil {
            routingHints[key(c)] = target
        }
        guard case .calibrated(let region) = target else { return }
        if profile(for: c, countryCode: countryCode).searchOutput != .unknown { return }
        if let retry = retryAfter[region], now() < retry { throw CalibrationError.unavailable }
        let task: Task<Profile, Error>
        if let existing = inFlight[region] { task = existing }
        else {
            let epoch = generation
            task = Task { @MainActor [weak self, fetchSample, now] in
                guard let self else { throw CancellationError() }
                do {
                    let anchors = Self.anchors(for: region)
                    var samples: [Sample] = []
                    for anchor in anchors {
                        try Task.checkCancellation()
                        samples.append(try await fetchSample(anchor))
                    }
                    try Task.checkCancellation()
                    guard self.generation == epoch else { throw CancellationError() }
                    let result = Self.classify(anchors: anchors, samples: samples, at: now())
                    self.profiles[region] = result // Search may be known on iOS 17 without a render witness.
                    self.inFlight[region] = nil
                    self.retryAfter[region] = result.searchOutput == .unknown ? now().addingTimeInterval(30) : nil
                    self.revision &+= 1
                    return result
                } catch {
                    if self.generation == epoch {
                        self.inFlight[region] = nil
                        if !(error is CancellationError) { self.retryAfter[region] = now().addingTimeInterval(30) }
                    }
                    throw error
                }
            }
            inFlight[region] = task
        }
        let result = try await task.value
        try Task.checkCancellation()
        guard result.searchOutput != .unknown else { throw CalibrationError.unavailable }
    }

    func invalidate() {
        generation &+= 1
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll(); profiles.removeAll(); retryAfter.removeAll(); routingHints.removeAll()
        revision &+= 1
    }
    /// Amap's adapter has already normalized these points to WGS84. Its
    /// mainland provenance can route reclaimed land missing from coarse coast
    /// geometry; it cannot establish a render datum or override foreign land.
    func registerMainlandProviderCoordinate(_ canonical: CLLocationCoordinate2D) {
        guard Self.area(for: canonical) == .unresolved else { return }
        let target = Area.calibrated(.mainland)
        if routingHints[key(canonical)] != target {
            routingHints[key(canonical)] = target
            revision &+= 1
        }
    }
    func supportsRenderStyle(_ style: Style, at coordinate: CLLocationCoordinate2D) -> Bool {
        if case .calibrated = area(for: coordinate) { return renderStyles.contains(style) }
        return true
    }
    func canonicalSearchCoordinate(_ raw: CLLocationCoordinate2D, countryCode: String? = nil) -> CLLocationCoordinate2D? {
        guard let c = convert(raw, datum: profile(for: raw, countryCode: countryCode).searchOutput, inverse: true) else { return nil }
        if let countryCode { routingHints[key(c)] = Self.area(for: c, countryCode: countryCode) }
        return c
    }
    func searchCoordinate(_ canonical: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        convert(canonical, datum: profile(for: canonical).searchOutput, inverse: false)
    }
    func mapCoordinate(_ c: CLLocationCoordinate2D, style: Style = .standard) -> CLLocationCoordinate2D? {
        let datum = profile(for: c).renderInput
        if case .calibrated = area(for: c), !renderStyles.contains(style) { return nil }
        guard let raw = convert(c, datum: datum, inverse: false) else { return nil }
        // Exact paired coordinates only: a transformed coast point must remain
        // invertible, without applying a city-wide hint across a land border.
        routingHints[key(raw)] = area(for: c)
        return raw
    }
    func canonicalMapCoordinate(_ raw: CLLocationCoordinate2D, style: Style = .standard) -> CLLocationCoordinate2D? {
        if case .calibrated = area(for: raw), !renderStyles.contains(style) { return nil }
        guard let canonical = convert(raw, datum: profile(for: raw).renderInput, inverse: true) else { return nil }
        routingHints[key(canonical)] = area(for: raw)
        return canonical
    }
    private func convert(_ c: CLLocationCoordinate2D, datum: Datum, inverse: Bool) -> CLLocationCoordinate2D? {
        guard Self.valid(c) else { return nil }
        switch datum {
        case .wgs84: return c
        case .gcj02: return inverse ? CoordinateConverter.removingGCJ02Offset(c) : CoordinateConverter.applyingGCJ02Offset(c)
        case .unknown: return nil
        }
    }

    static func classify(_ observed: CLLocationCoordinate2D, against expected: CLLocationCoordinate2D) -> Datum {
        guard valid(observed), valid(expected) else { return .unknown }
        let origin = CLLocation(latitude: observed.latitude, longitude: observed.longitude)
        func distance(_ c: CLLocationCoordinate2D) -> Double { origin.distance(from: .init(latitude: c.latitude, longitude: c.longitude)) }
        let wgs = distance(expected), gcj = distance(CoordinateConverter.applyingGCJ02Offset(expected))
        // Accounts for building footprint/reference precision. This classifies
        // the datum; it does not establish a restaurant entrance to 120 m.
        guard min(wgs, gcj) <= 120, abs(wgs - gcj) > 250 else { return .unknown }
        return wgs < gcj ? .wgs84 : .gcj02
    }
    static func classify(anchors: [Anchor], samples: [Sample], at date: Date) -> Profile {
        func agreement(_ values: [Datum]) -> Datum {
            guard let first = values.first, first != .unknown, values.allSatisfy({ $0 == first }) else { return .unknown }
            return first
        }
        guard anchors.count >= 2, samples.count == anchors.count,
              Set(samples.map(\.anchorID)).count == anchors.count,
              Set(anchors.map(\.id)) == Set(samples.map(\.anchorID)) else {
            return .init(searchOutput: .unknown, renderInput: .unknown, verifiedAt: date)
        }
        let pairs = anchors.compactMap { anchor in samples.first(where: { $0.anchorID == anchor.id }).map { (anchor, $0) } }
        return .init(searchOutput: agreement(pairs.map { classify($0.1.search, against: $0.0.coordinate) }),
                     renderInput: agreement(pairs.map { pair in pair.1.nativeAnnotation.map { classify($0, against: pair.0.coordinate) } ?? .unknown }),
                     verifiedAt: date)
    }

    static func fetchNativeSample(_ anchor: Anchor) async throws -> Sample {
        let item = try await fetchNativeMapItem(anchor)
        let native: CLLocationCoordinate2D?
        if #available(iOS 18.0, macOS 15.0, *) { native = MKMapItemAnnotation(mapItem: item)?.coordinate } else { native = nil }
        return .init(anchorID: anchor.id, search: item.placemark.coordinate, nativeAnnotation: native)
    }

    /// Kept internal so the opt-in native acceptance run can compare the exact
    /// same result with a native annotation and a custom annotation on screen.
    static func fetchNativeMapItem(_ anchor: Anchor) async throws -> MKMapItem {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = anchor.query
        request.resultTypes = .pointOfInterest
        request.region = .init(center: anchor.coordinate, latitudinalMeters: 3_000, longitudinalMeters: 3_000)
        if #available(iOS 18.0, macOS 15.0, *) { request.regionPriority = .required }
        let search = MKLocalSearch(request: request)
        let deadline = Task { @MainActor in
            try await Task.sleep(for: .seconds(12)); search.cancel()
        }
        defer { deadline.cancel() }
        let response = try await withTaskCancellationHandler { try await search.start() }
            onCancel: { Task { @MainActor in search.cancel() } }
        func normalized(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .init(identifier: "en_US_POSIX"))
                .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
        }
        let aliases = Set(([anchor.query] + anchor.aliases).map(normalized))
        guard let item = response.mapItems.first(where: { aliases.contains(normalized($0.name ?? "")) }) else { throw CalibrationError.identityUnverified }
        return item
    }

    /// Versioned external references, never reverse-derived from MapKit or Amap.
    static func anchors(for region: Region) -> [Anchor] {
        switch region {
        case .mainland:
            return [
                .init(id: "Q223207", query: "东方明珠广播电视塔", aliases: ["Oriental Pearl Tower", "Oriental Pearl Radio & TV Tower", "The Oriental Pearl Radio & TV Tower", "东方明珠"],
                      latitude: 31 + 14.0/60 + 30.01/3600, longitude: 121 + 29.0/60 + 40.98/3600, reference: "https://www.wikidata.org/wiki/Q223207"),
                .init(id: "Q168400", query: "广州塔", aliases: ["Canton Tower", "Guangzhou Tower"],
                      latitude: 23 + 6.0/60 + 33.12/3600, longitude: 113 + 19.0/60 + 8.93/3600, reference: "https://www.wikidata.org/wiki/Q168400")
            ]
        case .hongKong:
            return [
                .init(id: "hko-trig-zero", query: "Hong Kong Observatory", aliases: ["香港天文台", "Hong Kong Observatory Headquarters"],
                      latitude: 22 + 18.0/60 + 7.3/3600, longitude: 114 + 10.0/60 + 27.6/3600, reference: "https://www.hko.gov.hk/en/gts/astron2024/files/HKO_almanac_2024.pdf"),
                .init(id: "Q837115", query: "Hong Kong City Hall", aliases: ["香港大会堂", "香港大會堂"],
                      latitude: 22.282, longitude: 114.16128, reference: "https://www.wikidata.org/wiki/Q837115")
            ]
        case .macau:
            return [
                .init(id: "Q4310094", query: "澳门仁慈堂", aliases: ["Holy House of Mercy", "Santa Casa da Misericórdia", "仁慈堂大楼", "仁慈堂大樓"],
                      latitude: 22 + 11.0/60 + 37.0/3600, longitude: 113 + 32.0/60 + 25.0/3600, reference: "https://www.wikidata.org/wiki/Q4310094"),
                .init(id: "Q909429", query: "澳门邮政总局", aliases: ["Macao Post and Telecommunications Bureau", "CTT Macau", "General Post Office", "邮政总局", "郵政總局", "邮政总局大楼", "郵政總局大樓", "澳门邮电局", "澳門郵政總局"],
                      latitude: 22 + 11.0/60 + 35.9/3600, longitude: 113 + 32.0/60 + 24.7/3600, reference: "https://www.wikidata.org/wiki/Q909429")
            ]
        }
    }
}
