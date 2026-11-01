import Foundation
import UIKit
import Vision
import PDFKit
import AVFoundation
import Speech
import Observation
import UniformTypeIdentifiers
import ImageIO
#if DEBUG
import OSLog
#endif

/// Prepares genuine local media; extraction never substitutes for preserving the original.
enum CompanionMediaPreparation {
    enum Failure: Error { case invalidFile, tooLarge, unsupportedAudio }

    static func image(_ data: Data, name: String = "Photo.jpg") async throws -> CompanionMediaAttachment {
        guard data.count <= 10 * 1_024 * 1_024 else { throw Failure.tooLarge }
        return try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { throw Failure.invalidFile }
            let scale = min(1, 1_800 / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let bytes = normalized.jpegData(compressionQuality: 0.82), bytes.count <= 10 * 1_024 * 1_024 else { throw Failure.tooLarge }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(data: bytes).perform([request])
            try Task.checkCancellation()
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            let source = CGImageSourceCreateWithData(data as CFData, nil)
            let typeID = source.flatMap { CGImageSourceGetType($0) as String? }
            let type = typeID.flatMap { UTType($0) } ?? .jpeg
            let savedName = (name as NSString).deletingPathExtension + "." + (type.preferredFilenameExtension ?? "jpg")
            return .init(kind: .image, name: String(savedName.prefix(190)), mimeType: type.preferredMIMEType ?? "image/jpeg", data: data,
                         extractedText: text.isEmpty ? nil : String(text.prefix(12_000)))
        }.value
    }

    static func file(_ url: URL) async throws -> CompanionMediaAttachment {
        try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { throw Failure.invalidFile }
            guard let size = values.fileSize, size > 0, size <= 10 * 1_024 * 1_024 else { throw Failure.tooLarge }
            let data = try Data(contentsOf: url)
            guard data.count <= 10 * 1_024 * 1_024 else { throw Failure.tooLarge }
            let type = UTType(filenameExtension: url.pathExtension) ?? .data
            if type.conforms(to: .image) { return try await image(data, name: url.deletingPathExtension().lastPathComponent + ".jpg") }
            let name = String(url.lastPathComponent.prefix(190))
            if type.conforms(to: .audio) {
                let player = try AVAudioPlayer(data: data)
                guard player.duration > 0, player.duration <= 180 else { throw Failure.unsupportedAudio }
                return .init(kind: .audio, name: name, mimeType: type.preferredMIMEType ?? "audio/mp4", data: data, duration: player.duration)
            }
            var text: String?
            if type.conforms(to: .pdf) {
                if let document = PDFDocument(data: data) { text = String((document.string ?? "").prefix(12_000)) }
            } else if type.conforms(to: .plainText) || type.conforms(to: .json) {
                text = String(data: data, encoding: .utf8).map { String($0.prefix(12_000)) }
            }
            try Task.checkCancellation()
            return .init(kind: .file, name: name, mimeType: type.preferredMIMEType ?? "application/octet-stream", data: data,
                         extractedText: text?.isEmpty == false ? text : nil)
        }.value
    }
}

@MainActor
@Observable
final class CompanionAudioSession {
    private enum SessionUse { case recording, playback }
    private(set) var isRecording = false
    private(set) var elapsed: Double = 0
    private(set) var meter: Float = 0
    private(set) var playingID: UUID?
    private(set) var playbackProgress: Double = 0
    var playbackAttachmentID: UUID? { playingID ?? pausedID }
    private(set) var completedRecording: CompanionMediaAttachment?
    private(set) var errorMessage: String?
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var recordingURL: URL?
    @ObservationIgnored private var player: AVAudioPlayer?
    private(set) var recordingSamples: [Float] = []
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var pausedID: UUID?
    @ObservationIgnored private var activeSessionUse: SessionUse?

    func startRecording() async {
        let id = UUID(); generation = id
        stopPlayback()
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == id, !Task.isCancelled else { return }
        guard granted else {
            errorMessage = companionText("companion.media.micDenied", "未开启麦克风权限，仍可打字或选择已有音频。")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            activeSessionUse = .recording
            traceAudio("acquired-recording")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("companion-recording-\(UUID()).m4a")
            let recording = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000])
            recording.isMeteringEnabled = true
            guard recording.record() else { throw CompanionMediaPreparation.Failure.invalidFile }
            recordingURL = url; recorder = recording
            isRecording = true; elapsed = 0; recordingSamples = []; errorMessage = nil
            meterTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled, let self, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    self.elapsed = recorder.currentTime
                    self.meter = min(1, max(0, pow(10, recorder.averagePower(forChannel: 0) / 30)))
                    self.recordingSamples.append(self.meter)
                    if !recorder.isRecording || self.elapsed >= 120 { self.completedRecording = self.finishRecording(); return }
                }
            }
        } catch {
            errorMessage = companionText("companion.media.recordFailed", "这次未能开始录音，草稿仍在。")
            releaseSession(for: .recording)
        }
    }

    /// Stop -> preview. Lifecycle callers stage the result; no recording sends itself.
    func finishRecording() -> CompanionMediaAttachment? {
        generation = UUID(); meterTask?.cancel(); meterTask = nil
        let duration = max(elapsed, recorder?.currentTime ?? 0)
        recorder?.stop(); recorder = nil; isRecording = false
        defer { removeRecordingFile(); releaseSession(for: .recording) }
        guard duration > 0.25, let url = recordingURL, let bytes = try? Data(contentsOf: url), !bytes.isEmpty else { return nil }
        return .init(kind: .audio, name: companionText("companion.media.recordingName", "语音消息") + ".m4a", mimeType: "audio/mp4",
                     data: bytes, duration: duration, samples: recordingSamples)
    }

    func clearError() { errorMessage = nil }
    func cancelPendingPermission() { generation = UUID() }
    func takeCompletedRecording() -> CompanionMediaAttachment? {
        defer { completedRecording = nil }; return completedRecording
    }
    func togglePlayback(_ attachment: CompanionMediaAttachment) {
        guard !isRecording else { return }
        if playingID == attachment.id { player?.pause(); pausedID = attachment.id; playingID = nil; return }
        if pausedID == attachment.id, let player {
            if player.play() { playingID = attachment.id; pausedID = nil; watchPlayback() }
            return
        }
        stopPlayback()
        guard let bytes = attachment.data else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            activeSessionUse = .playback
            traceAudio("acquired-playback")
            let player = try AVAudioPlayer(data: bytes)
            guard player.play() else { throw CompanionMediaPreparation.Failure.invalidFile }
            self.player = player; playingID = attachment.id
            watchPlayback()
        } catch {
            errorMessage = companionText("companion.media.playFailed", "这段音频暂时无法播放，原件仍已保留。")
            releaseSession(for: .playback)
        }
    }
    private func watchPlayback() {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                if let player = self.player, player.duration > 0 { self.playbackProgress = min(1, player.currentTime / player.duration) }
                if self.player?.isPlaying != true {
                    if self.pausedID == nil { self.stopPlayback() }
                    return
                }
            }
        }
    }
    func stopPlayback() {
        traceAudio("stop-playback")
        playbackTask?.cancel(); playbackTask = nil
        player?.stop(); player = nil; playingID = nil; pausedID = nil; playbackProgress = 0
        if !isRecording, let use = activeSessionUse { releaseSession(for: use) }
        traceAudio("stop-playback-completed")
    }
    private func removeRecordingFile() {
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil
    }
    private func releaseSession(for use: SessionUse) {
        // Ordinary navigation and idle composer cleanup must never initialize
        // system audio or deactivate a session this controller never acquired.
        guard activeSessionUse == use else {
            traceAudio(use == .recording ? "release-skipped-recording" : "release-skipped-playback")
            return
        }
        do {
            traceAudio(use == .recording ? "release-recording" : "release-playback")
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            activeSessionUse = nil
            traceAudio("release-completed")
        } catch {
            let failure = error as NSError
            if failure.domain == NSOSStatusErrorDomain,
               failure.code == Int(AVAudioSession.ErrorCode.isBusy.rawValue) {
                // Legacy isBusy reports a completed deactivation.
                activeSessionUse = nil
                traceAudio("release-completed-legacy-busy")
            }
            // Other failures retain ownership so later cleanup can retry.
        }
    }

    private func traceAudio(_ event: String) {
        #if DEBUG
        Self.audioLog.debug("event=\(event, privacy: .public) recording=\(self.isRecording) playing=\(self.playingID != nil) paused=\(self.pausedID != nil) owns=\(self.activeSessionUse != nil)")
        #endif
    }
    #if DEBUG
    private static let audioLog = Logger(subsystem: "com.solocompass.audio-lifecycle", category: "ownership")
    #endif
}

/// Explicit transcription action; its result is editable and never a substitute for audio.
@MainActor
final class CompanionAudioTranscriber {
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeout: Task<Void, Never>?
    private var url: URL?
    private var generation = UUID()

    func transcribe(_ attachment: CompanionMediaAttachment) async throws -> String {
        cancel()
        let id = UUID(); generation = id
        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        try Task.checkCancellation()
        guard generation == id else { throw CancellationError() }
        guard granted, let data = attachment.data,
              let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw CompanionMediaPreparation.Failure.invalidFile }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("companion-transcription-\(UUID()).m4a")
        try data.write(to: url, options: .completeFileProtectionUntilFirstUserAuthentication)
        self.url = url
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { c in
                continuation = c
                task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                    Task { @MainActor [weak self] in
                        if let text { self?.finish(id: id, .success(String(text.prefix(12_000)))) }
                        else if let error { self?.finish(id: id, .failure(error)) }
                    }
                }
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(45))
                    guard !Task.isCancelled else { return }
                    self?.finish(id: id, .failure(URLError(.timedOut)))
                }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.cancel(id: id) } }
    }
    func cancel() { cancel(id: generation) }
    private func cancel(id: UUID) {
        guard generation == id else { return }
        finish(id: id, .failure(CancellationError()))
        generation = UUID()
    }
    private func finish(id: UUID, _ result: Result<String, Error>) {
        guard generation == id, let continuation else { return }
        self.continuation = nil
        task?.cancel(); task = nil; timeout?.cancel(); timeout = nil
        if let url { try? FileManager.default.removeItem(at: url) }; url = nil
        continuation.resume(with: result)
    }
}
