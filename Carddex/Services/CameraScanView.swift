import SwiftUI
import AVFoundation
import Vision

/// Live camera + on-device OCR streaming + on-demand still capture.
/// Real devices only — the simulator has no camera, and `isSupported`
/// reports that so `ScanView` can fall back to a simulated scan.
///
/// Replaces the earlier VisionKit `DataScannerViewController` wrapper, which
/// streamed text but had no way to capture a still frame — so the identify
/// call was shipping an empty image. Owning the `AVCaptureSession` lets us
/// feed a real JPEG to the `identify` Edge Function (the plan's "custom
/// AVFoundation capture path for the real card photo").
struct CameraScanView: UIViewControllerRepresentable {
    var onText: ([String]) -> Void

    static var isSupported: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController()
    }

    func updateUIViewController(_ controller: CameraViewController, context: Context) {
        controller.onText = onText
    }

    /// Capture a still JPEG from the live session. Returns nil when the
    /// session isn't running, the camera isn't authorized, or capture fails —
    /// the caller treats nil as "no image" so the OCR text hint still ships.
    static func capturePhoto() async -> Data? {
        await CameraSessionController.shared.capturePhoto()
    }
}

/// Hosts the `AVCaptureVideoPreviewLayer` and ties the shared session's
/// lifetime to the view's appearance.
@MainActor
final class CameraViewController: UIViewController {
    var onText: (([String]) -> Void)? {
        didSet { CameraSessionController.shared.onText = onText }
    }
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let controller = CameraSessionController.shared
        previewLayer.session = controller.session
        controller.onText = onText
        controller.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraSessionController.shared.stop()
    }
}

/// Owns the single `AVCaptureSession` shared by the preview layer and the
/// Scan flow. `@MainActor` for the session lifecycle + capture continuation;
/// AVFoundation delegate callbacks hop back here from background queues.
@MainActor
final class CameraSessionController {
    static let shared = CameraSessionController()

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ocrQueue = DispatchQueue(label: "carddex.ocr")
    // `lazy` so the closures can capture `self` safely — they're only built
    // on first access (post-init), from a MainActor context.
    private lazy var photoDelegate: PhotoCaptureDelegate = {
        PhotoCaptureDelegate { [weak self] data in
            Task { @MainActor [weak self] in self?.completeCapture(data) }
        }
    }()
    private lazy var ocrDelegate: OCRDelegate = {
        OCRDelegate { [weak self] lines in
            Task { @MainActor [weak self] in self?.onText?(lines) }
        }
    }()
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<Data?, Never>?

    var onText: (([String]) -> Void)?

    private init() {}

    func start() {
        configure()
        Task {
            guard await requestAccessIfNeeded() else { return }
            ocrQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
            }
        }
    }

    func stop() {
        ocrQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto() async -> Data? {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              session.isRunning,
              captureContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            photoOutput.capturePhoto(with: settings, delegate: photoDelegate)
        }
    }

    private func completeCapture(_ data: Data?) {
        captureContinuation?.resume(returning: data)
        captureContinuation = nil
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configure() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration(); isConfigured = true }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.setSampleBufferDelegate(ocrDelegate, queue: ocrQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }
}

/// Non-isolated photo delegate — invoked by AVFoundation on a background queue.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let onComplete: @Sendable (Data?) -> Void
    init(onComplete: @escaping @Sendable (Data?) -> Void) {
        self.onComplete = onComplete
        super.init()
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        onComplete(photo.fileDataRepresentation())
    }
}

/// Non-isolated OCR delegate — invoked on `ocrQueue`. Runs a throttled,
/// `.fast` Vision pass on sampled frames and emits recognized text lines.
/// Streaming OCR is only a hint for the backend (which re-runs OCR on the
/// JPEG); `.fast` + a 1s throttle keeps CPU/battery in check during long
/// scan sessions.
private final class OCRDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let onText: @Sendable ([String]) -> Void
    private var lastEmit: Date = .distantPast
    private let throttle: TimeInterval = 1.0

    init(onText: @escaping @Sendable ([String]) -> Void) {
        self.onText = onText
        super.init()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastEmit) > throttle else { return }
        lastEmit = now

        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            if !lines.isEmpty { self.onText(lines) }
        }
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])
    }
}
