import SwiftUI

/// Small map-owned controls. The host owns presentation, conversations and
/// external work; this view only changes deterministic map browsing state.
@MainActor
struct MapWorkspaceControls: View {
    @Bindable var viewModel: MapViewModel
    var sourceLabel: String? = nil
    var onReturnToConversation: (() -> Void)? = nil
    var onAskSelected: ((Experience) -> Void)? = nil
    var onOpenSavedList: (() -> Void)? = nil
    var onSearchArea: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if typeSize.isAccessibilitySize {
                modeSelector
                HStack(spacing: 8) { savedControls }
            } else {
                HStack(spacing: 8) {
                    modeSelector
                    savedControls
                    Spacer(minLength: 0)
                }
            }

            if let sourceLabel, let onReturnToConversation {
                Button(action: onReturnToConversation) {
                    HStack(spacing: 8) {
                        Text(sourceLabel).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                        Spacer(minLength: 4)
                        Label(localized("map.workspace.source.return"), systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .companionGlass(in: Capsule())
                .accessibilityLabel(sourceLabel + ", " + localized("map.workspace.source.return"))
                .accessibilityIdentifier("map.workspace.source.return")
            }

            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { actionControls }
            } else {
                HStack(spacing: 8) { actionControls }
            }
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.workspace.controls")
    }

    private var modeSelector: some View {
        HStack(spacing: 2) {
            modeButton(.nearby, key: "map.workspace.nearby")
            modeButton(.saved, key: "map.workspace.saved")
        }
        .padding(4)
        .companionGlass(in: Capsule())
    }

    @ViewBuilder private var savedControls: some View {
        if viewModel.mapBrowseMode == .saved {
            savedScopeMenu
            if let onOpenSavedList {
                Button(action: onOpenSavedList) {
                    Image(systemName: "list.bullet")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .companionGlass(in: Circle())
                .accessibilityLabel(localized("map.workspace.saved.list"))
                .accessibilityIdentifier("map.workspace.saved.list")
            }
        }
    }

    @ViewBuilder private var actionControls: some View {
        if let onSearchArea, viewModel.mapBrowseMode == .nearby {
            Button(action: onSearchArea) {
                Label(localized("map.workspace.searchArea"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .companionGlass(in: Capsule())
            .accessibilityIdentifier("map.workspace.searchArea")
        }
        if let onAskSelected, let selected = viewModel.selectedExperience {
            Button { onAskSelected(selected) } label: {
                Label(localized("map.workspace.askSelected"), systemImage: "bubble.left")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .companionGlass(in: Capsule())
            .accessibilityIdentifier("map.workspace.askSelected")
        }
    }

    private func modeButton(_ mode: MapWorkspaceBrowseMode, key: String) -> some View {
        let selected = viewModel.mapBrowseMode == mode
        return Button { viewModel.setMapBrowseMode(mode) } label: {
            Text(localized(key))
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .frame(minWidth: 64, minHeight: 44)
                .background(selected ? CompanionHomeStyle.accent.opacity(0.14) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("map.workspace.mode.\(mode.rawValue)")
    }

    private var savedScopeMenu: some View {
        Menu {
            ForEach(MapWorkspaceFavoriteScope.allCases) { scope in
                Button {
                    viewModel.setMapFavoriteScope(scope)
                } label: {
                    if scope == viewModel.mapFavoriteScope {
                        Label(scopeLabel(scope), systemImage: "checkmark")
                    } else {
                        Text(scopeLabel(scope))
                    }
                }
            }
        } label: {
            Label(scopeLabel(viewModel.mapFavoriteScope), systemImage: "chevron.down")
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .companionGlass(in: Capsule())
        .accessibilityIdentifier("map.workspace.saved.scope")
    }

    private func scopeLabel(_ scope: MapWorkspaceFavoriteScope) -> String {
        localized(scope == .currentCity ? "map.workspace.saved.currentCity" : "map.workspace.saved.all")
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "Map workspace control")
    }
}
