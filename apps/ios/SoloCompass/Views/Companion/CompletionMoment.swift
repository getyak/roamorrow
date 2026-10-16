import SwiftData
import SwiftUI

// MARK: - CompletionMoment

/// Full-screen completion moment for a route (round 2 follow-up review).
///
/// Two honest modes, decided by the companion slot's status:
///
///   - **replay** (route already `.completed`): strictly READ-ONLY celebration.
///     Viewing or replaying never starts a write.
///   - **confirm** (route `.closed`): an explicit confirmation button first,
///     then a loading state while `RouteCompanionRemote.markCompleted` runs,
///     and ONLY after the durable acknowledgement does the celebration appear.
///     Failures (including a stub remote) show a visible, retryable error and
///     claim nothing as completed.
///
/// All decision logic lives in `CompletionMomentFlow` (injectable, unit-tested).
public struct CompletionMoment: View {
    let route: Route
    var onDismiss: () -> Void

    private let remoteProvider: @MainActor () -> any RouteCompanionRemote

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulse: Bool = false
    @State private var appeared: Bool = false
    @State private var flow: CompletionMomentFlow

    public init(
        route: Route,
        onDismiss: @escaping () -> Void = {},
        remoteProvider: (@MainActor () -> any RouteCompanionRemote)? = nil
    ) {
        self.route = route
        self.onDismiss = onDismiss
        let provider: @MainActor () -> any RouteCompanionRemote = remoteProvider ?? { @MainActor in
            makeRouteCompanionRemote(context: ModelContext(SoloCompassModelContainer.shared))
        }
        self.remoteProvider = provider
        _flow = State(initialValue: CompletionMomentFlow(
            routeStatus: route.companion?.status,
            routeId: route.id,
            remoteProvider: provider
        ))
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundGradient

            switch flow.phase {
            case .awaitingConfirmation:
                confirmView
            case .committing:
                committingView
            case .celebrating:
                celebrationView
            case .failed(let failure):
                failureView(failure)
            }

            closeButton
        }
        .ignoresSafeArea()
        .onAppear {
            // Fade-in only. NO write ever starts by viewing — the old
            // auto-markCompleted on appear is gone (parent review).
            if reduceMotion {
                appeared = true
                pulse = false
            } else {
                withAnimation(.easeIn(duration: 0.4)) { appeared = true }
                if flow.phase == .celebrating {
                    startCelebrationPulse()
                }
            }
        }
        .onChange(of: flow.phase) { _, newPhase in
            if newPhase == .celebrating, !reduceMotion {
                startCelebrationPulse()
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    private func startCelebrationPulse() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            pulse = true
        }
    }

    // MARK: - Confirm step (closed route)

    private var confirmView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text(NSLocalizedString("completion.confirm.title", comment: "Ask the host to confirm marking the route done"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(NSLocalizedString("completion.confirm.message", comment: "Nothing is saved until the host confirms"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await flow.confirmCompletion() }
            } label: {
                Text(NSLocalizedString("completion.mark.done", comment: "Mark done"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.22))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: HitTargetMetrics.minimum * 1.2)
                    .background(Capsule().fill(.white.opacity(0.92)))
            }
            .frame(maxWidth: 320)
            .accessibilityLabel(Text(NSLocalizedString("completion.mark.done", comment: "Mark done")))
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Committing

    private var committingView: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(NSLocalizedString("completion.committing", comment: "Saving the completion"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(NSLocalizedString("completion.committing", comment: "Saving the completion")))
    }

    // MARK: - Failure (nothing claimed, retryable)

    private func failureView(_ failure: CompletionMomentFlow.Failure) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))

            Text(failure == .remoteUnavailable
                ? NSLocalizedString("completion.error.unavailable", comment: "Completion backend unavailable — nothing was marked done")
                : NSLocalizedString("completion.error.failed", comment: "Completion failed — nothing was saved"))
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await flow.confirmCompletion() }
            } label: {
                Text(NSLocalizedString("completion.error.retry", comment: "Retry marking the route done"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.22))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: HitTargetMetrics.minimum * 1.2)
                    .background(Capsule().fill(.white.opacity(0.92)))
            }
            .frame(maxWidth: 320)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Celebration (after ack, or read-only replay)

    private var celebrationView: some View {
        VStack(spacing: 32) {
            Spacer()
            verifiedIndicator
            statRow
            tagline
            Spacer()
        }
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString("completion.a11y", comment: ""),
            route.verification.walkedByCount,
            route.companion?.confirmedMembers.count ?? 0
        ))
    }

    // MARK: - Sub-views

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.12, blue: 0.22), Color(red: 0.08, green: 0.22, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var verifiedIndicator: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .scaleEffect(pulse ? 1.06 : 1.0)

            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.9, blue: 0.7), Color(red: 0.1, green: 0.7, blue: 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var statRow: some View {
        HStack(spacing: 20) {
            statPill(
                icon: "figure.walk",
                label: NSLocalizedString("completion.stat.walked", comment: "") + " x\(route.verification.walkedByCount)"
            )
            statPill(
                icon: "person.2.fill",
                label: NSLocalizedString("completion.stat.travelers", comment: "") + " x\(route.companion?.confirmedMembers.count ?? 0)"
            )
        }
    }

    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private var tagline: some View {
        Text(NSLocalizedString("completion.tagline", comment: ""))
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeButton: some View {
        Button {
            dismiss()
            onDismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: HitTargetMetrics.minimum, height: HitTargetMetrics.minimum)
                .contentShape(Rectangle())
        }
        .padding(.top, 46)
        .padding(.trailing, 12)
        .accessibilityLabel(Text(NSLocalizedString("common.close", comment: "Close")))
    }
}

// MARK: - Preview

#Preview("CompletionMoment — confirm (closed)") {
    let companion = RouteCompanion(
        status: .closed,
        hostId: "host-preview",
        departureWindow: DepartureWindow(startDate: "2026-06-01", to: "2026-06-03", time: "morning"),
        departureLabel: "Early June",
        pacePreference: .relaxed,
        maxMembers: 4,
        confirmedMembers: ["user-a", "user-b", "user-c"]
    )
    let route = Route(
        id: RouteId(rawValue: "mekong-sunset"),
        title: "Mekong Sunset Walk",
        summary: "",
        experienceIds: [],
        cityCode: "VTE",
        region: "Riverfront",
        estimatedDuration: 90,
        distanceMeters: 1200,
        pace: .relaxed,
        source: .editorial,
        verification: RouteVerification(status: .walkedBy, walkedByCount: 15, walkedBy: ["maya", "leo"]),
        companion: companion
    )
    CompletionMoment(route: route, onDismiss: {})
}

#Preview("CompletionMoment — read-only replay") {
    let companion = RouteCompanion(
        status: .completed,
        hostId: "host-preview",
        departureWindow: DepartureWindow(startDate: "2026-06-01", to: "2026-06-03", time: "morning"),
        departureLabel: "Early June",
        pacePreference: .relaxed,
        maxMembers: 4,
        confirmedMembers: ["user-a", "user-b", "user-c"]
    )
    let route = Route(
        id: RouteId(rawValue: "mekong-sunset"),
        title: "Mekong Sunset Walk",
        summary: "",
        experienceIds: [],
        cityCode: "VTE",
        region: "Riverfront",
        estimatedDuration: 90,
        distanceMeters: 1200,
        pace: .relaxed,
        source: .editorial,
        verification: RouteVerification(status: .verified, walkedByCount: 18, walkedBy: ["maya", "leo"]),
        companion: companion
    )
    CompletionMoment(route: route, onDismiss: {})
}
