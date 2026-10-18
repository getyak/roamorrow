import Foundation
import CoreLocation

/// Datum conversion at provider boundaries. Persisted coordinates, distances
/// and geofences use WGS84 [longitude, latitude]. Amap has a mainland routing
/// gate; MapKit uses explicit operations only after independent calibration.
/// Numerical round-trip residual is not evidence of geographical accuracy.
enum CoordinateConverter {
    // MARK: - Constants (state-bureau GCJ-02 algorithm)

    /// Semi-major axis of the Krasovsky 1940 ellipsoid (metres) — the datum the
    /// GCJ-02 offset algorithm is defined against.
    private static let a = 6_378_245.0
    /// Eccentricity squared of the Krasovsky 1940 ellipsoid.
    private static let ee = 0.006_693_421_622_965_943

    // MARK: - Public API

    /// Convert a WGS84 (GPS) coordinate to GCJ-02 for sending to Amap.
    /// This adapter only serves the mainland Amap route; other provider
    /// environments must establish their own datum independently.
    static func wgs84ToGcj02(_ wgs: CLLocationCoordinate2D, countryCode: String? = nil) -> CLLocationCoordinate2D {
        guard shouldConvert(wgs, countryCode: countryCode) else { return wgs }
        return applyingGCJ02Offset(wgs)
    }

    /// Explicit datum operation for a calibrated MapKit boundary, including
    /// service environments whose map coordinates cover Hong Kong or Macau.
    /// This does not decide which POI provider serves a geographical region.
    static func applyingGCJ02Offset(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard CLLocationCoordinate2DIsValid(wgs), wgs.latitude.isFinite, wgs.longitude.isFinite else { return wgs }
        let (dLat, dLon) = offset(lat: wgs.latitude, lon: wgs.longitude)
        return CLLocationCoordinate2D(
            latitude: wgs.latitude + dLat,
            longitude: wgs.longitude + dLon
        )
    }

    /// Convert a GCJ-02 coordinate (as returned by Amap) back to WGS84 for
    /// storage / display in the app's native coordinate system.
    ///
    /// There is no closed-form inverse, so we treat `gcj` as a first guess for
    /// the unknown WGS84 point and refine it: re-encode the guess, measure how
    /// far the result drifts from `gcj`, subtract that drift, repeat. The small
    /// numerical residual does not establish the accuracy of the upstream POI.
    static func gcj02ToWgs84(_ gcj: CLLocationCoordinate2D, countryCode: String? = nil) -> CLLocationCoordinate2D {
        guard shouldConvert(gcj, countryCode: countryCode) else { return gcj }
        return removingGCJ02Offset(gcj)
    }

    /// Inverse of `applyingGCJ02Offset`; only a known datum authorizes its use.
    static func removingGCJ02Offset(_ gcj: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard CLLocationCoordinate2DIsValid(gcj), gcj.latitude.isFinite, gcj.longitude.isFinite else { return gcj }
        var wgs = gcj
        // 5 iterations drives the residual below ~1e-7° (~1 cm) everywhere in
        // China; the loop is cheap and the extra rounds cost nothing.
        //
        // Apply `offset` directly rather than calling `wgs84ToGcj02`: the latter
        // re-runs the `isInsideChinaMainland` gate every iteration, so an
        // intermediate estimate that drifts a hair outside the bounding box near
        // a border would return the identity for that round and stall
        // convergence. We already gated `gcj` above, so the offset always applies.
        for _ in 0..<5 {
            let (dLat, dLon) = offset(lat: wgs.latitude, lon: wgs.longitude)
            // encoded = wgs + offset (what wgs84ToGcj02 would produce).
            wgs = CLLocationCoordinate2D(
                latitude: wgs.latitude + (gcj.latitude - (wgs.latitude + dLat)),
                longitude: wgs.longitude + (gcj.longitude - (wgs.longitude + dLon))
            )
        }
        return wgs
    }

    /// Offline mainland provider routing: country geometry with SAR exclusions.
    /// Coarse shoreline/border data is not suitable for navigation or surveying.
    static func isInsideChinaMainland(_ c: CLLocationCoordinate2D, countryCode: String? = nil) -> Bool {
        guard CLLocationCoordinate2DIsValid(c), c.latitude.isFinite, c.longitude.isFinite else { return false }
        // Country evidence handles reclaimed land, but cannot turn actual SAR
        // or Taiwan land into mainland. Rectangles also contain Fujian/Shenzhen.
        if isSpecialAdministrativeRegionOrTaiwan(c) { return false }
        if let code = countryCode?.uppercased(), !code.isEmpty { return code == "CN" }
        return MainlandChinaBoundary.contains(c)
    }

    private static func shouldConvert(_ coordinate: CLLocationCoordinate2D, countryCode: String?) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate), coordinate.latitude.isFinite,
              coordinate.longitude.isFinite else { return false }
        return isInsideChinaMainland(coordinate, countryCode: countryCode)
    }

    static func isSpecialAdministrativeRegionOrTaiwan(_ c: CLLocationCoordinate2D) -> Bool {
        MainlandChinaBoundary.specialRegion(c) != nil
    }

    // MARK: - State-bureau offset

    /// The GCJ-02 offset (Δlat, Δlon in degrees) at a WGS84 point. This is the
    /// canonical published transform — magic polynomials and all.
    private static func offset(lat: Double, lon: Double) -> (dLat: Double, dLon: Double) {
        // Algorithm works in a coordinate frame shifted by (105°E, 35°N).
        let x = lon - 105.0
        let y = lat - 35.0

        var dLat = transformLat(x: x, y: y)
        var dLon = transformLon(x: x, y: y)

        let radLat = lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = magic.squareRoot()

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (dLat, dLon)
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y
            + 0.1 * x * y + 0.2 * abs(x).squareRoot()
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x
            + 0.1 * x * y + 0.1 * abs(x).squareRoot()
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
