import SwiftUI
import UIKit

/// A single speech-bubble the Solo mascot pushes toward the traveler from the
/// bottom-right FAB. Bubbles are enqueued by the startup self-diagnostics flow
/// (see `StartupDiagnosticsService`) and by any future proactive nudge that
/// wants an in-app affordance instead of a system notification.
public struct SoloAgentBubble: Identifiable, Equatable, Sendable {

    public enum Tone: Sendable, Equatable {
        case info
        case warn
        case error

        var badge: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }
    }

    public let id: UUID
    public let tone: Tone
    public let title: String
    public let subtitle: String?
    /// Optional CTA — when non-nil, the bubble stays until the traveler taps
    /// (or dismisses). When nil, the bubble auto-dismisses after
    /// `autoDismissAfter` seconds.
    public let ctaLabel: String?
    public let autoDismissAfter: TimeInterval

    public init(
        id: UUID = UUID(),
        tone: Tone,
        title: String,
        subtitle: String? = nil,
        ctaLabel: String? = nil,
        autoDismissAfter: TimeInterval = 6
    ) {
        self.id = id
        self.tone = tone
        self.title = title
        self.subtitle = subtitle
        self.ctaLabel = ctaLabel
        self.autoDismissAfter = autoDismissAfter
    }
}

/// FIFO queue holding at most one visible bubble at a time. `enqueue()` appends;
/// the head is what the view shows. `dismiss(id:)` pops the head only if the id
/// matches — this prevents a stale auto-dismiss timer from removing a bubble
/// the user has already replaced.
@Observable
@MainActor
public final class SoloAgentBubbleQueue {
    public private(set) var items: [SoloAgentBubble] = []

    public init() {}

    public var head: SoloAgentBubble? { items.first }

    public func enqueue(_ bubble: SoloAgentBubble) {
        guard !items.contains(where: { $0.id == bubble.id }) else { return }
        items.append(bubble)
    }

    public func dismiss(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func clear() {
        items.removeAll()
    }
}

// MARK: - View

/// Renders the queue's head bubble to the *left* of the Solo mascot FAB with a
/// tail pointing bottom-right. Parent view is responsible for positioning the
/// overlay so the tail lines up with the mascot.
public struct SoloAgentBubbleView: View {
    @Bindable var queue: SoloAgentBubbleQueue
    let onTapCTA: (SoloAgentBubble) -> Void

    public init(queue: SoloAgentBubbleQueue, onTapCTA: @escaping (SoloAgentBubble) -> Void) {
        self.queue = queue
        self.onTapCTA = onTapCTA
    }

    public var body: some View {
        Group {
            if let bubble = queue.head {
                bubbleBody(for: bubble)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .task(id: bubble.id) {
                        guard bubble.ctaLabel == nil else { return }
                        let duration = UIAccessibility.isVoiceOverRunning ? max(60, bubble.autoDismissAfter) : bubble.autoDismissAfter
                        do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
                        catch { return }
                        if queue.head?.id == bubble.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                queue.dismiss(id: bubble.id)
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: queue.head?.id)
    }

    private func bubbleBody(for bubble: SoloAgentBubble) -> some View {
        HStack(spacing: 4) {
            if let cta = bubble.ctaLabel {
                Button {
                    onTapCTA(bubble)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: bubble.tone.badge)
                            .foregroundStyle(toneColor(bubble.tone))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bubble.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CT.textPrimaryAdaptive)
                            Text(cta)
                                .font(.caption)
                                .foregroundStyle(CT.textMutedAdaptive)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text([bubble.title, bubble.subtitle, cta].compactMap { $0 }.joined(separator: ". ")))
                .accessibilityIdentifier("solo.agent.bubble.cta")

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { queue.dismiss(id: bubble.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CT.textMutedAdaptive)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(NSLocalizedString("solo.agent.bubble.dismiss", comment: "Dismiss")))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label(bubble.title, systemImage: bubble.tone.badge)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle = bubble.subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(CT.textMutedAdaptive)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(CT.textPrimaryAdaptive)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: 420)
        .background(CT.cardAdaptive, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("solo.agent.bubble")
    }

    private func toneColor(_ tone: SoloAgentBubble.Tone) -> Color {
        switch tone {
        case .info: return CT.accent
        case .warn: return Color(red: 0.85, green: 0.55, blue: 0.10)
        case .error: return Color(red: 0.78, green: 0.20, blue: 0.15)
        }
    }
}

