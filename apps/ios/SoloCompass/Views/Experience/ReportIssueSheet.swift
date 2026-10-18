import MessageUI
import SwiftUI

/// Report an issue with an experience (US-034).
/// Shown via overflow menu in ExperienceDetailView toolbar.
///
/// Honest pipeline (contract 5): there is no report-upload backend, so this
/// sheet (1) saves the report as a LOCAL draft on this device, then (2) hands
/// the traveler a user-controlled email/share composition addressed to the
/// confirmed support inbox. Nothing is sent automatically; the UI clearly
/// distinguishes "saved on this device" from "sent", and a cancelled or failed
/// composition keeps the draft for retry.
public struct ReportIssueSheet: View {
    let experience: Experience
    /// Called when the traveler is done (after saving/sending or dismissing).
    var onFinished: () -> Void
    var onCancel: () -> Void

    private let store: ExperienceReportDraftStore

    public enum ReportReason: String, CaseIterable, Identifiable {
        case closedPermanently = "closed_permanently"
        case moved
        case hoursWrong = "hours_wrong"
        case vibeDifferent = "vibe_different"
        case factuallyWrong = "factually_wrong"
        case other

        public var id: String { rawValue }

        var label: String {
            NSLocalizedString("report.reason.\(rawValue)", comment: "Report reason")
        }
        var symbol: String {
            switch self {
            case .closedPermanently: return "door.left.hand.closed"
            case .moved:             return "arrow.triangle.turn.up.right.diamond"
            case .hoursWrong:        return "clock.badge.xmark"
            case .vibeDifferent:     return "person.crop.circle.badge.questionmark"
            case .factuallyWrong:    return "exclamationmark.circle"
            case .other:             return "ellipsis.circle"
            }
        }
    }

    /// Which step the sheet is in: composing the report, or delivering the
    /// saved draft through user-controlled channels.
    private enum Step: Equatable {
        case compose
        case deliver
    }

    @State private var step: Step = .compose
    @State private var selectedReason: ReportReason?
    @State private var detail: String = ""
    /// The locally saved draft. `status` says honestly whether it was sent.
    @State private var savedDraft: ExperienceReportDraft?
    @State private var isShowingMailComposer = false
    @State private var retainNotice = false
    @FocusState private var detailFocused: Bool
    @State private var didHitLimit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let detailLimit = 200

    public init(
        experience: Experience,
        reportStore: ExperienceReportDraftStore = ExperienceReportDraftStore(),
        onFinished: @escaping () -> Void = {},
        onCancel: @escaping () -> Void
    ) {
        self.experience = experience
        self.store = reportStore
        self.onFinished = onFinished
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .compose:
                    composeList
                case .deliver:
                    deliverList
                }
            }
            .navigationTitle(NSLocalizedString("report.title", comment: "Report an Issue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                switch step {
                case .compose:
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("report.cancel", comment: "Cancel"), action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("report.submit", comment: "Save the report draft")) {
                            saveDraft()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedReason == nil)
                    }
                case .deliver:
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("common.done", comment: "Done"), action: onFinished)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .task {
            // Re-entry restore (review closure 6): reopen loads the latest
            // UNSENT draft for this experience — reason, detail and the
            // delivery step, with an edit action. A `.sent` draft is history
            // and is never mislabeled as pending.
            restoreUnsentDraftIfNeeded()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Guard a partly-composed report (reason chosen or detail typed) from a
        // stray swipe-down; Cancel remains the deliberate exit. A SAVED draft
        // is never lost by dismissal — it lives in the local store.
        .interactiveDismissDisabled(
            step == .compose
                && (selectedReason != nil || !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
    }

    // MARK: - Compose step

    private var composeList: some View {
        List {
            reasonSection
            if selectedReason != nil { detailSection }
        }
    }

    // MARK: - Deliver step (contract 5)

    private var deliverList: some View {
        List {
            Section {
                Label {
                    Text(statusLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: savedDraft?.status == .sent ? "paperplane.fill" : "iphone")
                        .foregroundStyle(savedDraft?.status == .sent ? CT.verifiedGreen : CT.accent)
                }
                Text(NSLocalizedString(
                    "report.delivery.notSentHint",
                    comment: "The draft stays saved on this device until the traveler sends it"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Section(NSLocalizedString("report.delivery.title", comment: "Delivery options header")) {
                if ReportMailComposer.canSendMail {
                    Button {
                        retainNotice = false
                        isShowingMailComposer = true
                    } label: {
                        Label(
                            NSLocalizedString("report.delivery.email", comment: "Email support"),
                            systemImage: "envelope"
                        )
                    }
                    .frame(minHeight: HitTargetMetrics.minimum)
                } else if let mailto = ExperienceReportComposer.mailtoURL(
                    subject: composedSubject,
                    body: composedBody
                ) {
                    Link(destination: mailto) {
                        Label(
                            NSLocalizedString("report.delivery.email", comment: "Email support"),
                            systemImage: "envelope"
                        )
                    }
                    .frame(minHeight: HitTargetMetrics.minimum)
                }
                ShareLink(
                    item: composedBody,
                    subject: Text(composedSubject),
                    message: Text(NSLocalizedString("report.delivery.share.message", comment: "Share message"))
                ) {
                    Label(
                        NSLocalizedString("report.delivery.share", comment: "Share a copy"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .frame(minHeight: HitTargetMetrics.minimum)
            }
            if retainNotice {
                Section {
                    Text(NSLocalizedString(
                        "report.delivery.notSent",
                        comment: "The composition was cancelled or failed — the draft is still saved, not sent"
                    ))
                    .font(.caption)
                    .foregroundStyle(CT.sunGoldDeep)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                Text(composedBody)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } header: {
                Text(NSLocalizedString("report.delivery.preview", comment: "Report content preview header"))
            }
            Section {
                // Explicit edit action for a restored draft (review closure 6).
                Button(NSLocalizedString("report.delivery.edit", comment: "Edit the saved report draft")) {
                    withAnimation { step = .compose }
                }
                .frame(minHeight: HitTargetMetrics.minimum)
            }
        }
        .sheet(isPresented: $isShowingMailComposer) {
            ReportMailComposer(
                recipients: [ExperienceReportDraftStore.supportEmailAddress],
                subject: composedSubject,
                body: composedBody
            ) { result in
                handleMailResult(result)
            }
        }
    }

    /// Honest status line — local saved vs actually sent (contract 5).
    private var statusLine: String {
        savedDraft?.status == .sent
            ? NSLocalizedString("report.sent", comment: "Sent to support from the traveler's mail app")
            : NSLocalizedString("report.savedLocally", comment: "Saved on this device, not sent")
    }

    private var composedSubject: String {
        ExperienceReportComposer.emailSubject(experienceTitle: experience.title)
    }

    private var composedBody: String {
        ExperienceReportComposer.emailBody(
            experienceTitle: experience.title,
            placeName: experience.location.placeNameRomanized,
            cityCode: experience.location.cityCode,
            reasonLabel: selectedReason?.label ?? "",
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Save the report as a local draft — the only thing that happens without
    /// the traveler's explicit send (contract 5). A re-entry edit updates the
    /// SAME draft (review closure 6) instead of stacking duplicates.
    private func saveDraft() {
        guard let reason = selectedReason else { return }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = savedDraft {
            savedDraft = store.updateDraft(id: existing.id, reasonRaw: reason.rawValue, detail: trimmedDetail)
        } else {
            let draft = store.saveDraft(
                experienceId: experience.id,
                reasonRaw: reason.rawValue,
                detail: trimmedDetail
            )
            savedDraft = draft
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { step = .deliver }
    }

    /// Load the latest UNSENT draft on reopen (review closure 6).
    private func restoreUnsentDraftIfNeeded() {
        guard step == .compose, savedDraft == nil,
              let draft = store.latestUnsentDraft(forExperienceId: experience.id)
        else { return }
        savedDraft = draft
        selectedReason = ReportReason(rawValue: draft.reasonRaw)
        detail = draft.detail
        withAnimation { step = .deliver }
    }

    /// Mail composer outcome. ONLY `.sent` marks the draft sent; cancelled or
    /// failed compositions keep the draft saved and say so (contract 5).
    private func handleMailResult(_ result: MFMailComposeResult) {
        isShowingMailComposer = false
        switch result {
        case .sent:
            if let draft = savedDraft {
                store.markSent(id: draft.id)
                savedDraft = store.draft(id: draft.id)
            }
            retainNotice = false
        case .cancelled, .saved, .failed:
            // `.saved` only parks the message in the mail app's drafts — it
            // was NOT sent. The report draft stays savedLocally and says so
            // (contract 5 + review closure 6 compiler fix).
            retainNotice = true
        @unknown default:
            retainNotice = true
        }
    }

    // MARK: - Helpers

    private var counterColor: Color {
        let ratio = Double(detail.count) / Double(detailLimit)
        if detail.count >= detailLimit { return CT.savedRed }
        if ratio >= 0.8 { return .orange }
        return .secondary
    }

    // MARK: - Sections

    private var reasonSection: some View {
        Section {
            ForEach(ReportReason.allCases) { reason in
                // Real Button rows (contract 5): reliable VoiceOver activation
                // plus a readable selected state.
                Button {
                    selectedReason = reason
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: reason.symbol)
                            .frame(width: 24)
                            .foregroundStyle(reason == selectedReason ? CT.savedRed : .secondary)
                            .accessibilityHidden(true)
                        Text(reason.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if reason == selectedReason {
                            Image(systemName: "checkmark").foregroundStyle(CT.savedRed).fontWeight(.semibold)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: HitTargetMetrics.minimum)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(reason.label))
                .accessibilityValue(Text(reason == selectedReason
                    ? NSLocalizedString("common.selected", comment: "Selected")
                    : ""))
                .accessibilityAddTraits(reason == selectedReason ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(NSLocalizedString("report.reason.hint", comment: "Describes that selecting a reason reveals an optional details field"))
                .listRowBackground(reason == selectedReason
                    ? CT.savedRedSoft
                    : Color(.secondarySystemGroupedBackground))
            }
        } header: {
            Text(NSLocalizedString("report.reason.header", comment: "What's wrong?"))
        }
    }

    private var detailSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if detail.isEmpty {
                    Text(NSLocalizedString("report.detail.placeholder", comment: "Optional details (200 chars)"))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $detail)
                    .focused($detailFocused)
                    .frame(minHeight: 80)
                    .onChange(of: detail) { _, new in
                        if new.count > detailLimit {
                            withAnimation {
                                detail = String(new.prefix(detailLimit))
                            }
                            if !didHitLimit {
                                didHitLimit = true
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        } else {
                            didHitLimit = false
                        }
                    }
            }
            HStack {
                Spacer()
                let atLimit = detail.count >= detailLimit
                Text("\(detail.count)/\(detailLimit)")
                    .font(.caption2)
                    .foregroundStyle(counterColor)
                    .monospacedDigit()
                    .scaleEffect(atLimit && !reduceMotion ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: atLimit)
                    .animation(.default, value: detail.count)
            }
        } header: {
            Text(NSLocalizedString("report.detail.header", comment: "Additional details (optional)"))
        }
    }
}

// MARK: - ReportMailComposer

/// User-driven mail composition. NOTHING is sent until the traveler presses
/// Send inside the system composer; the result (sent / cancelled / failed) is
/// handed back so the draft's status stays honest.
struct ReportMailComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let onResult: (MFMailComposeResult) -> Void

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    @MainActor
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: (MFMailComposeResult) -> Void
        init(onResult: @escaping (MFMailComposeResult) -> Void) {
            self.onResult = onResult
        }

        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let rawResult = result.rawValue
            Task { @MainActor in
                controller.dismiss(animated: true) {
                    self.onResult(MFMailComposeResult(rawValue: rawResult) ?? .failed)
                }
            }
        }
    }
}
