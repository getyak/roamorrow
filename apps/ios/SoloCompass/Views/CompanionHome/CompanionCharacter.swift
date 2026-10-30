import SwiftUI

/// Approved C identity. Motion expresses a real in-flight request, never invented emotion.
struct CompanionCharacter: View {
    var activity: CompanionActivity = .idle
    var size: CGFloat = 32
    var viewport: CGRect? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var image: some View {
        Image("CompanionCharacter").resizable().scaledToFit()
            .frame(width: size, height: size)
    }
    private var animates: Bool {
        activity.isWorking && visible && scenePhase == .active && !reduceMotion && !lowPower
    }
    var body: some View {
        // Idle history rows have no motion to suspend. Keep their fixed image
        // out of the scroll view's global geometry/preference update graph.
        Group {
            if activity.isWorking { workingImage }
            else { image }
        }
        .accessibilityHidden(true)
    }

    private var workingImage: some View {
        Group {
            if animates {
                image.phaseAnimator([false, true]) { content, phase in
                    content.rotationEffect(.degrees(phase ? 2.5 : -2), anchor: .bottom)
                        .scaleEffect(phase ? 1.012 : 1, anchor: .bottom)
                } animation: { _ in .easeInOut(duration: 1.45) }
            } else { image }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CompanionCharacterVisible.self,
                    value: CompanionCharacterMotion.isVisible(frame: proxy.frame(in: .global),
                        viewport: (viewport ?? UIScreen.main.bounds).intersection(UIScreen.main.bounds)))
            }
        }
        .onPreferenceChange(CompanionCharacterVisible.self) { visible = $0 }
        .onAppear { lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

enum CompanionCharacterMotion {
    static func isVisible(frame: CGRect, viewport: CGRect) -> Bool {
        !frame.intersection(viewport).isEmpty
    }
}

private struct CompanionCharacterVisible: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
