import Foundation

// Only the framework boundary is fake. The Python runner compiles the exact
// shipping CompanionAudioSession class, with no edits to its control flow.
enum FakeAudioFailure: Error { case failed }
let AVFormatIDKey = "format"
let AVSampleRateKey = "rate"
let AVNumberOfChannelsKey = "channels"
let AVEncoderBitRateKey = "bits"
let kAudioFormatMPEG4AAC = 1
func companionText(_ key: String, _ fallback: String) -> String { fallback }
enum CompanionMediaPreparation { enum Failure: Error { case invalidFile } }
struct CompanionMediaAttachment {
    enum Kind { case audio }
    var id = UUID()
    var kind: Kind
    var name: String
    var mimeType: String
    var data: Data?
    var duration: Double? = nil
    var samples: [Float]? = nil
}

@MainActor
enum AVAudioApplication {
    static var granted = true
    static var permissionRequests = 0
    static func requestRecordPermission() async -> Bool { permissionRequests += 1; return granted }
}

@MainActor
final class AVAudioSession {
    enum Category: String { case playAndRecord, playback }
    enum Mode { case `default` }
    struct Options: OptionSet, Sendable {
        let rawValue: Int
        static let defaultToSpeaker = Self(rawValue: 1)
        static let notifyOthersOnDeactivation = Self(rawValue: 2)
    }
    static var calls: [String] = []
    static var activationFails = false
    static var deactivationFails = false
    static let instance = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { calls.append("shared"); return instance }
    func setCategory(_ category: Category, mode: Mode, options: Options = []) throws {
        Self.calls.append("category:\(category.rawValue)")
    }
    func setActive(_ active: Bool, options: Options = []) throws {
        Self.calls.append(active ? "activate" : "deactivate")
        if active && Self.activationFails { throw FakeAudioFailure.failed }
        if !active && Self.deactivationFails { throw FakeAudioFailure.failed }
    }
}

@MainActor
final class AVAudioRecorder {
    static var constructionFails = false
    static var files: [URL] = []
    let url: URL
    var isMeteringEnabled = false
    var isRecording = false
    var currentTime = 1.0
    init(url: URL, settings: [String: Any]) throws {
        if Self.constructionFails { throw FakeAudioFailure.failed }
        self.url = url
    }
    func record() -> Bool {
        do { try Data([1, 2, 3]).write(to: url) } catch { return false }
        Self.files.append(url); isRecording = true; return true
    }
    func stop() { isRecording = false }
    func updateMeters() {}
    func averagePower(forChannel channel: Int) -> Float { -30 }
}

@MainActor
final class AVAudioPlayer {
    static var constructionFails = false
    var isPlaying = false
    let duration = 1.0
    let currentTime = 0.0
    init(data: Data) throws { if Self.constructionFails { throw FakeAudioFailure.failed } }
    func play() -> Bool { isPlaying = true; return true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false }
}

@main @MainActor
struct CompanionAudioHost {
    static var failures = 0
    static var checks = 0
    static func expect(_ value: Bool, _ description: String) {
        checks += 1
        if !value { failures += 1; print("FAIL: \(description)") }
    }
    static func count(_ call: String) -> Int { AVAudioSession.calls.filter { $0 == call }.count }
    static func reset() {
        AVAudioSession.calls = []; AVAudioSession.activationFails = false; AVAudioSession.deactivationFails = false
        AVAudioApplication.granted = true; AVAudioApplication.permissionRequests = 0
        AVAudioRecorder.constructionFails = false; AVAudioPlayer.constructionFails = false
    }
    static func attachment() -> CompanionMediaAttachment {
        .init(kind: .audio, name: "Owned test audio", mimeType: "audio/mp4", data: Data([1, 2, 3]))
    }
    static func main() async {
        reset()
        let idle = CompanionAudioSession()
        for _ in 0..<20 { idle.stopPlayback(); _ = idle.finishRecording() }
        expect(AVAudioSession.calls.isEmpty, "idle navigation/composer cleanup never initializes system audio")
        expect(AVAudioApplication.permissionRequests == 0, "idle cleanup never requests microphone access")

        reset()
        let recording = CompanionAudioSession()
        await recording.startRecording()
        expect(recording.isRecording && count("activate") == 1, "explicit recording activates once after consent")
        recording.stopPlayback()
        expect(count("deactivate") == 0, "playback cleanup preserves the recording session")
        expect(recording.finishRecording()?.data != nil, "recording stop preserves the original audio")
        expect(count("deactivate") == 1, "recording completion releases its acquired session once")
        _ = recording.finishRecording(); recording.stopPlayback()
        expect(count("deactivate") == 1, "repeated recording cleanup never deactivates again")

        reset(); AVAudioApplication.granted = false
        let denied = CompanionAudioSession(); await denied.startRecording(); denied.stopPlayback()
        expect(AVAudioSession.calls.isEmpty, "denied microphone access never touches system audio")

        reset(); AVAudioSession.activationFails = true
        let failedActivation = CompanionAudioSession(); await failedActivation.startRecording()
        expect(count("activate") == 1 && count("deactivate") == 0, "failed recording activation owns nothing to release")

        reset(); AVAudioRecorder.constructionFails = true
        let failedRecorder = CompanionAudioSession(); await failedRecorder.startRecording(); failedRecorder.stopPlayback()
        expect(count("activate") == 1 && count("deactivate") == 1, "failed recorder construction releases only its acquired session")

        reset()
        let playback = CompanionAudioSession(); let audio = attachment()
        playback.togglePlayback(audio); playback.togglePlayback(audio)
        expect(playback.playbackAttachmentID == audio.id && playback.playingID == nil, "pausing retains the same audio")
        expect(playback.finishRecording() == nil && count("deactivate") == 0, "idle recording cleanup preserves paused playback")
        playback.togglePlayback(audio)
        expect(playback.playingID == audio.id && count("activate") == 1, "resume reuses the acquired playback session")
        _ = playback.finishRecording()
        expect(count("deactivate") == 0, "idle recording cleanup preserves active playback")
        playback.stopPlayback(); playback.stopPlayback()
        expect(count("deactivate") == 1, "playback stop releases exactly once")

        reset(); AVAudioPlayer.constructionFails = true
        let failedPlayer = CompanionAudioSession(); failedPlayer.togglePlayback(attachment()); failedPlayer.stopPlayback()
        expect(count("activate") == 1 && count("deactivate") == 1, "failed player construction releases its acquired session")

        reset(); AVAudioSession.activationFails = true
        let failedPlaybackActivation = CompanionAudioSession(); failedPlaybackActivation.togglePlayback(attachment())
        expect(count("activate") == 1 && count("deactivate") == 0, "failed playback activation owns nothing to release")

        reset()
        let switching = CompanionAudioSession(); switching.togglePlayback(attachment()); switching.togglePlayback(attachment())
        expect(count("activate") == 2 && count("deactivate") == 1, "switching tracks releases the previous playback session")
        switching.stopPlayback()
        expect(count("deactivate") == 2, "final track stop balances successful activations")

        reset()
        let releaseRetry = CompanionAudioSession(); releaseRetry.togglePlayback(attachment())
        AVAudioSession.deactivationFails = true; releaseRetry.stopPlayback()
        AVAudioSession.deactivationFails = false; releaseRetry.stopPlayback(); releaseRetry.stopPlayback()
        expect(count("deactivate") == 2, "failed deactivation retains ownership for one successful cleanup retry")

        reset()
        let recordingRetry = CompanionAudioSession(); await recordingRetry.startRecording()
        AVAudioSession.deactivationFails = true; _ = recordingRetry.finishRecording()
        AVAudioSession.deactivationFails = false; recordingRetry.stopPlayback(); recordingRetry.stopPlayback()
        expect(count("deactivate") == 2, "idle cleanup retries a stopped recording's failed deactivation once")

        reset()
        var missing = attachment(); missing.data = nil
        let missingAudio = CompanionAudioSession(); missingAudio.togglePlayback(missing)
        expect(AVAudioSession.calls.isEmpty, "missing audio never initializes a system session")
        expect(AVAudioRecorder.files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "owned temporary recordings are removed")
        print("Companion audio lifecycle: \(checks) checks, \(failures) failures; shipping controller with inert framework boundary")
        if failures > 0 { exit(1) }
    }
}
