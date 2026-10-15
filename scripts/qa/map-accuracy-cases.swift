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
print("Map accuracy host checks: \(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)
