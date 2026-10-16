import SwiftUI

/// P2.4 #241: compose sheet for burying a time capsule.
public struct CapsuleComposeView: View {

    public let experienceId: String
    public let experienceTitle: String
    /// Persists the capsule. Returns `true` only when the store actually
    /// accepted it (I12/I16): on `false` the editor stays open with the draft
    /// intact and an inline error to retry — it must never close as if the
    /// note had been buried.
    public let onBury: (Payload) -> Bool
    public let onCancel: () -> Void

    public struct Payload: Hashable {
        public let contentType: String
        public let contentBlob: Data
        public let monthsFromNow: Int
    }

    @State private var text: String = ""
    @State private var months: Int = 12
    /// Inline save-failure status; the draft is untouched when this is shown.
    @State private var saveErrorMessage: String?
    /// Cancel asks for confirmation once there is a draft to lose (I12).
    @State private var showCancelConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let monthOptions = [3, 6, 12, 24]

    public init(
        experienceId: String,
        experienceTitle: String,
        onBury: @escaping (Payload) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.experienceId = experienceId
        self.experienceTitle = experienceTitle
        self.onBury = onBury
        self.onCancel = onCancel
    }

    /// Trimmed, non-empty content — ten spaces are not a note (I12).
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canBury: Bool { !trimmedText.isEmpty }

    /// True when the user typed something that would be lost by dismissing.
    private var isDirty: Bool { !trimmedText.isEmpty }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("capsule.compose.prompt", comment: "Time capsule compose prompt"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(CT.fgPrimary)

                Text(experienceTitle)
                    .font(.footnote)
                    .foregroundColor(CT.fgMuted)

                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(CT.chatInputBg)
                    .cornerRadius(12)
                    .frame(minHeight: 120)
                    .accessibilityLabel(Text(NSLocalizedString(
                        "capsule.compose.editor.a11y",
                        comment: "Note to your future self"
                    )))

                Picker(NSLocalizedString("capsule.compose.surfaceIn", comment: "Surface in"), selection: $months) {
                    ForEach(monthOptions, id: \.self) { m in
                        Text(String(
                            format: NSLocalizedString("capsule.compose.months", comment: "%d months"),
                            m
                        )).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.caption)
                        .foregroundStyle(CT.bannerError)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isStaticText)
                }

                Spacer()

                Button(action: bury) {
                    Text(NSLocalizedString("capsule.compose.bury", comment: "Bury time capsule button"))
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canBury ? CT.capsuleGlow : CT.borderDefault)
                        .foregroundColor(CT.fgPrimary)
                        .cornerRadius(20)
                }
                .disabled(!canBury)
            }
            .padding(20)
            .navigationTitle(NSLocalizedString("capsule.compose.title", comment: "Time capsule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        // Draft protection (I12): never drop typed text silently.
                        if isDirty {
                            showCancelConfirm = true
                        } else {
                            onCancel()
                        }
                    }
                }
            }
            .confirmationDialog(
                NSLocalizedString("capsule.compose.discard.title", comment: "Discard this note?"),
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("capsule.compose.discard.confirm", comment: "Discard"), role: .destructive) {
                    onCancel()
                }
                Button(NSLocalizedString("capsule.compose.discard.keep", comment: "Keep editing"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("capsule.compose.discard.message", comment: "Your note has not been buried yet."))
            }
        }
        .interactiveDismissDisabled(isDirty)
    }

    private func bury() {
        guard canBury, let blob = trimmedText.data(using: .utf8) else { return }
        let ok = onBury(Payload(contentType: "text", contentBlob: blob, monthsFromNow: months))
        if ok {
            saveErrorMessage = nil
            // Only a real save closes the editor (I12/I16).
            dismiss()
        } else {
            // Keep the draft and say what happened — the same button retries.
            saveErrorMessage = NSLocalizedString(
                "capsule.compose.saveFailed",
                comment: "Couldn't bury this note — it is still here. Tap Bury to try again."
            )
        }
    }
}

#Preview {
    CapsuleComposeView(
        experienceId: "demo",
        experienceTitle: "Kalare market alley",
        onBury: { _ in true },
        onCancel: {}
    )
}
