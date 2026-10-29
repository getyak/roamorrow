import SwiftUI

@MainActor
struct CompanionComposer: View {
    @Binding var text: String
    let isWorking: Bool
    var isActive = true
    let onSend: () -> Void
    let onCancel: () -> Void
    var store: CompanionHomeStore? = nil
    var onAddMedia: (() -> Void)? = nil
    var onOpenMedia: ((CompanionMediaAttachment) -> Void)? = nil
    var focusOnAppear = false
    var onFocusChange: ((Bool) -> Void)? = nil
    @Environment(CompanionAudioSession.self) private var audio
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var recordTask: Task<Void, Never>?
    @State private var transcriber = CompanionAudioTranscriber()
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var transcribingID: UUID?
    @State private var notice: String?
    @FocusState private var isFocused: Bool

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(store?.draftAttachments.isEmpty ?? true)
    }
    var body: some View {
        VStack(spacing: 8) {
            if let scopeName {
                HStack(spacing: 8) {
                    Image(systemName: store?.nextTurnPlace == nil ? "map" : "mappin")
                    Text(String(format: companionText("companion.scope.next", "本次关于：%@"), scopeName))
                        .font(.subheadline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    CompanionIconButton(symbol: "xmark", label: companionText("companion.scope.clear", "清除本次范围")) {
                        _ = store?.clearNextTurnScope()
                    }.accessibilityIdentifier("companion.scope.clear")
                }.padding(.leading, 12)
                    .background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("companion.scope.next")
            }
            if let quote = store?.draftQuote {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left").accessibilityHidden(true)
                    Text(quote.text).font(.subheadline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    CompanionIconButton(symbol: "xmark", label: companionText("companion.im.cancelReply", "取消引用")) { store?.setDraftQuote(nil) }
                }.padding(.leading, 12).background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 14))
            }
            if let attachments = store?.draftAttachments, !attachments.isEmpty {
                if isFocused && typeSize.isAccessibilitySize {
                    Button {
                        isFocused = false
                    } label: {
                        Label(String(format: companionText("companion.media.draftCount", "%d 个附件 · 查看"), attachments.count), systemImage: "paperclip")
                            .font(.subheadline).frame(minHeight: 44)
                    }.buttonStyle(.plain)
                } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(attachments) { attachment in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .top, spacing: 2) {
                                    CompanionMediaTile(attachment: attachment, compact: true) { onOpenMedia?(attachment) }
                                    CompanionIconButton(symbol: "xmark.circle", label: companionText("companion.media.remove", "移除附件") + "，" + attachment.name) {
                                        if transcribingID == attachment.id { cancelTranscription() }
                                        store?.removeDraftAttachment(id: attachment.id)
                                    }.accessibilityIdentifier("companion.media.remove.\(attachment.id)")
                                }
                                if attachment.kind == .audio {
                                    Button {
                                        if transcribingID == attachment.id { cancelTranscription() } else { transcribe(attachment) }
                                    } label: {
                                        Label(transcribingID == attachment.id
                                            ? companionText("companion.media.cancelTranscribe", "取消转写")
                                            : companionText("companion.media.transcribe", "转写文字"), systemImage: "text.bubble")
                                            .font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    if let transcript = attachment.extractedText {
                                        TextField(companionText("companion.media.editTranscript", "转写文字，可修改"), text: Binding(
                                            get: { store?.draftAttachments.first(where: { $0.id == attachment.id })?.extractedText ?? transcript },
                                            set: { _ = store?.setAttachmentTranscript(id: attachment.id, text: $0) }), axis: .vertical)
                                            .font(.subheadline).lineLimit(1...5)
                                            .accessibilityLabel(companionText("companion.media.editTranscript", "转写文字，可修改"))
                                    }
                                }
                            }.padding(6).frame(width: 245)
                                .background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 17))
                        }
                    }
                }.scrollIndicators(.hidden).accessibilityIdentifier("companion.draft.media")
                }
            }
            if let message = notice ?? audio.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Text(message).font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk)
                    Spacer(minLength: 0)
                    CompanionIconButton(symbol: "xmark", label: companionText("companion.dismiss_notice", "关闭提示")) { notice = nil; audio.clearError() }
                }.padding(.horizontal, 8)
            }
            if audio.isRecording {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill").foregroundStyle(.red).accessibilityHidden(true)
                    Text(companionText("companion.media.recording", "录音中") + " " + CompanionMediaTile.duration(audio.elapsed))
                        .font(.subheadline.monospacedDigit())
                    Spacer(minLength: 0)
                    Button { finishRecording() } label: {
                        Text(companionText("companion.media.finishRecording", "完成录音"))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.accessibilityIdentifier("companion.audio.finish")
                }.padding(.horizontal, 12)
            }
            HStack(alignment: .bottom, spacing: 2) {
                CompanionIconButton(symbol: "plus", label: companionText("companion.media.add", "添加内容")) {
                    isFocused = false; finishRecording(); onAddMedia?()
                }.disabled(onAddMedia == nil || transcribingID != nil)
                    .accessibilityIdentifier("companion.media.add")
                TextField(companionText("companion.im.placeholder", "和旅伴说说…"), text: $text,
                    prompt: Text(companionText("companion.im.placeholder", "和旅伴说说…")).foregroundColor(CompanionHomeStyle.secondaryInk), axis: .vertical)
                    .font(.body).lineLimit(1...(typeSize.isAccessibilitySize ? 1 : 5)).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12).focused($isFocused).submitLabel(.return)
                    .accessibilityIdentifier("companion.composer")
                if isWorking {
                    CompanionIconButton(symbol: "stop.fill", label: companionText("companion.cancel_response", "停止回应"), action: onCancel)
                } else if hasContent {
                    Button {
                        finishRecording(); cancelTranscription(); isFocused = false; onSend()
                    } label: {
                        Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold))
                            .frame(width: 34, height: 34).foregroundStyle(CompanionHomeStyle.paper)
                            .background(CompanionHomeStyle.ink, in: Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel(companionText("companion.send", "发送"))
                        .accessibilityIdentifier("companion.send").disabled(audio.isRecording || transcribingID != nil)
                } else {
                    CompanionIconButton(symbol: audio.isRecording ? "stop.circle" : "mic", label: companionText("companion.media.recordVoice", "录制语音消息")) {
                        if audio.isRecording { finishRecording() } else { startRecording() }
                    }.accessibilityIdentifier("companion.audio.record")
                }
            }
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(CompanionHomeStyle.line, lineWidth: 0.5))
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
        .onAppear { if focusOnAppear && isActive { isFocused = true } }
        .onChange(of: focusOnAppear) { _, requested in if requested && isActive { isFocused = true } }
        .onChange(of: isFocused) { _, focused in onFocusChange?(focused) }
        .onChange(of: isActive) { _, active in
            if !active { stopCapture() }
            else if focusOnAppear { isFocused = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || (phase == .inactive && audio.isRecording) { stopCapture() }
        }
        .onDisappear { stopCapture() }
        .accessibilityElement(children: .contain).accessibilityIdentifier("companion.input.area")
        .disabled(!isActive)
    }
    private var scopeName: String? {
        if let place = store?.nextTurnPlace { return place.name }
        guard let scope = store?.nextTurnArea else { return nil }
        var labels = [scope.area.name]
        if let query = scope.query, !query.isEmpty { labels.append(query) }
        if let category = scope.category.flatMap(ExperienceCategory.init(rawValue:)) { labels.append(category.localizedTitle) }
        return labels.joined(separator: " · ")
    }

    private func startRecording() {
        guard isActive else { return }
        guard store?.canStartRecording == true else {
            notice = companionText("companion.media.recordLimit", "请先移除一份附件，或导出本机媒体后再录音。")
            return
        }
        isFocused = false
        recordTask?.cancel()
        recordTask = Task { await audio.startRecording() }
    }
    private func finishRecording() {
        recordTask?.cancel(); recordTask = nil
        audio.cancelPendingPermission()
        if audio.isRecording, let recording = audio.finishRecording() {
            if store?.stageAttachment(recording) != true { notice = store?.errorMessage }
        }
    }
    private func stopCapture() {
        finishRecording(); cancelTranscription(); isFocused = false
    }
    private func cancelTranscription() {
        transcriptionTask?.cancel(); transcriptionTask = nil
        transcriber.cancel(); transcribingID = nil
    }
    private func transcribe(_ attachment: CompanionMediaAttachment) {
        cancelTranscription()
        transcribingID = attachment.id
        transcriptionTask = Task {
            defer { if transcribingID == attachment.id { transcribingID = nil; transcriptionTask = nil } }
            do {
                let transcript = try await transcriber.transcribe(attachment)
                try Task.checkCancellation()
                guard isActive, store?.draftAttachments.contains(where: { $0.id == attachment.id }) == true else { return }
                _ = store?.setAttachmentTranscript(id: attachment.id, text: transcript)
                notice = companionText("companion.media.transcriptReady", "转写已附在语音下，发送前请核对。")
            } catch {
                if !Task.isCancelled { notice = companionText("companion.media.transcriptFailed", "暂时无法转写，原始录音仍已保留，可以直接发送或打字补充。") }
            }
        }
    }
}
