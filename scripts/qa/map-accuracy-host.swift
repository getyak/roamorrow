import Foundation
import CoreLocation

// Only the transport container is stubbed. The converter, merger and rating
// implementations compiled below are the unchanged production source files.
public enum OverpassService {
    public struct POI {
        public let osmId: Int64
        public let name: String
        public let nameEn: String?
        public let lat: Double
        public let lon: Double
        public let tags: [String: String]
    }
}
public typealias POI = OverpassService.POI

// These adapter dependencies carry no logic under test. No network key is
// available, and the host checks only call Amap's real POI mapping function.
public enum ExperienceCategory: String { case culture, nature, food, coffee, work, wellness, nightlife, hidden }
enum Secrets { static let resolvedAmapKey = "" }

var failures = 0
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(label)") }
}
func fixture(_ id: Int64, _ name: String, _ lat: Double = 31.78001,
             _ lon: Double = 113.75001, _ tags: [String: String] = [:]) -> POI {
    POI(osmId: id, name: name, nameEn: nil, lat: lat, lon: lon, tags: tags)
}
