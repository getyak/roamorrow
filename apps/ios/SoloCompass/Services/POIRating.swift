import Foundation

/// ExperienceLocation.rating is always normalized to 0–10. A missing, zero or
/// malformed provider score is unknown, not a neutral or minimum rating.
enum POIRating {
    static func normalized10(value: Double, scale: Double) -> Double? {
        guard value.isFinite, scale.isFinite, scale > 0, value > 0, value <= scale else { return nil }
        return value * 10 / scale
    }

    static func normalized10(tags: [String: String]) -> Double? {
        if let value = tags["provider_rating"].flatMap(Double.init),
           let scale = tags["provider_rating_scale"].flatMap(Double.init) {
            return normalized10(value: value, scale: scale)
        }
        guard let value = tags["fsq_rating"].flatMap(Double.init) else { return nil }
        return normalized10(value: value, scale: 10)
    }
}
