import SwiftUI

/// Subtly scales the label down on press and springs back, giving tappable
/// surfaces physical feedback without the old exaggerated squash. Shared by the
/// filter pills, chat input bar and card actions so press feedback stays
/// consistent across the app.
public struct PressableButtonStyle: ButtonStyle {
    /// Subtle press-down scale used when a call site doesn't pick its own.
    /// The previous `0.92` default visibly squashed every control; HIG press
    /// feedback is a small affordance, not a squeeze.
    public static let defaultPressedScale: CGFloat = 0.97

    /// This style provides scale-only press feedback. Commit haptics belong to
    /// call-site actions, where a completed outcome is actually known.
    public static let providesCommitHaptics = false

    /// Press-down scale. Call sites may still pass a specific value for a
    /// stronger physical affordance (e.g. a large send key).
    let pressedScale: CGFloat

    /// Retained for source compatibility with existing call sites. A
    /// `ButtonStyle` cannot observe whether the button's action actually ran —
    /// `isPressed` also falls on a cancelled press (finger dragged off) — so a
    /// style-level "release" haptic buzzed even when nothing happened. Meaningful
    /// commit haptics live at the call site, inside the action closure where the
    /// outcome is known. This parameter is therefore accepted but never buzzes.
    let haptic: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(pressedScale: CGFloat = PressableButtonStyle.defaultPressedScale, haptic: Bool = false) {
        self.pressedScale = pressedScale
        self.haptic = haptic
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Motion.press: near-critically damped (df 0.82) so the button
            // settles crisply like a system control instead of a wobble that
            // overshoots on release. No haptic is emitted here — see `haptic`.
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Tappable Pill") {
    VStack(spacing: 20) {
        Button("Filter Pill") {}
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(CT.accent.opacity(0.15)))

        Button("Explicit Scale") {}
            .buttonStyle(PressableButtonStyle(pressedScale: 0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
    }
    .padding()
}
