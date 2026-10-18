import SwiftUI
import MapKit
import CoreLocation

struct ProbeResult: Codable {
    var status: String
    var query: String
    var name: String?
    var country: String?
    var raw: [Double]?
    var wgs84: [Double]?
    var differenceMeters: Double?
    var error: String?
}

@MainActor final class ProbeModel: ObservableObject {
    @Published var result = ProbeResult(status: "fixture", query: "Haodian government", name: "Public anchor fixture", country: "CN", raw: [113.759462,31.787312])
    @Published var position: MapCameraPosition = .region(.init(center: .init(latitude:31.786,longitude:113.757),span:.init(latitudeDelta:0.018,longitudeDelta:0.018)))
    private var didRun = false
    private var active: MKLocalSearch?

    private func save() {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("result.json")
        if let data = try? JSONEncoder().encode(result) { try? data.write(to:path,options:.atomic) }
    }
    func run() async {
        guard !didRun else { return }; didRun = true
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--live-poi") else { save(); return }
        let isHK = args.contains("--hong-kong")
        let empty = args.contains("--empty-query")
        let query = empty ? "" : (isHK ? "香港大會堂 Hong Kong City Hall" : "湖北省广水市郝店镇人民政府")
        guard !query.isEmpty else { result = .init(status:"rejected-empty-input",query:query,error:"No network request issued"); save(); return }
        result = .init(status:"pending",query:query); save()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest,.address]
        request.region = .init(center: isHK ? .init(latitude:22.282,longitude:114.162) : .init(latitude:31.787312,longitude:113.759462), latitudinalMeters:10000,longitudinalMeters:10000)
        let search = MKLocalSearch(request:request); active=search
        do {
            let response = try await search.start()
            guard let item=response.mapItems.first else { result.status="empty";save();return }
            let raw=item.placemark.coordinate
            let wgs=CoordinateConverter.mapKitSearchToWgs84(raw,countryCode:item.placemark.isoCountryCode)
            result = .init(status:"observed",query:query,name:item.name,country:item.placemark.isoCountryCode,
                raw:[raw.longitude,raw.latitude],wgs84:[wgs.longitude,wgs.latitude],
                differenceMeters:CLLocation(latitude:raw.latitude,longitude:raw.longitude).distance(from:CLLocation(latitude:wgs.latitude,longitude:wgs.longitude)))
            position = .region(.init(center:.init(latitude:(raw.latitude+wgs.latitude)/2,longitude:(raw.longitude+wgs.longitude)/2),span:.init(latitudeDelta:0.018,longitudeDelta:0.018)))
        } catch { result.status="error";result.error=String(describing:error) }
        save()
    }
}

struct ProbeView: View {
    @StateObject private var model = ProbeModel()
    private func coordinate(_ values:[Double]) -> CLLocationCoordinate2D { .init(latitude:values[1],longitude:values[0]) }
    var body: some View {
        VStack(spacing:0) {
            Text("MapKit 坐标边界校准 · 只读").font(.headline).padding(.vertical,10)
            Map(position:$model.position) {
                if let raw=model.result.raw {
                    Annotation("原始搜索 R",coordinate:coordinate(raw)) {
                        Text("R").font(.headline).padding(8).background(.red,in:Circle()).foregroundStyle(.white)
                    }
                }
                if let wgs=model.result.wgs84 {
                    Annotation("内部 WGS84 W",coordinate:coordinate(wgs)) {
                        Text("W").font(.headline).padding(8).background(.blue,in:Circle()).foregroundStyle(.white)
                    }
                }
            }.mapStyle(.standard(pointsOfInterest:.all))
            VStack(alignment:.leading,spacing:5) {
                Text(model.result.name ?? model.result.query).font(.headline)
                Text("状态：\(model.result.status)　国家：\(model.result.country ?? "?")")
                Text("红 R = 原始搜索；蓝 W = 内部 WGS84").font(.caption)
                if let p=model.result.raw { Text(String(format:"R %.6f, %.6f",p[0],p[1])).monospaced() }
                if let p=model.result.wgs84 { Text(String(format:"W %.6f, %.6f",p[0],p[1])).monospaced() }
                if let d=model.result.differenceMeters { Text(String(format:"来源转换差：%.1f m",d)) }
                if let error=model.result.error { Text(error).font(.caption) }
                Text("只比较底图与搜索契约；不是实地 GPS 验证。").font(.caption).foregroundStyle(.secondary)
            }.font(.subheadline).padding(12).frame(maxWidth:.infinity,alignment:.leading)
        }.task { await model.run() }
    }
}
@main struct CoordinateBoundaryApp: App { var body: some Scene { WindowGroup { ProbeView() } } }
