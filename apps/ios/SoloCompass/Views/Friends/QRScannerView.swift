import AVFoundation
import SwiftUI
import UIKit

/// US-014: a thin SwiftUI wrapper over an `AVCaptureSession` QR reader.
///
/// Streams the *first* decoded `qr` payload back via `onCode`, then stops the
/// session (one-shot — the parent dismisses the scanner on a hit). Camera
/// permission is requested lazily; a denial routes to `onError` so the caller
/// can fall back to manual entry (NSCameraUsageDescription is declared in
/// Info.plist). No frames leave the device.
struct QRScannerView: UIViewControllerRepresentable {
    /// Called once with the raw decoded string on the first QR detection.
    var onCode: (String) -> Void
    /// Called when the camera is unavailable or permission was denied.
    var onError: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: ScannerViewController, coordinator: Coordinator) {
        controller.shutdownCapture()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCode: (String) -> Void
        private let onError: () -> Void
        private var didFire = false

        init(onCode: @escaping (String) -> Void, onError: @escaping () -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func reportError() {
            guard !didFire else { return }
            didFire = true
            onError()
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didFire,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue
            else { return }
            didFire = true
            onCode(value)
        }
    }
}

// MARK: - Capture controller

/// Shared with queued capture work so permission/visibility changes are checked
/// again when an operation actually runs, rather than only when it is queued.
final class ScannerCaptureGate: @unchecked Sendable {
    private let lock = NSLock()
    private var allowed = false

    func update(visible: Bool, foreground: Bool, authorized: Bool) {
        lock.lock()
        allowed = visible && foreground && authorized
        lock.unlock()
    }

    var isAllowed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return allowed
    }
}

/// Owns the `AVCaptureSession`. Starts/stops on appear/disappear and routes
/// permission/setup failures through the coordinator so SwiftUI can recover.
///
/// Lifecycle guard (I25): capture is allowed only while the scanner is on
/// screen and the app is foregrounded. A camera permission callback that
/// resolves AFTER the user left must never start a session on a hidden
/// controller; start/stop requests are serialized through one chained task so
/// a slow `startRunning` can't race past a later stop.
final class ScannerViewController: UIViewController {
    weak var coordinator: QRScannerView.Coordinator?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// The single gate every start path re-checks (visible + foreground).
    private let captureGate = ScannerCaptureGate()
    private var isCaptureAllowed: Bool { captureGate.isAllowed }
    /// Whether the scanner is currently on screen.
    private var isViewVisible = false
    /// FIFO chain serializing `startRunning` / `stopRunning` calls.
    private var sessionOpTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnteredBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        requestAccessThenConfigure()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isViewVisible = true
        allowCapture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        denyCapture()
    }

    @objc private func handleEnteredBackground() {
        // The camera must never keep running behind another app.
        denyCapture()
    }

    @objc private func handleWillEnterForeground() {
        // Restore capture only if the scanner is still on screen.
        if isViewVisible { allowCapture() }
    }

    /// Entering screen/foreground: set up (once) and start capture.
    private func allowCapture() {
        let foreground = UIApplication.shared.applicationState == .active
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        captureGate.update(visible: isViewVisible, foreground: foreground, authorized: status == .authorized)
        guard isCaptureAllowed else {
            if isViewVisible && foreground && (status == .denied || status == .restricted) {
                coordinator?.reportError()
            }
            return
        }
        configureSession()
        startIfPossible()
    }

    /// Leaving the screen or backgrounding: stop capture and invalidate any
    /// in-flight permission grant (its callback re-checks `isCaptureAllowed`).
    private func denyCapture() {
        captureGate.update(visible: false, foreground: false, authorized: false)
        stopSession()
    }

    func shutdownCapture() {
        isViewVisible = false
        denyCapture()
        coordinator = nil
    }

    // MARK: - Setup

    private func requestAccessThenConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // `viewWillAppear` starts only after visibility is established.
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.isViewVisible else { return }
                    if granted {
                        self.allowCapture()
                    } else if UIApplication.shared.applicationState == .active {
                        self.coordinator?.reportError()
                    }
                }
            }
        default:
            coordinator?.reportError()
        }
    }

    private func configureSession() {
        guard isCaptureAllowed, AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              previewLayer == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            coordinator?.reportError()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            coordinator?.reportError()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func startIfPossible() {
        guard isCaptureAllowed, previewLayer != nil else { return }
        enqueueSessionOp { [session, captureGate] in
            guard captureGate.isAllowed else { return }
            if !session.isRunning { session.startRunning() }
        }
    }

    private func stopSession() {
        enqueueSessionOp { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Serializes session start/stop in FIFO order: each operation awaits the
    /// previous one, so a slow start can never outrun a later stop request.
    private func enqueueSessionOp(_ op: @escaping @Sendable () -> Void) {
        let previous = sessionOpTask
        sessionOpTask = Task.detached {
            await previous?.value
            op()
        }
    }
}
