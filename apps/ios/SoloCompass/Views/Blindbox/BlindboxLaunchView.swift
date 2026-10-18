import SwiftUI

/// P2.3 #230: full-screen launch UI for a blindbox trip.
public struct BlindboxLaunchView: View {

    public enum Duration: String, CaseIterable, Identifiable {
        case oneHour = "1h"
        case threeHours = "3h"
        case allDay = "all-day"

        public var id: String { rawValue }
        public var hours: Double {
            switch self {
            case .oneHour: return 1
            case .threeHours: return 3
            case .allDay: return 8
            }
        }
    }

    @State private var selected: Duration = .threeHours
    public let onLaunch: (Duration) -> Void
    public let onDismiss: () -> Void

    public init(
        onLaunch: @escaping (Duration) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onLaunch = onLaunch
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [CT.blindboxAmber.opacity(0.88), CT.sunGoldDeep.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable content + pinned actions (I13): large Dynamic
                // Type must never push the buttons off screen.
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 8)
                        Text(NSLocalizedString("blindbox.launch.title", comment: "Blindbox launch title"))
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(NSLocalizedString("blindbox.launch.subtitle", comment: "Blindbox launch explanation"))
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)

                        Picker(
                            NSLocalizedString("blindbox.launch.duration", comment: "Duration"),
                            selection: $selected
                        ) {
                            ForEach(Duration.allCases) { d in
                                Text(d.rawValue).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.white)
                        .padding(.horizontal, 40)
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 8) {
                    Button(action: { onLaunch(selected) }) {
                        Text(NSLocalizedString("blindbox.launch.open", comment: "Open blindbox button"))
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: HitTargetMetrics.minimum)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundColor(CT.blindboxAmber)
                            .cornerRadius(24)
                            .padding(.horizontal, 24)
                    }

                    Button(NSLocalizedString("blindbox.launch.notNow", comment: "Not now"), action: onDismiss)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(minWidth: HitTargetMetrics.minimum, minHeight: HitTargetMetrics.minimum)
                        .contentShape(Rectangle())
                        .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview {
    BlindboxLaunchView(onLaunch: { _ in }, onDismiss: {})
}
