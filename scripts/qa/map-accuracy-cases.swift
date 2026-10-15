let cn = CLLocationCoordinate2D(latitude: 31.787312, longitude: 113.759462)
check(CoordinateConverter.isInsideChinaMainland(cn), "Haodian uses mainland provider boundary")
check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 37.5665, longitude: 126.9780)), "Seoul is not mainland")
check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 27.7172, longitude: 85.3240)), "Kathmandu is not mainland")
check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 47.918, longitude: 106.917)), "Ulaanbaatar is not mainland")
check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: 22.2810, longitude: 114.1580)), "Hong Kong excluded")
check(CoordinateConverter.isInsideChinaMainland(.init(latitude: 20.044, longitude: 110.199)), "Hainan included")

let different = POIMerger.enrichMerge(
    base: [fixture(1, "Restaurant A")],
    enrichment: [fixture(2, "Restaurant B", 31.78002, 113.75002, ["fsq_rating": "9.5"])])
check(different.count == 2, "different same-cell venues survive")
check(different.first?.tags["fsq_rating"] == nil, "neighbor rating is not borrowed")
let same = POIMerger.enrichMerge(
    base: [fixture(1, "Haodian Private Kitchen", 31.78001, 113.75001, ["phone": "+86 722 1234567"])],
    enrichment: [fixture(2, "Haodian Private Kitchen", 31.78020, 113.75001, ["phone": "867221234567", "fsq_rating": "9.5"])])
check(same.count == 1, "same venue merges across coordinate cells")
check(same.first?.tags["fsq_rating"] == "9.5", "verified identity can share rating")
let floors = POIMerger.enrichMerge(
    base: [fixture(1, "Cafe", 31.78001, 113.75001, ["phone": "12345678", "addr": "Floor 1"])],
    enrichment: [fixture(2, "Cafe", 31.78001, 113.75001, ["phone": "87654321", "addr": "Floor 2"])])
check(floors.count == 2, "conflicting phones/floors remain distinct")
let normalized = CoordinateConverter.mapKitSearchToWgs84(cn, countryCode: "CN")
check(CLLocation(latitude: cn.latitude, longitude: cn.longitude).distance(from: CLLocation(latitude: normalized.latitude, longitude: normalized.longitude)) > 500, "Haodian MapKit boundary removes the observed source offset")
let roundTrip = CoordinateConverter.wgs84ToGcj02(normalized)
check(abs(roundTrip.latitude - cn.latitude) < 0.00001 && abs(roundTrip.longitude - cn.longitude) < 0.00001, "Haodian conversion round trips within one metre")
check(CoordinateConverter.mapKitSearchToWgs84(cn, countryCode: "KR").latitude == cn.latitude, "explicit foreign country never transforms")
check(!CoordinateConverter.isInsideChinaMainland(.init(latitude: .nan, longitude: 113)), "invalid coordinates fail closed")
check(POIRating.normalized10(value: 4.5, scale: 5) == 9, "Amap 4.5/5 becomes 9/10")
check(POIRating.normalized10(value: 9, scale: 10) == 9, "Foursquare 9/10 remains 9/10")
for value in [Double.nan, .infinity, -1, 0, 6] {
    check(POIRating.normalized10(value: value, scale: 5) == nil, "invalid rating rejected: \(value)")
}
check(!POIMerger.sameVenue(fixture(10, "星巴克"), fixture(11, "星巴克", 31.78002)), "chain branches need corroborating identity")
let pudong = CLLocationCoordinate2D(latitude: 31.1504353, longitude: 121.8059071)
let xiamen = CLLocationCoordinate2D(latitude: 24.544, longitude: 118.127)
check(CoordinateConverter.isInsideChinaMainland(pudong), "Pudong airport routes to mainland despite coastal geometry")
check(CoordinateConverter.isInsideChinaMainland(xiamen, countryCode: "CN"), "Xiamen airport uses mainland routing with geocoded country evidence")
let reclaimed = CLLocationCoordinate2D(latitude: 31.14, longitude: 121.83)
check(CoordinateConverter.mapKitSearchToWgs84(reclaimed, countryCode: "CN").latitude != reclaimed.latitude, "explicit CN evidence overrides generalized coastlines")
let providerA = fixture(100, "郝店面馆", 31.78001, 113.75001, ["source":"amap", "amap_id":"A100"])
let providerB = fixture(101, "郝店面馆", 31.78002, 113.75001, ["source":"amap", "amap_id":"A101", "fsq_rating":"9.6"])
let distinctIDs = POIMerger.enrichMerge(base:[providerA],enrichment:[providerB])
check(distinctIDs.count == 2, "distinct IDs from the same provider remain distinct")
check(distinctIDs[0].tags["fsq_rating"] == nil, "same-name neighboring ID cannot donate its rating")
let sameProviderID = fixture(100, "Renamed venue", 31.7802, 113.75001, ["source":"amap", "amap_id":"A100", "phone":"new number"])
check(POIMerger.merge(primary:[providerA],secondary:[sameProviderID]).count == 1, "stable identity survives updated names and phone numbers")
let sameAddressBranches = POIMerger.merge(primary:[fixture(200,"蜜雪冰城",31.78001,113.75001,["source":"amap","amap_id":"A200","addr":"Mall","phone":"4000000"])],secondary:[fixture(201,"蜜雪冰城",31.78002,113.75001,["source":"amap","amap_id":"A201","addr":"Mall","phone":"4000000"])])
check(sameAddressBranches.count == 2, "shared address and chain hotline cannot override different provider IDs")
let jittered = POIMerger.merge(primary:[fixture(300,"Town Cafe",31.78004,113.75,["source":"mapkit"])],secondary:[fixture(301,"Town Cafe",31.78006,113.75,["source":"mapkit"])])
check(jittered.count == 1, "synthetic MapKit IDs must allow corroborated proximity matching")
let missingProviderID = POIMerger.merge(primary:[fixture(400,"Town Cafe",31.78004,113.75,["source":"amap"])],secondary:[fixture(401,"Town Cafe",31.78006,113.75,["source":"amap"])])
check(missingProviderID.count == 1, "Amap coordinate hashes without upstream IDs are not authoritative")
MainActor.assumeIsolated {
    @MainActor func amap(_ id: String?, _ name: String = "Town Cafe") -> POI {
        AmapPOIService.poi(from: .init(id: id, name: name, location: "113.759462,31.787312",
                                     typecode: "050500", address: nil, tel: nil, business: nil))!
    }
    let upstream = amap("  B123  ")
    check(upstream.tags["amap_id"] == "B123", "Amap adapter preserves a normalized provider identity")
    check(upstream.osmId == amap("B123").osmId, "whitespace cannot fork provider identity")
    check(POIMerger.merge(primary:[upstream],secondary:[amap("B124")]).count == 2, "adapter identities protect distinct neighboring provider records end to end")
    check(amap("   ").tags["amap_id"] == nil, "blank upstream IDs are not authoritative")
    check(amap("   ").osmId == amap(nil).osmId, "blank IDs use the same synthetic fallback as absent IDs")
    check(amap("   ").osmId != amap("   ", "Different venue").osmId, "blank IDs cannot collapse different venues")
}
print("Map accuracy host checks: \(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)
