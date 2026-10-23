import SwiftUI

/// Native system glass only for controls; opaque fallback honors accessibility settings.
struct CompanionGlassSurface<S: Shape>: ViewModifier {
    var shape: S
    var interactive = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
                .overlay(shape.stroke(CompanionHomeStyle.ink.opacity(contrast == .increased ? 0.5 : 0.12), lineWidth: 1))
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.35), lineWidth: 0.5))
        }
    }
}
extension View {
    func companionGlass<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(CompanionGlassSurface(shape: shape, interactive: interactive))
    }
}

struct CompanionGlassGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var body: some View {
        if #available(iOS 26, *) { GlassEffectContainer(spacing: 12) { content() } }
        else { content() }
    }
}

struct CompanionMapFilters: View {
    let selected: ExperienceCategory?
    let isFavoriteFilter: Bool
    var onSelect: (ExperienceCategory) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: 0) {
            category(.coffee, title: companionText("companion.nearby.coffee", "咖啡"), symbol: "cup.and.saucer")
            category(.food, title: companionText("companion.nearby.food", "吃点"), symbol: "fork.knife")
            category(.nature, title: companionText("companion.nearby.walk", "走走"), symbol: "leaf")
        }
        .padding(.horizontal, 5)
        .companionGlass(in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.nearby.filters")
    }
    private func category(_ category: ExperienceCategory, title: String, symbol: String) -> some View {
        let active = selected == category && !isFavoriteFilter
        return Button { onSelect(category) } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(active ? .semibold : .medium))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(CompanionHomeStyle.ink)
                .background(active ? CompanionHomeStyle.accent.opacity(0.15) : .clear, in: Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(active ? companionText("companion.filter.selected", "已选中，再点清除") : companionText("companion.filter.notSelected", "未选中"))
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("companion.nearby.filter.\(category.rawValue)")
    }
}
