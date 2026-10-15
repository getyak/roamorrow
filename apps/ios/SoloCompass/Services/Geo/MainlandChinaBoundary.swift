import Foundation
import CoreLocation

/// Offline provider-routing boundary, not a survey/navigation boundary.
/// Natural Earth 1:10m Admin 0 Countries, public domain. The bundled GeoJSON
/// records the upstream SHA-256; missing/invalid data fails closed.
enum MainlandChinaBoundary {
    private struct Collection: Decodable { let features: [Feature] }
    private struct Feature: Decodable { let geometry: Geometry; let properties: Properties? }
    private struct Properties: Decodable { let region: String? }
    private struct Geometry: Decodable { let coordinates: [[[[Double]]]] }

    private struct Polygon {
        let rings: [[[Double]]]
        let minLon: Double, maxLon: Double, minLat: Double, maxLat: Double
        init(_ rings: [[[Double]]]) {
            self.rings = rings
            let outer = rings.first ?? []
            let lon = outer.compactMap { $0.first }, lat = outer.compactMap { $0.count > 1 ? $0[1] : nil }
            minLon = lon.min() ?? .infinity; maxLon = lon.max() ?? -.infinity
            minLat = lat.min() ?? .infinity; maxLat = lat.max() ?? -.infinity
        }
        func contains(_ c: CLLocationCoordinate2D) -> Bool {
            guard minLon <= maxLon, minLat <= maxLat, (minLon...maxLon).contains(c.longitude), (minLat...maxLat).contains(c.latitude),
                  let outer = rings.first, MainlandChinaBoundary.contains(c, ring: outer) else { return false }
            return !rings.dropFirst().contains { MainlandChinaBoundary.contains(c, ring: $0) }
        }
    }
    private static let polygons: [Polygon] = {
        let url = Bundle.main.url(forResource: "mainland_china_boundary", withExtension: "json")
            ?? Bundle.main.url(forResource: "mainland_china_boundary", withExtension: "json", subdirectory: "JSON")
        guard let url, let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(Collection.self, from: data) else { return [] }
        return collection.features.flatMap { $0.geometry.coordinates }.map(Polygon.init)
    }()

    private static let foreignPolygons: [Polygon] = {
        let url = Bundle.main.url(forResource: "mapkit_foreign_land", withExtension: "geojson")
            ?? Bundle.main.url(forResource: "mapkit_foreign_land", withExtension: "geojson", subdirectory: "JSON")
        guard let url, let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(Collection.self, from: data) else { return [] }
        return collection.features.flatMap { $0.geometry.coordinates }.map(Polygon.init)
    }()

    private static let specialRegions: [(String, [Polygon])] = {
        let url = Bundle.main.url(forResource: "mapkit_special_regions", withExtension: "geojson")
            ?? Bundle.main.url(forResource: "mapkit_special_regions", withExtension: "geojson", subdirectory: "JSON")
        guard let url, let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(Collection.self, from: data) else { return [] }
        return collection.features.compactMap { feature in
            guard let region = feature.properties?.region else { return nil }
            return (region, feature.geometry.coordinates.map(Polygon.init))
        }
    }()

    static func specialRegion(_ coordinate: CLLocationCoordinate2D) -> String? {
        specialRegions.first { $0.1.contains { $0.contains(coordinate) } }?.0
    }

    /// Positive evidence of foreign land; missing geometry never proves WGS84.
    static func isForeignLand(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        return foreignPolygons.contains { $0.contains(coordinate) }
    }

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return false }
        return polygons.contains { $0.contains(coordinate) }
    }

    private static func contains(_ c: CLLocationCoordinate2D, ring: [[Double]]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var previous = ring.count - 1
        for index in ring.indices {
            let a = ring[index], b = ring[previous]
            guard a.count >= 2, b.count >= 2 else { return false }
            if (a[1] > c.latitude) != (b[1] > c.latitude),
               c.longitude < (b[0] - a[0]) * (c.latitude - a[1]) / (b[1] - a[1]) + a[0] {
                inside.toggle()
            }
            previous = index
        }
        return inside
    }
}
