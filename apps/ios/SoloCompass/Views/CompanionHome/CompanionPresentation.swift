import CoreLocation
import SwiftUI

/// One presenter owns both map tasks and conversation tasks.
enum CompanionHomePresentation: Identifiable {
    case people, journey, settings, addMedia
    case media(CompanionMediaAttachment)
    case sources(CompanionHomeEntry)
    case place(Experience, distanceOrigin: CLLocationCoordinate2D?, usesGPS: Bool)
    case cities(MapViewModel, onSelect: () -> Void)

    var id: String {
        switch self {
        case .addMedia: return "addMedia"
        case .media(let attachment): return "media-\(attachment.id)"
        case .people: return "people"
        case .journey: return "journey"
        case .settings: return "settings"
        case .sources(let entry): return "sources-\(entry.id)"
        case .place(let place, _, _): return "place-\(place.id)"
        case .cities: return "cities"
        }
    }

    var isMapTask: Bool {
        switch self {
        case .place, .cities: return true
        default: return false
        }
    }
}
