import SwiftUI
import AVFoundation
import QuartzCore
import UIKit

/// Real-time coaching session: camera -> Vision pose -> metrics/framing/reps,
/// with optional GPU-server enhancement (AUTO mode falls back on drop).
/// Supports front/back camera switching and session recording with the sensor
/// overlay burned into the video (review in the Sessions tab).
struct ExerciseSessionView: View {
    let exercise: Exercise
    @StateObject private var tracker = PoseTracker()
    @State private var running = false
    @State private var reps = 0
    @State private var cue = ""
    @State private var metricsText = ""
    @State private var engine = RepEngine(low: 0, high: 0)
    @State private var serverConnected = false
    @State private var frontCamera = false
    @State private var recording = ServerConfig.shared.recordSessions
    @State private var zoom: Double = 1
    @State private var lens = "wide"
    @State private var lenses = ["wide"]
    @State private var saved = false
    @ObservedObject private var orientation = OrientationController.shared
    private let frameSink = FrameSink()
    @State private var recorder: SessionRecorder?
    @State private var recordedFrames = 0
    @State private var videoURL: URL?
    private let client = ServerClient()

    var body: some View {
        ZStack(alignment: .top) {
            CameraPreview(tracker: tracker, frontCamera: frontCamera, zoom: zoom, lens: lens,
                          onLenses: { lenses = $0 }) { buf in
                frameSink.set(buf)
            }
            .ignoresSafeArea()

            // Live skeleton + HUD overlay (same renderer as the recording)
            OverlayCanvas(landmarks: tracker.landmarks, cue: cue, metrics: metricsText,
                          reps: "\(reps)/\(exercise.targetReps)",
                          mirror: CameraOrientation.bufferUpright && frontCamera)
                .ignoresSafeArea()
            VStack {
                Text("\(exercise.name) — \(exercise.view.uppercased()) view\n\(exercise.description)")
                    .font(.callout).padding(8)
                    .background(.black.opacity(0.6)).foregroundStyle(.white)
                Spacer()
                Text(cue).font(.subheadline).padding(8)
                    .background(.black.opacity(0.7)).foregroundStyle(.yellow)
                Text(metricsText).font(.system(.caption, design: .monospaced))
                    .padding(6).background(.black.opacity(0.7)).foregroundStyle(.white)
                HStack {
                    Slider(value: $zoom, in: 1...5, step: 0.1)
                    Text(String(format: "%.1fx", zoom))
                        .font(.caption.monospacedDigit()).foregroundStyle(.white).frame(width: 44)
                }.padding(.horizontal)
                HStack {
                    ForEach(lenses, id: \.self) { item in
                        Button(lensTitle(item)) {
                            lens = item
                            zoom = 1
                        }
                        .buttonStyle(.bordered)
                        .tint(lens == item ? .green : .white)
                    }
                    Button(orientation.landscape ? "Portrait" : "Landscape") {
                        orientation.rotate()
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Button(running ? "Stop & Save" : "Start") { toggle() }
                        .buttonStyle(.borderedProminent)
                    Button("Flip") { frontCamera.toggle() }
                        .buttonStyle(.bordered)
                    Button(recording ? "Rec: On" : "Rec: Off") {
                        recording.toggle(); ServerConfig.shared.recordSessions = recording
                    }
                    .buttonStyle(.bordered)
                    Button("Mode: \(modeLabel())") { cycleMode() }
                        .buttonStyle(.bordered)
                }.padding()
            }
            Text("\(reps)/\(exercise.targetReps)")
                .font(.system(size: 44, weight: .bold)).foregroundStyle(.green)
                .shadow(radius: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding()
        }
        .navigationTitle(exercise.name)
        .onAppear { cue = "Position the camera: \(exercise.view.uppercased()) view." }
        .onDisappear {
            client.disconnect()
            if running { running = false; persist() }
        }
        .onChange(of: frontCamera) { _ in zoom = 1 }
        .onChange(of: tracker.landmarks) { lms in score(lms) }
    }

    private func lensTitle(_ id: String) -> String {
        switch id {
        case "ultra": return "Ultra"
        case "tele": return "Tele"
        default: return "Wide"
        }
    }

    private func modeLabel() -> String {
        switch ServerConfig.shared.mode {
        case .auto: return "Auto"
        case .onDevice: return "On-device"
        case .server: return "GPU server"
        }
    }

    private func cycleMode() {
        ServerConfig.shared.mode = ServerConfig.Mode(rawValue: (ServerConfig.shared.mode.rawValue + 1) % 3)!
        ServerConfig.shared.save()
    }

    /// Local scoring: framing gate -> metrics -> rep engine -> form rules.
    private func score(_ lms: [String: Metrics.LM]) {
        guard running else { return }
        captureFrame()
        let framing = FramingGuide.check(lms.isEmpty ? nil : lms,
                                         required: exercise.requiredLandmarks,
                                         minConf: exercise.minConf, frameW: 1, frameH: 1)
        guard framing.ready else {
            cue = "Camera: " + framing.issues.map(FramingGuide.fixFor).joined(separator: " ")
            return
        }
        let metrics = Metrics.compute(lms)
        let sig = signalValue(metrics, exercise.signal)
        let now = Date().timeIntervalSince1970
        if engine.update(sig, now) { reps = engine.reps; cue = "Rep \(reps)/\(exercise.targetReps) ✓" }
        for rule in exercise.formRules {
            if let v = metrics[rule.metric], abs(v) > rule.maxAbs { cue = rule.cue; break }
        }
        metricsText = metrics.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: "  ")
            + "\npose=\(String(format: "%.0f", tracker.lastMs))ms \(serverConnected ? "GPU" : "on-device")"
    }

    private func captureFrame() {
        guard let rec = recorder, let buf = frameSink.get(),
              let pb = CMSampleBufferGetImageBuffer(buf) else { return }
        let ok = rec.append(pb, landmarks: tracker.landmarks, cue: cue, metrics: metricsText,
                            reps: "\(reps)/\(exercise.targetReps)",
                            mirror: CameraOrientation.bufferUpright && frontCamera,
                            orientation: CameraOrientation.vision(front: frontCamera),
                            timestamp: CMSampleBufferGetPresentationTimeStamp(buf))
        if ok { recordedFrames += 1 }
    }

    private func toggle() {
        running.toggle()
        if running {
            saved = false
            engine = RepEngine(low: exercise.repLow, high: exercise.repHigh)
            reps = 0; recordedFrames = 0
            cue = "Calibrate: adopt neutral posture, then begin. Stop on: \(exercise.stopConditions.joined(separator: ", "))"
            if recording { startRecorder() }
            if ServerConfig.shared.mode != .onDevice {
                client.connect(ServerConfig.shared.url, user: ServerConfig.shared.user,
                               pass: ServerConfig.shared.pass) { [self] msg in
                    if (msg["type"] as? String) == "pose" {
                        serverConnected = true
                        if let r = msg["reps"] as? Int { reps = r }
                        if let cues = msg["cues"] as? [[String: Any]], let c = cues.first?["cue"] as? String { cue = c }
                    }
                }
                client.send(["type": "session", "exercise_id": exercise.id])
            }
        } else {
            client.disconnect(); serverConnected = false
            persist()
        }
    }

    private func lastMetricsSnapshot() -> [String: Double] {
        // Parse the latest metrics line back into values for the store.
        var out: [String: Double] = [:]
        for token in metricsText.split(separator: " ") {
            let parts = token.split(separator: "=")
            if parts.count == 2, let v = Double(parts[1]) { out[String(parts[0])] = v }
        }
        return out
    }

    private func startRecorder() {
        let landscape = CameraOrientation.interfaceOrientation().isLandscape
        let url = SessionStore.recordingsDir()
            .appendingPathComponent("session_\(exercise.id)_\(Int(Date().timeIntervalSince1970)).mp4")
        let size = landscape ? (w: 1280, h: 720) : (w: 720, h: 1280)
        recorder = SessionRecorder(url: url, width: size.w, height: size.h)
        videoURL = recorder == nil ? nil : url
    }

    /// Writes the MP4 header, then stores the session. Review opens this file.
    private func persist() {
        guard !saved else { return }
        saved = true
        let rec = recorder
        let frames = recordedFrames
        let url = videoURL
        let repsNow = reps
        let metrics = lastMetricsSnapshot()
        let seen = tracker.landmarks.count
        let source = serverConnected ? "gpu-server" : "on-device"
        let exerciseId = exercise.id
        recorder = nil
        let store: (URL?) -> Void = { video in
            SessionStore.shared.save(exerciseId: exerciseId, reps: repsNow, metrics: metrics, cues: [:],
                                     frames: max(seen, frames), source: source,
                                     videoURL: video, recordedFrames: frames)
        }
        if let rec {
            rec.finish { ok in store(ok ? url : nil) }
        } else {
            store(nil)
        }
    }
}

/// Thread-safe holder for the latest camera sample buffer (written on the
/// camera queue, read on the main thread when scoring a frame).
final class FrameSink {
    private let lock = NSLock()
    private var buf: CMSampleBuffer?
    func set(_ b: CMSampleBuffer) { lock.lock(); buf = b; lock.unlock() }
    func get() -> CMSampleBuffer? { lock.lock(); defer { lock.unlock() }; return buf }
}

/// SwiftUI overlay drawing the skeleton + HUD, mirroring the camera preview.
struct OverlayCanvas: View {
    let landmarks: [String: Metrics.LM]
    let cue: String
    let metrics: String
    let reps: String
    let mirror: Bool

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                OverlayRenderer.draw(ctx: &ctx, size: size, lms: landmarks,
                                     cue: cue, metrics: metrics, reps: reps, mirror: mirror)
            }
        }
    }
}

/// UIViewRepresentable wrapping AVCaptureSession + Vision processing.
/// The preview layer is resized whenever the view lays out (a zero-size layer
/// was the black preview), and the frame delegate is retained.
struct CameraPreview: UIViewRepresentable {
    let tracker: PoseTracker
    let frontCamera: Bool
    let zoom: Double
    let lens: String
    let onLenses: ([String]) -> Void
    let onFrame: (CMSampleBuffer) -> Void

    func makeUIView(context: Context) -> CameraHostView {
        let view = CameraHostView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.session
        context.coordinator.host = view
        view.onLayout = { [weak coord = context.coordinator] in coord?.applyConnection() }
        AVCaptureCamera.shared.requestPermission { granted in
            if granted { context.coordinator.reconfigure(front: frontCamera, lens: lens) }
        }
        return view
    }

    func updateUIView(_ uiView: CameraHostView, context: Context) {
        context.coordinator.host = uiView
        context.coordinator.onLenses = onLenses
        context.coordinator.reconfigure(front: frontCamera, lens: lens)
        context.coordinator.setZoom(CGFloat(zoom))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tracker: tracker, onFrame: onFrame, onLenses: onLenses)
    }

    final class CameraHostView: UIView {
        let previewLayer = AVCaptureVideoPreviewLayer()
        var onLayout: (() -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(previewLayer)
        }
        required init?(coder: NSCoder) { return nil }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
            onLayout?()
        }
    }

    final class Coordinator {
        let session = AVCaptureSession()
        let tracker: PoseTracker
        let onFrame: (CMSampleBuffer) -> Void
        var onLenses: ([String]) -> Void
        weak var host: CameraHostView?
        private let queue = DispatchQueue(label: "spinecare.camera")
        private var input: AVCaptureDeviceInput?
        private var appliedFront: Bool?
        private var appliedLens: String?
        private var frameDelegate: FrameDelegate?
        private var started = false
        private var rotationCoordinator: Any?
        private var rotationObservation: NSKeyValueObservation?
        private var previewAngle: CGFloat = 90
        private var captureAngle: CGFloat = 90

        init(tracker: PoseTracker, onFrame: @escaping (CMSampleBuffer) -> Void, onLenses: @escaping ([String]) -> Void) {
            self.tracker = tracker
            self.onFrame = onFrame
            self.onLenses = onLenses
            session.sessionPreset = .hd1280x720
        }

        func reconfigure(front: Bool, lens: String) {
            guard AVCaptureCamera.shared.authorized else { return }
            if appliedFront == front && appliedLens == lens && started { return }
            appliedFront = front
            appliedLens = lens
            queue.async { [weak self] in self?.configure(front: front, lens: lens) }
        }

        private var appliedZoom: CGFloat = -1

        func setZoom(_ factor: CGFloat) {
            queue.async { [weak self] in
                guard let self, let device = self.input?.device else { return }
                if abs(self.appliedZoom - factor) <= 0.04 { return }
                do {
                    try device.lockForConfiguration()
                    let maxZ = min(device.activeFormat.videoMaxZoomFactor, 5)
                    let minZ = max(device.minAvailableVideoZoomFactor, 1)
                    device.videoZoomFactor = min(max(factor, minZ), maxZ)
                    device.unlockForConfiguration()
                    self.appliedZoom = device.videoZoomFactor
                } catch {}
            }
        }

        private func configure(front: Bool, lens: String) {
            let position: AVCaptureDevice.Position = front ? .front : .back
            let choices = Self.lenses(position)
            DispatchQueue.main.async { self.onLenses(choices) }
            guard let cam = Self.device(lens, position: position) else { return }
            session.beginConfiguration()
            if let old = input { session.removeInput(old) }
            guard let newInput = try? AVCaptureDeviceInput(device: cam), session.canAddInput(newInput) else {
                session.commitConfiguration()
                return
            }
            session.addInput(newInput)
            input = newInput
            appliedZoom = -1
            if session.outputs.isEmpty {
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                let interval = max(0.05, Double(ServerConfig.shared.frameIntervalMs) / 1000)
                let delegate = FrameDelegate(tracker: tracker, minInterval: interval, onFrame: onFrame)
                frameDelegate = delegate
                output.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "spinecare.pose"))
                if session.canAddOutput(output) { session.addOutput(output) }
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
            started = true
            let device = newInput.device
            DispatchQueue.main.async { [weak self] in
                self?.installRotation(device: device)
            }
        }

        /// Keeps the face upright: portrait phone shows a vertical face, and so does landscape.
        private func installRotation(device: AVCaptureDevice) {
            if #available(iOS 17.0, *) {
                guard let layer = host?.previewLayer else { return }
                let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
                rotationCoordinator = coordinator
                rotationObservation = coordinator.observe(
                    \.videoRotationAngleForHorizonLevelPreview,
                    options: [.initial, .new]
                ) { [weak self] coordinator, _ in
                    let preview = coordinator.videoRotationAngleForHorizonLevelPreview
                    let capture = coordinator.videoRotationAngleForHorizonLevelCapture
                    DispatchQueue.main.async {
                        self?.applyAngles(preview: preview, capture: capture)
                    }
                }
            } else {
                applyLegacyAngles()
            }
        }

        func applyConnection() {
            if #available(iOS 17.0, *) {
                if rotationCoordinator == nil, let device = input?.device {
                    installRotation(device: device)
                    return
                }
                applyAngles(preview: previewAngle, capture: captureAngle)
            } else {
                applyLegacyAngles()
            }
        }

        @available(iOS 17.0, *)
        private func applyAngles(preview: CGFloat, capture: CGFloat) {
            previewAngle = preview
            captureAngle = capture
            let front = appliedFront ?? false
            if let conn = host?.previewLayer.connection {
                if conn.isVideoRotationAngleSupported(preview) {
                    conn.videoRotationAngle = preview
                }
                if conn.isVideoMirroringSupported {
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = front
                }
            }
            queue.async { [weak self] in
                self?.rotateCaptureConnection(angle: capture, front: front)
            }
        }

        private func applyLegacyAngles() {
            let front = appliedFront ?? false
            let orientation = CameraOrientation.captureOrientation()
            if let conn = host?.previewLayer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = orientation
                if conn.isVideoMirroringSupported {
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = front
                }
            }
            queue.async { [weak self] in
                guard let self,
                      let output = self.session.outputs.compactMap({ $0 as? AVCaptureVideoDataOutput }).first,
                      let conn = output.connection(with: .video),
                      conn.isVideoOrientationSupported else { return }
                conn.videoOrientation = orientation
                DispatchQueue.main.async {
                    CameraOrientation.bufferUpright = true
                    self.frameDelegate?.orientation = .up
                }
            }
        }

        private func rotateCaptureConnection(angle: CGFloat, front: Bool) {
            guard let output = session.outputs.compactMap({ $0 as? AVCaptureVideoDataOutput }).first,
                  let conn = output.connection(with: .video) else { return }
            var upright = false
            if #available(iOS 17.0, *), conn.isVideoRotationAngleSupported(angle) {
                conn.videoRotationAngle = angle
                upright = true
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = CameraOrientation.captureOrientation()
                upright = true
            }
            DispatchQueue.main.async { [weak self] in
                CameraOrientation.bufferUpright = upright
                self?.frameDelegate?.orientation = CameraOrientation.vision(front: front)
            }
        }

        private static func lenses(_ position: AVCaptureDevice.Position) -> [String] {
            var out: [String] = []
            if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: position) != nil { out.append("ultra") }
            if AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil { out.append("wide") }
            if AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: position) != nil { out.append("tele") }
            return out.isEmpty ? ["wide"] : out
        }

        private static func device(_ lens: String, position: AVCaptureDevice.Position) -> AVCaptureDevice? {
            let type: AVCaptureDevice.DeviceType
            switch lens {
            case "ultra": type = .builtInUltraWideCamera
            case "tele": type = .builtInTelephotoCamera
            default: type = .builtInWideAngleCamera
            }
            return AVCaptureDevice.default(type, for: .video, position: position)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video)
        }
    }
}

enum CameraOrientation {
    /// True once the capture connection itself rotates the buffer upright.
    static var bufferUpright = false

    static func interfaceOrientation() -> UIInterfaceOrientation {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
    }

    /// Device landscape is the opposite of the video connection's landscape.
    static func captureOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        case .portrait: return .portrait
        default:
            switch interfaceOrientation() {
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            case .portraitUpsideDown: return .portraitUpsideDown
            default: return .portrait
            }
        }
    }

    static func vision(front: Bool) -> CGImagePropertyOrientation {
        if bufferUpright { return .up }
        return current(front: front)
    }

    /// Used only when the buffer is still in sensor orientation.
    static func current(front: Bool) -> CGImagePropertyOrientation {
        switch interfaceOrientation() {
        case .landscapeLeft:
            return front ? .upMirrored : .down
        case .landscapeRight:
            return front ? .downMirrored : .up
        case .portraitUpsideDown:
            return front ? .rightMirrored : .left
        default:
            return front ? .leftMirrored : .right
        }
    }
}

/// Permission helper shared by all camera users.
final class AVCaptureCamera {
    static let shared = AVCaptureCamera()
    var authorized = false
    func requestPermission(_ done: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true; done(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                self?.authorized = ok
                DispatchQueue.main.async { done(ok) }
            }
        default: authorized = false; done(false)
        }
    }
}

final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let tracker: PoseTracker
    private let minInterval: TimeInterval
    private let onFrame: (CMSampleBuffer) -> Void
    private let lock = NSLock()
    private var storedOrientation: CGImagePropertyOrientation = .right
    var orientation: CGImagePropertyOrientation {
        get { lock.lock(); defer { lock.unlock() }; return storedOrientation }
        set { lock.lock(); storedOrientation = newValue; lock.unlock() }
    }
    private var lastT = Date.distantPast
    init(tracker: PoseTracker, minInterval: TimeInterval, onFrame: @escaping (CMSampleBuffer) -> Void) {
        self.tracker = tracker; self.minInterval = minInterval; self.onFrame = onFrame
    }

    func captureOutput(_ out: AVCaptureOutput, didOutput buf: CMSampleBuffer, from conn: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastT) >= minInterval,
              CMSampleBufferGetImageBuffer(buf) != nil else { return }
        lastT = now
        onFrame(buf)
        tracker.process(buf, orientation: orientation)
    }
}
