import SwiftUI

/// Bundled/vector artwork stays available offline at every display size.
struct CompanionPortrait: View {
    let style: CompanionPortraitStyle
    var size: CGFloat = 32

    var body: some View {
        Group {
            switch style {
            case .moss:
                Image("CompanionCharacter").resizable().scaledToFit()
            case .pixel:
                Canvas { context, canvas in
                    let rows = ["  xxxx  ", " xxxxxx ", "xx xx xx", "xxxxxxxx", "xx xx xx", "xxx  xxx", " xxxxxx ", "  xxxx  "]
                    let unit = canvas.width / 8
                    for (y, row) in rows.enumerated() {
                        for (x, cell) in row.enumerated() where cell == "x" {
                            context.fill(Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit,
                                width: unit, height: unit)), with: .color(Color(red: 0.63, green: 0.37, blue: 0.12)))
                        }
                    }
                }.padding(size * 0.13).background(Color(red: 0.98, green: 0.88, blue: 0.61), in: Circle())
            case .moon:
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(red: 0.25, green: 0.31, blue: 0.52),
                        Color(red: 0.52, green: 0.58, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "moon.stars.fill").resizable().scaledToFit()
                        .foregroundStyle(Color(red: 0.97, green: 0.93, blue: 0.77)).padding(size * 0.22)
                }
            case .landscape:
                ZStack {
                    Circle().fill(Color(red: 0.91, green: 0.91, blue: 0.81))
                    Circle().fill(Color(red: 0.81, green: 0.55, blue: 0.35))
                        .frame(width: size * 0.2, height: size * 0.2).offset(x: size * 0.16, y: -size * 0.17)
                    Image(systemName: "mountain.2.fill").resizable().scaledToFit()
                        .foregroundStyle(Color(red: 0.29, green: 0.42, blue: 0.34))
                        .padding(size * 0.14).offset(y: size * 0.13)
                }.clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
