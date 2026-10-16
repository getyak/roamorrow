import Foundation

// MARK: - VoiceInteractionLifecycle

/// Token-guarded lifecycle for the VoiceButton press → permission → record
/// pipeline (contract 4).
///
/// The old button fired an unowned `Task { await requestPermission() }` and
/// started recording whenever the prompt resolved — even if the finger had
/// already lifted, the button had disappeared, or the app had gone to the
/// background. Every transition here returns an `Effect` the view applies, so
/// the decision logic is injectable and unit-testable WITHOUT ever touching
/// the microphone or prompting for permission (tests drive
/// `permissionResolved` manually).
///
/// Rules encoded here:
///   - releasing before the permission prompt resolves kills the pending start
///     (no late recording);
///   - disappearing / going inactive / backgrounding stops an active
///     recording WITHOUT sending, and also kills pending starts;
///   - VoiceOver's default activation toggles start/stop like the advertised
///     hint says (the named action is not the only path);
///   - the 60s auto-stop keeps the existing send-the-transcript behavior.
@MainActor
public final class VoiceInteractionLifecycle {
    /// What the view should do in response to a lifecycle transition.
    public enum Effect: Equatable, Sendable {
        /// Ask for speech/microphone permission for `token`, then call
        /// `permissionResolved(token:granted:)`.
        case requestPermission(token: Int)
        /// Permission landed and everything is still valid — start listening.
        case startRecording(token: Int)
        /// Stop recording and deliver the transcript (release / auto-stop).
        case stopAndSend
        /// Stop recording and discard the transcript (cancel, hide, background).
        case stopWithoutSending
        /// Permission was denied for the CURRENT attempt — surface the
        /// explanation. Stale denials return `.none` (the user already moved on).
        case permissionDenied
        /// Nothing to do.
        case none
    }

    /// True while the microphone stream should be running.
    public private(set) var isRecording = false
    /// True while a start intent is active (finger held / VoiceOver toggle on).
    public private(set) var wantsRecording = false
    /// Token of the in-flight permission/start attempt; nil when none.
    public private(set) var activeToken: Int?

    private var nextToken = 0
    private var isVisible = true
    private var isSceneActive = true

    public init() {}

    // MARK: Start pipeline

    /// The user asked to start (long-press threshold reached, or VoiceOver
    /// default/named action). Returns a permission request unless the view is
    /// hidden, the scene inactive, or a recording is already running.
    public func beginStart() -> Effect {
        guard !isRecording, canStart else { return .none }
        // A new start supersedes any pending one.
        nextToken += 1
        activeToken = nextToken
        wantsRecording = true
        return .requestPermission(token: nextToken)
    }

    /// The permission (or any async precondition) for `token` resolved.
    /// Only a grant for the CURRENT token, with the intent still alive and the
    /// view still visible/foreground, may start recording.
    public func permissionResolved(token: Int, granted: Bool) -> Effect {
        guard granted else {
            if token == activeToken {
                wantsRecording = false
                activeToken = nil
                return .permissionDenied
            }
            return .none
        }
        guard token == activeToken, wantsRecording, canStart, !isRecording else {
            return .none
        }
        activeToken = nil
        isRecording = true
        return .startRecording(token: token)
    }

    // MARK: Stop paths

    /// Pointer release: while recording this sends; before auth it cancels the
    /// pending start so a late permission can never begin recording.
    public func pressReleased() -> Effect {
        if isRecording {
            return finish(send: true)
        }
        wantsRecording = false
        activeToken = nil
        return .none
    }

    /// VoiceOver default (double-tap) / named action: toggles exactly as the
    /// accessibility hint advertises — start when idle (or pending), stop and
    /// send when recording.
    public func accessibilityToggle() -> Effect {
        if isRecording {
            return finish(send: true)
        }
        if wantsRecording {
            // Second activation while the prompt is up: cancel, don't stack.
            wantsRecording = false
            activeToken = nil
            return .none
        }
        return beginStart()
    }

    /// The 60s auto-stop fired. Keeps the pre-existing behavior: deliver the
    /// transcript (the user spoke — auto-stop is not a discard).
    public func autoStopElapsed() -> Effect {
        guard isRecording else { return .none }
        return finish(send: true)
    }

    /// Slide-up-to-cancel: discard the transcript.
    public func cancelRequested() -> Effect {
        if isRecording {
            return finish(send: false)
        }
        wantsRecording = false
        activeToken = nil
        return .none
    }

    /// The recognition stream failed on its own; reset so the user can retry.
    public func recordingAborted() -> Effect {
        let wasRecording = isRecording
        isRecording = false
        wantsRecording = false
        activeToken = nil
        return wasRecording ? .stopWithoutSending : .none
    }

    // MARK: Lifecycle guards

    /// Visibility change (onDisappear / reappear). Going away stops recording
    /// WITHOUT sending and kills any pending start.
    public func visibilityChanged(_ visible: Bool) -> Effect {
        isVisible = visible
        return lifecycleGuardEffect()
    }

    /// Scene activity change (.active / .inactive / .background). Losing
    /// foreground stops recording WITHOUT sending — never a silent late send.
    public func sceneActivityChanged(_ active: Bool) -> Effect {
        isSceneActive = active
        return lifecycleGuardEffect()
    }

    // MARK: Private

    private var canStart: Bool { isVisible && isSceneActive }

    private func lifecycleGuardEffect() -> Effect {
        guard !canStart else { return .none }
        if isRecording {
            return finish(send: false)
        }
        wantsRecording = false
        activeToken = nil
        return .none
    }

    private func finish(send: Bool) -> Effect {
        isRecording = false
        wantsRecording = false
        activeToken = nil
        return send ? .stopAndSend : .stopWithoutSending
    }
}

/// The audio service owns one capture epoch. Late recognition callbacks and
/// stream termination may clean up only the epoch that created them.
struct VoiceCaptureGeneration: Sendable {
    private(set) var current: UUID?
    mutating func begin() -> UUID {
        let token = UUID()
        current = token
        return token
    }
    func isCurrent(_ token: UUID) -> Bool { current == token }
    @discardableResult
    mutating func finish(token: UUID? = nil) -> Bool {
        guard let current, token == nil || token == current else { return false }
        self.current = nil
        return true
    }
}
