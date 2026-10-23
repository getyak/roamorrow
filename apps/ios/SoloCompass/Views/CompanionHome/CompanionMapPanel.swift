import SwiftUI

enum CompanionPanelLevel: Equatable { case collapsed, expanded }

/// A persistent panel, separate from the modal presenter and the durable task state.
struct CompanionMapPanel<Summary: View, Header: View, Content: View>: View {
    @Binding var level: CompanionPanelLevel
    var expandedHeight: CGFloat
    var availableHeight: CGFloat
    @ViewBuilder var summary: () -> Summary
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @GestureState private var drag: CGFloat = 0
    private var restingHeight: CGFloat {
        level == .collapsed ? (typeSize.isAccessibilitySize ? 240 : 86)
            : min(max(expandedHeight, typeSize.isAccessibilitySize ? availableHeight * 0.75 : 0), availableHeight * 0.88)
    }
    var body: some View {
        VStack(spacing: 0) {
                Capsule().fill(CompanionHomeStyle.secondaryInk.opacity(0.28))
                    .frame(width: 30, height: 4)
                    .frame(maxWidth: .infinity).frame(height: 24)
                    .contentShape(Rectangle())
            .accessibilityHidden(true)
            .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let travel = value.predictedEndTranslation.height
                    changeLevel(travel > 30 ? .collapsed : travel < -30 ? .expanded : level)
                })
            if level == .collapsed {
                summary().padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                header().padding(.horizontal, 18)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        content()
                    }.padding(.horizontal, 18).padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("companion.panel.content")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(max(restingHeight - drag, 72), availableHeight * 0.9), alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .background(reduceTransparency ? CompanionHomeStyle.paper : .clear, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 29, style: .continuous).strokeBorder(CompanionHomeStyle.line, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.map.panel")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: changeLevel(.expanded)
            case .decrement: changeLevel(.collapsed)
            @unknown default: break
            }
        }
    }
    private func toggle() { changeLevel(level == .collapsed ? .expanded : .collapsed) }
    private func changeLevel(_ value: CompanionPanelLevel) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.94)) { level = value }
    }
}
