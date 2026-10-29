import SwiftUI

enum CompanionPrimaryTab: String, CaseIterable, Identifiable {
    case now, nearby, itinerary, me
    var id: String { rawValue }
    var title: String {
        switch self {
        case .now: return companionText("companion.tab.conversation", "对话")
        case .nearby: return companionText("companion.tab.map", "地图")
        case .itinerary: return companionText("companion.tab.itinerary", "行程")
        case .me: return companionText("companion.tab.me", "我的")
        }
    }
    var symbol: String {
        switch self {
        case .now: return "bubble.left"
        case .nearby: return "map"
        case .itinerary: return "calendar"
        case .me: return "person.crop.circle"
        }
    }
}

/// Navigation stays separate from the composer and never owns conversation state.
@MainActor
struct CompanionNavigationBar: View {
    let selection: CompanionPrimaryTab
    let onSelect: (CompanionPrimaryTab) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 3) {
            ForEach(CompanionPrimaryTab.allCases) { tab in
                let selected = selection == tab
                Button {
                    guard !selected else { return }
                    Haptics.selection()
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 21, weight: selected ? .semibold : .regular))
                        Text(tab.title)
                            .font(.caption2.weight(selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? CompanionHomeStyle.ink : CompanionHomeStyle.secondaryInk)
                    .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 64 : 56)
                    .padding(.vertical, 3)
                    .background(CompanionHomeStyle.accent.opacity(selected ? 0.12 : 0), in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("companion.surface.\(tab.rawValue)")
            }
        }
        .padding(5)
        .companionGlass(in: Capsule())
        .overlay(Capsule().strokeBorder(CompanionHomeStyle.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.top, 4).padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.navigation")
    }
}
