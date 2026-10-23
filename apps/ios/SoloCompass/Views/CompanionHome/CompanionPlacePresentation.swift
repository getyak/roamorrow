import CoreLocation
import Foundation

/// Display-only translations of bundled source copy. Unknown prose stays available
/// under the original-material disclosure; it is never machine-completed into facts.
enum CompanionPlacePresentation {
  static func isChinese(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
  }

  static func summary(_ original: String, chinese: Bool) -> String {
    guard chinese, !isChinese(original) else { return original }
    return summaries[original]
      ?? companionMapText("companion.place.originalAvailable", "这处体验的资料尚未翻译，可展开查看原文与来源。")
  }

  static func cityName(code: String, fallback: String) -> String {
    let normalized = code.lowercased()
    let aliases = ["san-francisco": "sf", "sfo": "sf", "cn-深圳市": "szx"]
    let key = "city.\(aliases[normalized] ?? normalized)"
    return NSLocalizedString(key, value: fallback, comment: "Known city name")
  }

  static func sourceName(_ source: InformationSource) -> String {
    if let attribution = source.attribution, !attribution.isEmpty,
      source.type == .user || source.type == .fieldVisit || isChinese(attribution) || attribution.hasPrefix("@")
    {
      return attribution
    }
    if let host = source.url?.host { return host }
    switch source.type {
    case .wikivoyage: return "Wikivoyage"
    case .wikipedia: return "Wikipedia"
    case .reddit: return "Reddit"
    case .youtube: return "YouTube"
    case .blog: return companionMapText("companion.source.blog", "博客资料")
    case .user: return companionMapText("companion.source.user", "用户提供")
    case .fieldVisit: return companionMapText("companion.source.visit", "到访记录")
    case .amap: return companionMapText("companion.source.amap", "高德地图")
    }
  }

  static func distance(
    to destination: CLLocationCoordinate2D?, from origin: CLLocationCoordinate2D?, usesGPS: Bool
  ) -> String? {
    guard let destination, let origin, CLLocationCoordinate2DIsValid(destination),
      CLLocationCoordinate2DIsValid(origin)
    else { return nil }
    let meters = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
      .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = meters < 1000 ? 0 : 1
    let amount = meters < 1000 ? (meters / 10).rounded() * 10 : meters / 1000
    let unit =
      meters < 1000
      ? companionMapText("companion.distance.meters", "米")
      : companionMapText("companion.distance.km", "公里")
    let value = (formatter.string(from: NSNumber(value: amount)) ?? "—") + " " + unit
    let label =
      usesGPS
      ? companionMapText("companion.distance.gps", "距你直线约")
      : companionMapText("companion.distance.center", "距地图中心直线约")
    return "\(label) \(value)"
  }

  static let summaries: [String: String] = [
    "The royal cemetery's white chedis catch fire in the last 30 minutes of daylight.":
      "日落前半小时，王室墓园的白色佛塔染上夕照。",
    "A two-table roastery behind an unmarked wooden door, run by a former Bangkok barista.":
      "没有招牌的木门后，是一位曾在曼谷工作的咖啡师经营的两桌小烘焙店。",
    "A 50-year-old khao soi stall where three generations still hand-fry the noodle nest.":
      "一家经营了五十年的咖喱面摊，三代人仍在手工炸制面巢。",
    "Morning chanting at 06:00, when the mountain temple is silent except for the bells.":
      "资料记载清晨六点有诵经，山寺里只听见钟声。",
    "A 100-year-old wooden shophouse with a quiet upstairs, free wifi, and a bottomless pot of jasmine tea.":
      "百年木屋的安静楼上，资料提到免费无线网络和可续的茉莉花茶。",
    "Plastic chairs, cheap Beerlao, and a river that swallows the sun in 12 minutes.":
      "坐在河边塑料椅上喝一杯老挝啤酒，看太阳落入湄公河。",
    "Laos's oldest surviving temple is also its quietest first thing in the morning.":
      "老挝现存最古老的寺庙，清晨格外安静。",
    "A 'concrete monstrosity' built with U.S. cement meant for an airport — and the best vantage in the capital.":
      "这座纪念建筑使用了原定修建机场的美国水泥，也提供了俯瞰首都的视角。",
    "The national symbol of Laos catches the first light at 6:10am — and the gates open then.":
      "老挝的国家象征在晨光里亮起；资料中的开门时间需在出发前确认。",
    "A two-table roaster off Setthathirath where the barista will let you sit through three brews.":
      "塞塔提拉路旁只有两张桌子的烘焙店，适合慢慢喝几轮咖啡。",
    "Basement sake bar, 10-seat counter, bartender pours and steps back.":
      "地下清酒吧只有十个吧台座位，调酒师倒完酒便退开，留出独处空间。",
    "24-hour Korean ox-bone soup counter, four solo tables, no minimum.":
      "韩式牛骨汤店，资料记载有四张单人桌、无最低消费；全天营业说法需再确认。",
    "Nonprofit used-book café: two solo tables in the back mezzanine, no timer.":
      "公益二手书咖啡馆，后方夹层有两张单人桌，资料未设限时。",
    "Small live-jazz room, tip jar not cover, counter seats face the band.":
      "小型现场爵士空间，吧台面向乐队；资料记载以小费罐代替入场费。",
    "Opens 05:30 daily; window seats face the sakuragaoka slope; no conversation needed.":
      "窗边座位朝向樱丘坡道，适合安静独坐；资料标注清晨五点半开门。",
    "24-hour ticket-machine ramen; every seat is a solo booth with a curtain.":
      "自助售票机点单，座位各有独立隔帘；资料中的全天营业需再确认。",
    "Book-store café at Aoyama HQ: single tables face the design section, no music.":
      "书店里的咖啡区，单人桌面向设计书架，资料记载不播放音乐。",
    "Gravel path, benches every 200m, flat walk, English signage; opens at sunrise; no ticket, no crowds.":
      "平缓碎石路沿途有长椅与英文指示，适合清晨散步；开放安排以现场为准。",
    "Bookstore's poetry room upstairs, then Vesuvio's second-floor solo balcony for a beer.":
      "先去书店楼上的诗歌阅览室，再到 Vesuvio 二楼阳台独坐喝杯啤酒。",
    "Six oysters and a glass of Muscadet at the marble bar counter, bay view.":
      "在大理石吧台前点六只生蚝和一杯密斯卡岱白葡萄酒，看海湾。",
    "Long communal table at the back, outlets every 3 feet, staff never rush you.":
      "后方有一张长共享桌，资料提到插座密集、店员不催客。",
    "Paved loop around Strawberry Hill; benches every 100m; boat rentals at the boathouse.":
      "环绕草莓山的铺装步道，沿途有长椅，船屋提供租船。",
    "Third-floor open terrace faces west, sunset ~18:14, no cover charge, tripod OK.":
      "三楼露台朝西，适合看日落；资料记载无入场费、可用三脚架。",
    "Well-lit café-bar on Vo Van Tan open to 23:00, Grab drops at door, solo women regulars.":
      "武文频路上灯光明亮的咖啡酒吧，资料提到常有独自前来的女性，可叫车到门口。",
    "24-hour pho counter, solo four-tops on the sidewalk, bowl arrives in 3 min.":
      "人行道旁可以独坐吃一碗河粉，资料记载上菜较快、全天营业，出发前需确认。",
    "Corner stall open 24h; ₫40k baguette in 90 seconds; sit on plastic stool or take away.":
      "街角越式法棍摊，可以坐塑料凳或外带；资料中的价格与营业时间需再确认。",
    "Working-class tasca: no reservations for solos, €10 grilled sardines, locals fill the room by 20:00.":
      "街坊常去的小酒馆，一人用餐无需预约；烤沙丁鱼价格及晚间座位需再确认。",
    "World's oldest bookstore (1732) has a small café at the back; two single tables by the poetry shelves.":
      "这家始于 1732 年的老书店后面有小咖啡馆，诗歌书架旁设两张单人桌。",
    "Tiled tasca off Praça do Comércio: pratos do dia €9 including soup, main, drink, coffee.":
      "商业广场附近的瓷砖小餐馆，资料提到包含汤、主菜、饮料和咖啡的每日套餐。",
    "20-seat fado tasca: no cover, no minimum, two sets nightly at 20:00 and 22:00.":
      "只有二十个座位的法朵小酒馆，资料记载无入场费及最低消费；场次需另行确认。",
  ]
}
