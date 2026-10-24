import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Instagram-DM-style input bar for **human-to-human** chat (Companion DM).
///
/// Structurally mirrors the Voice-Agent `ChatInputBar` — a "+" attachment menu
/// (Photo Library / Camera / Files), a rounded growing text field, and an inline
/// send button — but deliberately drops the mic affordance: voice is a Voice-Agent
/// concern only. Keeping the picker plumbing here (rather than duplicating it into
/// `ChatView`) means both bars share one well-tested attachment ingestion path.
///
/// Camera capture reuses the existing internal `CameraPicker`
/// (`Views/Experience/CreateExperienceSheet.swift`) so no camera type is
/// redeclared (avoids colliding with `ChatCameraPicker` in `ChatInputBar.swift`).
/// A retry has no text parameter: it cannot resend an acknowledged message
/// or consume edits in the active composer while retrying failed attachments.
struct AttachmentRetryBatch {
    let attachments: [LocalAttachment]

    @MainActor
    func send(using sender: (String, [LocalAttachment]) async -> ChatService.SendOutcome) async -> ChatService.SendOutcome {
        await sender("", attachments)
    }
}

@MainActor
struct AttachmentInputBar: View {
    @Binding var draftText: String
    /// Draft attachments staged for the next send. The parent owns the array;
    /// this bar appends on pick and clears it after `onSend` runs.
    @Binding var attachments: [LocalAttachment]
    /// True while a send is in flight — disables the send button.
    var isSending: Bool

    /// Fires when the user taps send (or hits return) with a non-empty draft OR
    /// at least one staged attachment. Receives the exact trimmed text and the
    /// exact staged attachment snapshot being sent, and returns the structured
    /// `SendOutcome` from the real send pipeline (I24). The bar keeps its
    /// snapshot until this resolves and then clears ONLY what was actually
    /// written — a failed send keeps the whole draft, and a text-only degrade
    /// keeps the failed attachments so a retry can never resend the text.
    let onSend: (String, [LocalAttachment]) async -> ChatService.SendOutcome

    let placeholder: String

    @Environment(\.colorScheme) private var colorScheme

    /// Synchronous pending guard: `submitDraft` flips this before awaiting so a
    /// double tap / double return can never start a second send.
    @State private var isSubmitInFlight = false
    /// Last send failure status kept inline above the field until the next
    /// send attempt, so the user reads what happened and what is still staged.
    @State private var sendStatusMessage: String?
    @State private var retryAttachmentIDs: Set<UUID> = []

    private var retryAttachments: [LocalAttachment] {
        attachments.filter { retryAttachmentIDs.contains($0.id) }
    }

    private var activeAttachments: [LocalAttachment] {
        attachments.filter { !retryAttachmentIDs.contains($0.id) }
    }

    // Attachment-picker presentation state.
    @State private var showAttachmentDialog = false
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false

    init(
        draftText: Binding<String>,
        attachments: Binding<[LocalAttachment]>,
        isSending: Bool = false,
        placeholder: String,
        onSend: @escaping (String, [LocalAttachment]) async -> ChatService.SendOutcome
    ) {
        self._draftText = draftText
        self._attachments = attachments
        self.isSending = isSending
        self.placeholder = placeholder
        self.onSend = onSend
    }

    var body: some View {
        VStack(spacing: 8) {
            if let sendStatusMessage {
                Text(sendStatusMessage)
                    .font(.caption)
                    .foregroundStyle(CT.bannerError)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isStaticText)
            }

            if !retryAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("chat.send.pendingAttachments", comment: "Unsent attachments"))
                        .font(.caption.weight(.semibold))
                    AttachmentDraftStrip(attachments: retryAttachments, onRemove: removeAttachment)
                    Button(action: retryFailedAttachments) {
                        Text(NSLocalizedString("chat.send.retryAttachments", comment: "Retry attachments only"))
                            .font(.subheadline.weight(.medium))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .disabled(isSending || isSubmitInFlight)
                }
                .disabled(isSending || isSubmitInFlight)
            }

            if !activeAttachments.isEmpty {
                AttachmentDraftStrip(attachments: activeAttachments, onRemove: removeAttachment)
                    .disabled(isSending || isSubmitInFlight)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 8) {
                plusButton
                textField
                sendButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(alignment: .top) {
            // Hairline top divider + opaque surface, matching ChatInputBar.
            ZStack(alignment: .top) {
                Color(.systemBackground)
                Rectangle()
                    .fill(CT.borderDefault)
                    .frame(height: 0.5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: attachments)
        .confirmationDialog(
            NSLocalizedString("chat.attachment.add.title", comment: "Add attachment"),
            isPresented: $showAttachmentDialog,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("chat.attachment.source.photos", comment: "Photo Library")) {
                showPhotosPicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(NSLocalizedString("chat.attachment.source.camera", comment: "Camera")) {
                    showCamera = true
                }
            }
            Button(NSLocalizedString("chat.attachment.source.files", comment: "Files")) {
                showFileImporter = true
            }
            Button(NSLocalizedString("chat.attachment.source.cancel", comment: "Cancel"), role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoSelections,
            maxSelectionCount: 5,
            matching: .images
        )
        .onChange(of: photoSelections) { _, items in
            Task { await ingest(photoItems: items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image { appendCameraImage(image) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            Task { await ingest(fileResult: result) }
        }
    }

    // MARK: - Subviews

    private var inputFieldFill: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : CT.chatInputBg
    }

    private var inputBorder: Color {
        colorScheme == .dark ? Color(.separator) : CT.borderSubtle
    }

    /// Instagram-style "+" entry that surfaces the photo/camera/files menu.
    private var plusButton: some View {
        Button {
            showAttachmentDialog = true
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(CT.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(CT.borderSubtle, lineWidth: 0.5)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isSending || isSubmitInFlight)
        .accessibilityLabel(Text(NSLocalizedString("chat.attachment.add.a11y", comment: "Add attachment")))
    }

    private var textField: some View {
        TextField(placeholder, text: $draftText, axis: .vertical)
            .lineLimit(1...4)  // matches ChatInputBar (Voice Agent) growth
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(inputFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(inputBorder, lineWidth: 0.5)
            )
            .submitLabel(.send)
            .onSubmit(submitDraft)
            .disabled(isSending || isSubmitInFlight)
            .accessibilityLabel(Text(placeholder))
    }

    private var sendButton: some View {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Enabled when there's text OR at least one staged attachment.
        let canSend = (!trimmed.isEmpty || !activeAttachments.isEmpty) && !isSending && !isSubmitInFlight
        return Button(action: submitDraft) {
            Group {
                if isSending || isSubmitInFlight {
                    ProgressView().tint(CT.accent)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? CT.accent : Color.secondary.opacity(0.5))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!canSend)
        .accessibilityLabel(Text(NSLocalizedString("chat.input.send.a11y", comment: "Send")))
    }

    private func submitDraft() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || !activeAttachments.isEmpty) && !isSending && !isSubmitInFlight else { return }
        // Freeze the exact snapshot being sent; anything the user types or
        // stages during the await survives the selective cleanup below.
        let sentText = trimmed
        let sentAttachments = activeAttachments
        isSubmitInFlight = true
        sendStatusMessage = nil
        Task {
            let outcome = await onSend(sentText, sentAttachments)
            applySendOutcome(outcome, sentText: sentText, sentAttachments: sentAttachments)
            isSubmitInFlight = false
        }
    }

    /// Selective cleanup driven by the real send outcome (I24):
    ///  - `.sent`: clear the exact sent text (preserving edits made during the
    ///    await) and remove only the sent attachment IDs.
    ///  - `.textSentAttachmentsFailed`: the text is already delivered — clear
    ///    it (never resend) but keep the failed attachments staged for a
    ///    retry, with an explicit message.
    ///  - `.notSent`: nothing was written — keep the entire draft untouched.
    private func applySendOutcome(
        _ outcome: ChatService.SendOutcome,
        sentText: String,
        sentAttachments: [LocalAttachment]
    ) {
        switch outcome {
        case .sent:
            clearSentText(sentText)
            let sentIds = Set(sentAttachments.map(\.id))
            attachments.removeAll { sentIds.contains($0.id) }
            sendStatusMessage = nil

        case .textSentAttachmentsFailed(let reason):
            clearSentText(sentText)
            // Keep failed items in a separate retry group. Normal send only
            // consumes active attachments; this retry never resends text.
            retryAttachmentIDs.formUnion(sentAttachments.map(\.id))
            sendStatusMessage = String(
                format: NSLocalizedString(
                    "chat.send.attachmentsFailed",
                    comment: "Message sent, but attachments could not be uploaded and stay staged: %@"
                ),
                reason
            )

        case .notSent(let reason):
            sendStatusMessage = reason
                ?? NSLocalizedString("chat.send.failed", comment: "Message not sent — it is still in the input field")
        }
        #if canImport(UIKit)
        if let sendStatusMessage {
            UIAccessibility.post(notification: .announcement, argument: sendStatusMessage)
        }
        #endif
    }

    /// Clear only an unchanged snapshot; edits made during the send stay intact.
    private func clearSentText(_ sentText: String) {
        guard !sentText.isEmpty else { return }
        let current = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if current == sentText {
            draftText = ""
        }
    }

    private func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
        retryAttachmentIDs.remove(id)
    }

    private func retryFailedAttachments() {
        guard !isSending, !isSubmitInFlight, !retryAttachments.isEmpty else { return }
        let batch = AttachmentRetryBatch(attachments: retryAttachments)
        isSubmitInFlight = true
        Task {
            let outcome = await batch.send(using: onSend)
            switch outcome {
            case .sent:
                let ids = Set(batch.attachments.map(\.id))
                attachments.removeAll { ids.contains($0.id) }
                retryAttachmentIDs.subtract(ids)
                sendStatusMessage = nil
            case .notSent(let reason):
                sendStatusMessage = reason ?? NSLocalizedString("chat.send.failed", comment: "Not sent")
            case .textSentAttachmentsFailed(let reason):
                sendStatusMessage = reason
            }
            // This path intentionally never reads or clears draftText.
            isSubmitInFlight = false
        }
    }

    // MARK: - Attachment ingestion

    /// Decode picked photo-library items into image drafts.
    ///
    /// A full-resolution `UIImage(data:)` decode of a modern phone photo (often
    /// 10–50 MB) can block for tens to hundreds of ms. Running it on the main
    /// actor froze the picker's dismiss animation the instant you tapped "add".
    /// We now decode + pre-render off the main actor and only hop back to append
    /// the finished, immutable draft — the UI stays live while the bytes land.
    private func ingest(photoItems: [PhotosPickerItem]) async {
        attachments.append(contentsOf: await ChatAttachmentDecoder.photoDrafts(photoItems))
        photoSelections = []
    }

    /// Wrap a freshly captured camera photo as a JPEG image draft.
    private func appendCameraImage(_ image: UIImage) {
        if let draft = ChatAttachmentDecoder.cameraDraft(image) {
            attachments.append(draft)
        }
    }

    /// Read security-scoped files chosen via the document picker into drafts.
    ///
    /// `Data(contentsOf:)` and image decode both block, and picked files can be
    /// large (a PDF, a video). Read + decode each off the main actor and hop
    /// back only to append; the picker dismiss stays smooth. The security scope
    /// must be opened/closed on the same actor that reads, so the whole
    /// per-URL read runs inside one detached task.
    private func ingest(fileResult: Result<[URL], Error>) async {
        guard case let .success(urls) = fileResult else { return }
        attachments.append(contentsOf: await ChatAttachmentDecoder.fileDrafts(urls))
    }
}

#Preview("Empty") {
    StatefulAttachmentBarPreview(initial: "")
}

#Preview("With attachments") {
    StatefulAttachmentBarPreview(
        initial: "Check these out",
        attachments: [
            LocalAttachment(
                kind: .image,
                fileName: "photo.jpg",
                mimeType: "image/jpeg",
                data: Data(count: 120_000),
                image: UIImage(systemName: "photo.fill")
            ),
            LocalAttachment(
                kind: .file,
                fileName: "notes.pdf",
                mimeType: "application/pdf",
                data: Data(count: 900_000),
                image: nil
            )
        ]
    )
}

/// Small helper so the previews can mutate `draftText` like the real parent.
private struct StatefulAttachmentBarPreview: View {
    @State private var text: String
    @State private var attachments: [LocalAttachment]

    init(initial: String, attachments: [LocalAttachment] = []) {
        self._text = State(initialValue: initial)
        self._attachments = State(initialValue: attachments)
    }

    var body: some View {
        VStack {
            Spacer()
            AttachmentInputBar(
                draftText: $text,
                attachments: $attachments,
                placeholder: "Message…",
                onSend: { _, _ in .sent }
            )
        }
    }
}
