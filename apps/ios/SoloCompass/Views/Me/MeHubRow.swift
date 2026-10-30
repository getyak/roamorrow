import SwiftUI

/// One consistent, generously sized navigation row for the personal hub.
struct MeHubRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var badge = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(CompanionHomeStyle.accent)
                .frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(CompanionHomeStyle.ink)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(CompanionHomeStyle.paper)
                    .background(CompanionHomeStyle.ink, in: Capsule())
                    .accessibilityLabel(String(format: NSLocalizedString("me.pending.count", comment: "Pending count"), badge))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(CompanionHomeStyle.secondaryInk)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18).padding(.vertical, 17)
        .frame(minHeight: 60).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct MeHubSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.medium))
                .foregroundStyle(CompanionHomeStyle.secondaryInk)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content }
                .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
    }
}
