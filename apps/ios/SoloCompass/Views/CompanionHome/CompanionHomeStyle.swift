import SwiftUI

/// C's moss, cream and warm paper identity; functional text keeps its contrast.
enum CompanionHomeStyle {
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.09, blue: 0.08, alpha: 1)
            : UIColor(red: 0.980, green: 0.969, blue: 0.941, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.87, green: 0.90, blue: 0.84, alpha: 1)
            : UIColor(red: 0.14, green: 0.22, blue: 0.17, alpha: 1)
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.75, green: 0.85, blue: 0.67, alpha: 1)
            : UIColor(red: 0.22, green: 0.35, blue: 0.27, alpha: 1)
    })
    static let secondaryInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.66, green: 0.72, blue: 0.65, alpha: 1)
            : UIColor(red: 0.35, green: 0.40, blue: 0.36, alpha: 1)
    })
    static let outgoing = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.29, blue: 0.23, alpha: 1)
            : UIColor(red: 0.88, green: 0.92, blue: 0.86, alpha: 1)
    })
    static let incoming = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.13, green: 0.18, blue: 0.15, alpha: 1)
            : UIColor(red: 0.939, green: 0.945, blue: 0.902, alpha: 1)
    })
    static let line = Color.primary.opacity(0.09)
    static let inset: CGFloat = 16
}

func companionText(_ key: String, _ fallback: String) -> String {
    NSLocalizedString(key, value: fallback, comment: "Continuous travel companion")
}

struct CompanionIconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension View {
    /// A secondary hierarchy using the system's complete text-style metrics.
    func companionMetadata(weight: Font.Weight = .regular) -> some View {
        font(.subheadline.weight(weight))
    }
}
