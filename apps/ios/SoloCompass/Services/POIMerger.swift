import Foundation
import CoreLocation

// MARK: - POIMerger

/// Source-neutral POI merging primitives — extracted from `FoursquareService`
/// per audit M3. The original `FoursquareService.merge` / `enrichMerge`
/// remain as thin wrappers so existing call sites (MapViewModel + 5 sites in
/// EnrichmentAgent + 7 tests) keep compiling, but the actual logic lives
/// here in a service-neutral spot — merging Overpass with MapKit, or Amap
/// with Foursquare, no longer feels like "borrow Foursquare's helper."
///
/// Spatial proximity supplies candidates; normalized names and branch evidence
/// establish identity. Merge preserves the first source; enrichMerge only copies
/// allow-listed signals into an identity match and preserves other venues.
public enum POIMerger {

    /// Tag keys promoted from `enrichment` into `base` by `enrichMerge`.
    /// These are the cross-verifiable objective fields the deep-dive
    /// pipeline cares about (audit M3 + the original FoursquareService doc).
    public static let signalKeys: [String] = [
        "fsq_rating",
        "opening_hours",
        "fsq_price",
        "website",
        "phone",
        "fsq_popularity",
        "addr",
    ]

    /// Preserve primary-first order, removing only matching venue identities.
    public static func merge(
        primary: [POI],
        secondary: [POI]
    ) -> [POI] {
        var result: [POI] = []
        result.reserveCapacity(primary.count + secondary.count)
        for poi in primary {
            if !result.contains(where: { sameVenue($0, poi) }) {
                result.append(poi)
            }
        }
        for poi in secondary {
            if !result.contains(where: { sameVenue($0, poi) }) {
                result.append(poi)
            }
        }
        return result
    }

    /// Fold missing allow-listed fields from the nearest unused identity match.
    /// Base identity/coordinates/tags win; unrelated enrichment venues survive.
    public static func enrichMerge(
        base: [POI],
        enrichment: [POI]
    ) -> [POI] {
        var usedIndices = Set<Int>()
        var result: [POI] = []
        result.reserveCapacity(base.count + enrichment.count)
        for poi in base {
            let matchIndex = enrichment.indices
                .filter { !usedIndices.contains($0) && sameVenue(poi, enrichment[$0]) }
                .min { distance(poi, enrichment[$0]) < distance(poi, enrichment[$1]) }
            guard let matchIndex else {
                result.append(poi)
                continue
            }
            usedIndices.insert(matchIndex)
            let match = enrichment[matchIndex]
            var tags = poi.tags
            for sk in signalKeys where tags[sk] == nil {
                if let value = match.tags[sk] { tags[sk] = value }
            }
            result.append(POI(
                osmId: poi.osmId,
                name: poi.name,
                nameEn: poi.nameEn,
                lat: poi.lat,
                lon: poi.lon,
                tags: tags
            ))
        }
        for (index, poi) in enrichment.enumerated() {
            if !usedIndices.contains(index), !result.contains(where: { sameVenue($0, poi) }) {
                result.append(poi)
            }
        }
        return result
    }

    /// Spatial proximity finds candidates; identity evidence authorizes transfer.
    /// In particular, colocated businesses with conflicting phones/addresses
    /// cannot borrow one another's scores or hours.
    public static func sameVenue(_ a: POI, _ b: POI) -> Bool {
        // Stable IDs from the same provider establish identity before fuzzy
        // matching. A shared brand, mall address or hotline cannot join two IDs.
        if let source = a.tags["source"], source == b.tags["source"],
           let key = ["amap": "amap_id", "foursquare": "fsq_id"][source],
           let idA = a.tags[key], !idA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let idB = b.tags[key], !idB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return idA == idB
        }
        let meters = distance(a, b)
        guard meters.isFinite, meters <= 100 else { return false }
        let phoneA = a.tags["phone"].map(normalizedPhone) ?? ""
        let phoneB = b.tags["phone"].map(normalizedPhone) ?? ""
        if !phoneA.isEmpty, !phoneB.isEmpty, phoneA != phoneB { return false }
        let addrA = a.tags["addr"].map(normalized) ?? ""
        let addrB = b.tags["addr"].map(normalized) ?? ""
        if !addrA.isEmpty, !addrB.isEmpty, addrA != addrB { return false }
        if a.osmId == b.osmId, a.tags["source"] == b.tags["source"] { return true }
        let namesA = Set([a.name, a.nameEn].compactMap { $0 }.map(normalized).filter { !$0.isEmpty })
        let namesB = Set([b.name, b.nameEn].compactMap { $0 }.map(normalized).filter { !$0.isEmpty })
        guard !namesA.isDisjoint(with: namesB) else { return false }
        if !phoneA.isEmpty, phoneA == phoneB { return true }
        if !addrA.isEmpty, addrA == addrB { return true }
        // An exact name alone is insufficient for generic chains, even when
        // two branches are in the same mall or on opposite street corners.
        let chains: Set<String> = ["starbucks", "星巴克", "mcdonalds", "麦当劳", "kfc", "肯德基", "luckincoffee", "瑞幸咖啡"]
        guard namesA.isDisjoint(with: chains), namesB.isDisjoint(with: chains) else { return false }
        return meters <= 30
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private static func normalizedPhone(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private static func distance(_ a: POI, _ b: POI) -> Double {
        CLLocation(latitude: a.lat, longitude: a.lon)
            .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
    }

    /// 4-decimal lat/lon bucket key (~11 m). Two POIs that round to the
    /// same cell are spatial candidates only; this is not an identity key.
    public static func cellKey(lat: Double, lon: Double) -> String {
        let rLat = (lat * 10_000).rounded() / 10_000
        let rLon = (lon * 10_000).rounded() / 10_000
        return String(format: "%.4f_%.4f", rLat, rLon)
    }
}
