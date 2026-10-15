import Foundation
import CoreLocation

/// Offline provider-routing boundary, not a survey/navigation boundary.
/// Natural Earth 1:10m Admin 0 Countries, public domain. The bundled GeoJSON
/// records the upstream SHA-256; missing/invalid data fails closed.
enum MainlandChinaBoundary {
    private struct Collection: Decodable { let features: [Feature] }
    private struct Feature: Decodable { let geometry: Geometry }
    private struct Geometry: Decodable { let coordinates: [[[[Double]]]] }

    private static let polygons: [[[[Double]]]] = {
        let url = Bundle.main.url(forResource: "mainland_china_boundary", withExtension: "json")
            ?? Bundle.main.url(forResource: "mainland_china_boundary", withExtension: "json", subdirectory: "JSON")
        guard let url, let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(Collection.self, from: data) else { return [] }
        return collection.features.flatMap { $0.geometry.coordinates }
    }()

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return false }
        return polygons.contains { rings in
            guard let outer = rings.first, contains(coordinate, ring: outer) else { return false }
            return !rings.dropFirst().contains { contains(coordinate, ring: $0) }
        }
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
