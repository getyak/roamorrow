import SwiftUI

/// The score breakdown used by the experience detail screen.
/// Expansion and animation bindings keep the detail screen's existing state lifetime.
struct SoloScoreBreakdownCard: View {
    let score: SoloScore
    let subtitle: String?
    let isEstimate: Bool
    @Binding var isExpanded: Bool
    @Binding var barsAppeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Dimension {
        let label: String
        let value: Double
        var clampedValue: Double { max(0, min(10, value)) }
        var accessibilityLabel: String { "\(label) \(String(format: "%.0f", clampedValue))" }
    }

    var dimensions: [Dimension] {
        let b = score.breakdown
        return [
            Dimension(label: NSLocalizedString("solo.seating", comment: ""), value: b.seatingFriendly),
            Dimension(label: NSLocalizedString("solo.staff", comment: ""), value: b.staffPressure),
            Dimension(label: NSLocalizedString("solo.patrons", comment: ""), value: b.soloPatronRatio),
            Dimension(label: NSLocalizedString("solo.ambiance", comment: ""), value: b.ambianceFit),
            Dimension(label: NSLocalizedString("solo.safety", comment: ""), value: b.safety),
            Dimension(label: NSLocalizedString("solo.portioning", comment: ""), value: b.soloPortioning),
        ]
    }

    var displayedDimensions: [Dimension] { isExpanded ? dimensions : Array(dimensions.prefix(3)) }
    var strongestDimension: Dimension? { dimensions.max(by: { $0.value < $1.value }) }

    var body: some View {
        let dims = dimensions
        let strongest = strongestDimension
        let shown = displayedDimensions
        VStack(alignment: .leading, spacing: 0) {
            if let hint = score.hint, !hint.isEmpty {
                Text(hint)
                    .ctBody(14.5)
                    .foregroundStyle(CT.fgPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
            if let subtitle {
                Text(isEstimate ? NSLocalizedString("solo.estimate.pill", comment: "AI estimate pill") : subtitle)
                    .ctMono(10.5)
                    .foregroundStyle(CT.fgMuted)
                    .padding(.bottom, 14)
            }
            VStack(spacing: 9) {
                ForEach(shown, id: \.label) { dim in
                    dimensionRow(dim)
                }
            }
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded
                        ? NSLocalizedString("solo.collapse", comment: "Collapse dimensions")
                        : String(format: NSLocalizedString("solo.showAll", comment: "Show all N dimensions"), dims.count))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .ctBody(12)
                .foregroundStyle(CT.fgMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .frame(minHeight: HitTargetMetrics.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(NSLocalizedString("solo.breakdown.expand.hint", comment: "Accessibility hint for breakdown toggle")))
            if let strongest, strongest.value >= 8 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11))
                    Text(String(format: NSLocalizedString("solo.bestCall", comment: "Best solo dimension callout"), strongest.label))
                }
                .ctBody(12.5)
                .foregroundStyle(CT.accent)
                .padding(.top, 8)
                .overlay(alignment: .top) {
                    Rectangle().fill(CT.borderSubtle).frame(height: 0.5)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(CT.surfaceWhite))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(CT.borderSubtle, lineWidth: 0.5))
        .opacity(isEstimate ? 0.85 : 1.0)
        .onAppear {
            guard !barsAppeared else { return }
            if reduceMotion {
                barsAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.7).delay(0.1)) { barsAppeared = true }
            }
        }
    }

    private func dimensionRow(_ dim: Dimension) -> some View {
        let clamped = dim.clampedValue
        let fill: Color = clamped >= 9 ? CT.heatmapHi : clamped >= 7 ? CT.heatmapMid : CT.heatmapLow
        let isTop = clamped >= 10
        return HStack(spacing: 10) {
            Text(dim.label)
                .ctBody(12)
                .foregroundStyle(CT.fgMuted)
                .frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                Capsule().fill(CT.heatmapEmpty)
                    .overlay(alignment: .leading) {
                        Capsule().fill(fill)
                            .frame(width: barsAppeared ? geo.size.width * clamped / 10 : 0)
                    }
            }
            .frame(height: 6)
            Text(String(format: "%.0f", clamped))
                .ctMono(11.5, isTop ? .semibold : .regular)
                .foregroundStyle(isTop ? CT.accent : CT.fgMuted)
                .frame(width: 20, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(dim.accessibilityLabel))
    }

}
