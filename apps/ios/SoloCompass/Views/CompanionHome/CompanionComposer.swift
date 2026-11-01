import SwiftUI
import OSLog

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recordTask: Task<Void, Never>?
    @State private var transcriber = CompanionAudioTranscriber()
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var transcribingID: UUID?
    @State private var transcriptionToken = UUID()
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
                        .accessibilityIdentifier("companion.scope.next")
                    CompanionIconButton(symbol: "xmark", label: companionText("companion.scope.clear", "清除本次范围")) {
                        _ = store?.clearNextTurnScope()
                    }.accessibilityIdentifier("companion.scope.clear")
                }.padding(.leading, 12)
                    .background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 16))
            }
            if let quote = store?.draftQuote {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left").accessibilityHidden(true)
                    Text(quote.text).font(.subheadline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    CompanionIconButton(symbol: "xmark", label: companionText("companion.im.cancelReply", "取消引用")) { store?.setDraftQuote(nil) }
                }.padding(.leading, 12).background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 14))
            }
            if let attachments = store?.draftAttachments.filter({ $0.id != transcribingID }), !attachments.isEmpty {
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
            Group {
                if audio.isRecording {
                    CompanionVoiceRecordingBar(canSend: !isWorking, onPause: pauseRecording, onSend: sendRecording)
                } else if recordTask != nil {
                    pendingInput(companionText("companion.media.startingRecording", "正在开启麦克风…"),
                        cancelLabel: companionText("companion.media.cancelRecording", "取消录音")) { finishRecording() }
                } else if transcribingID != nil {
                    pendingInput(companionText("companion.media.transcribing", "正在转成文字…"),
                        cancelLabel: companionText("companion.media.cancelTranscribe", "取消转写"), action: cancelTranscription)
                } else {
                    textInput
                }
            }
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(CompanionHomeStyle.line, lineWidth: 0.5))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: audio.isRecording)
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
        .onAppear {
            if focusOnAppear && isActive { isFocused = true }
            traceComposer("appeared")
        }
        .onChange(of: focusOnAppear) { _, requested in if requested && isActive { isFocused = true } }
        .onChange(of: isFocused) { _, focused in
            onFocusChange?(focused)
            traceComposer("focus-changed")
        }
        .onChange(of: isActive) { _, active in
            if !active { stopCapture() }
            else if focusOnAppear { isFocused = true }
            traceComposer("activity-changed")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || (phase == .inactive && audio.isRecording) { stopCapture() }
            traceComposer("scene-changed")
        }
        .onDisappear { stopCapture(); traceComposer("disappeared") }
        .accessibilityElement(children: .contain).accessibilityIdentifier("companion.input.area")
        .disabled(!isActive)
    }

    private var textInput: some View {
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
                    finishRecording(); cancelTranscription(); onSend()
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold))
                        .frame(width: 34, height: 34).foregroundStyle(CompanionHomeStyle.paper)
                        .background(CompanionHomeStyle.ink, in: Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel(companionText("companion.send", "发送"))
                    .accessibilityIdentifier("companion.send").disabled(audio.isRecording || transcribingID != nil)
            } else {
                CompanionIconButton(symbol: "mic", label: companionText("companion.media.recordVoice", "录制语音消息"), action: startRecording)
                    .accessibilityIdentifier("companion.audio.record")
            }
        }
    }

    private func pendingInput(_ label: String, cancelLabel: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            ProgressView().padding(.leading, 12)
            Text(label).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            CompanionIconButton(symbol: "xmark", label: cancelLabel, action: action)
        }
        .frame(minHeight: 44).accessibilityIdentifier("companion.audio.pending")
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
        guard isActive, recordTask == nil else { return }
        guard store?.canStartRecording == true else {
            notice = companionText("companion.media.recordLimit", "请先移除一份附件，或导出本机媒体后再录音。")
            return
        }
        isFocused = false
        notice = nil
        recordTask = Task {
            await audio.startRecording()
            if !Task.isCancelled { recordTask = nil }
        }
    }
    @discardableResult
    private func finishRecording() -> CompanionMediaAttachment? {
        recordTask?.cancel(); recordTask = nil
        audio.cancelPendingPermission()
        if audio.isRecording, let recording = audio.finishRecording() {
            guard store?.stageAttachment(recording) == true else { notice = store?.errorMessage; return nil }
            return recording
        }
        return nil
    }
    private func pauseRecording() {
        guard let recording = finishRecording() else {
            notice = notice ?? companionText("companion.media.recordingTooShort", "录音太短，请再说一次。")
            return
        }
        transcribe(recording)
    }
    private func sendRecording() {
        guard !isWorking else { return }
        guard finishRecording() != nil else {
            notice = notice ?? companionText("companion.media.recordingTooShort", "录音太短，请再说一次。")
            return
        }
        onSend()
    }
    private func stopCapture() {
        finishRecording(); cancelTranscription(); isFocused = false
    }
    private func cancelTranscription() {
        transcriptionToken = UUID()
        transcriptionTask?.cancel(); transcriptionTask = nil
        transcriber.cancel(); transcribingID = nil
    }
    private func transcribe(_ attachment: CompanionMediaAttachment) {
        cancelTranscription()
        let token = UUID(); transcriptionToken = token
        transcribingID = attachment.id
        transcriptionTask = Task {
            defer { if transcriptionToken == token { transcribingID = nil; transcriptionTask = nil } }
            do {
                let transcript = try await transcriber.transcribe(attachment)
                try Task.checkCancellation()
                guard isActive, transcriptionToken == token,
                      store?.draftAttachments.contains(where: { $0.id == attachment.id }) == true else { return }
                guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    notice = companionText("companion.media.transcriptEmpty", "没有识别到文字，录音已保留，可以重试或直接发送。")
                    return
                }
                guard store?.useVoiceTranscript(id: attachment.id, text: transcript) == true else {
                    notice = store?.errorMessage
                    return
                }
                notice = nil
                isFocused = true
            } catch {
                if !Task.isCancelled, transcriptionToken == token {
                    notice = companionText("companion.media.transcriptFailed", "暂时无法转写，原始录音仍已保留，可以直接发送或打字补充。")
                }
            }
        }
    }

    /// Diagnose focus ownership without recording text, media, IDs or location.
    private func traceComposer(_ event: String) {
        #if DEBUG
        let focused = isFocused
        let active = isActive
        let phase = String(describing: scenePhase)
        let recording = audio.isRecording
        let requesting = recordTask != nil
        let transcribing = transcribingID != nil
        Self.composerLog.debug("event=\(event, privacy: .public) focused=\(focused) active=\(active) scene=\(phase, privacy: .public) recording=\(recording) requesting=\(requesting) transcribing=\(transcribing)")
        #endif
    }
    #if DEBUG
    private static let composerLog = Logger(subsystem: "com.solocompass.voice-composer", category: "focus")
    #endif
}

/// Only this small view observes the live meter, keeping the conversation still.
@MainActor
private struct CompanionVoiceRecordingBar: View {
    let canSend: Bool
    let onPause: () -> Void
    let onSend: () -> Void
    @Environment(CompanionAudioSession.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Text(CompanionMediaTile.duration(audio.elapsed))
                .font(.subheadline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
                .frame(minWidth: 42).padding(.leading, 10)
                .accessibilityLabel(companionText("companion.media.recording", "录音中"))
                .accessibilityValue(CompanionMediaTile.duration(audio.elapsed))
                .accessibilityIdentifier("companion.audio.duration")
            waveform.frame(maxWidth: .infinity).frame(height: 32).accessibilityHidden(true)
            CompanionIconButton(symbol: "pause.fill", label: companionText("companion.media.pauseToText", "暂停并转成文字"), action: onPause)
                .accessibilityIdentifier("companion.audio.pause")
            Button(action: onSend) {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34).foregroundStyle(CompanionHomeStyle.paper)
                    .background(CompanionHomeStyle.ink, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(!canSend)
                .accessibilityLabel(companionText("companion.media.sendVoice", "发送语音"))
                .accessibilityIdentifier("companion.audio.send")
        }.frame(minHeight: 44).accessibilityIdentifier("companion.audio.recording")
    }

    private var waveform: some View {
        let samples = Array(audio.recordingSamples.suffix(32))
        return GeometryReader { geometry in
            let count = max(1, min(32, Int(geometry.size.width / 5)))
            let visible = Array(samples.suffix(count))
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    let sampleIndex = index - (count - visible.count)
                    let level = sampleIndex >= 0 ? CGFloat(visible[sampleIndex]) : 0
                    Capsule().fill(CompanionHomeStyle.accent)
                        .frame(maxWidth: .infinity).frame(height: max(3, min(1, level) * 30))
                }
            }.frame(height: geometry.size.height)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: audio.elapsed)
        }
    }
}
