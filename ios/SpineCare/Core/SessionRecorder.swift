import AVFoundation
import CoreImage
import UIKit

/// Records the session as MP4 with the sensor overlay burned in: each camera
/// frame is composited with the skeleton/metrics/cues (same renderer as the
/// live view) via UIGraphicsImageRenderer + CoreImage, then written through
/// AVAssetWriter. Runs on the camera queue (no main-actor APIs).
final class SessionRecorder {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let width: Int
    private let height: Int
    private var started = false
    private var frameIndex: Int64 = 0
    private let ciContext = CIContext(options: nil)

    init?(url: URL, width: Int, height: Int) {
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        self.width = width; self.height = height
    }

    func append(_ pixelBuffer: CVPixelBuffer, landmarks: [String: Metrics.LM],
                cue: String, metrics: String, reps: String, mirror: Bool,
                orientation: CGImagePropertyOrientation, timestamp _: CMTime) -> Bool {
        guard input.isReadyForMoreMediaData else { return false }
        let time = CMTime(value: frameIndex, timescale: 30)
        if !started {
            started = true
            writer.startSession(atSourceTime: .zero)
        }
        frameIndex += 1

        var ci = CIImage(cvPixelBuffer: pixelBuffer).oriented(forExifOrientation: Int32(orientation.rawValue))
        if mirror {
            ci = ci.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }
        ci = ci.transformed(by: CGAffineTransform(translationX: -ci.extent.origin.x, y: -ci.extent.origin.y))
        let sx = CGFloat(width) / max(ci.extent.width, 1)
        let sy = CGFloat(height) / max(ci.extent.height, 1)
        ci = ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let overlayImage = renderer.image { r in
            OverlayRenderer.draw(cg: r.cgContext, size: CGSize(width: width, height: height),
                                 lms: landmarks, cue: cue, metrics: metrics, reps: reps, mirror: mirror)
        }
        guard let overlayCG = overlayImage.cgImage else { return false }
        let composed = CIImage(cgImage: overlayCG).composited(over: ci)

        var out: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool else { return false }
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out) == kCVReturnSuccess, let ob = out else { return false }
        ciContext.render(composed, to: ob)
        guard adaptor.append(ob, withPresentationTime: time) else { return false }
        return true
    }

    /// Completes the MP4. Without this the file has no movie header and review cannot open it.
    func finish(_ done: @escaping (Bool) -> Void) {
        guard started else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: writer.outputURL)
            DispatchQueue.main.async { done(false) }
            return
        }
        input.markAsFinished()
        writer.finishWriting {
            let ok = self.writer.status == .completed
            if !ok { try? FileManager.default.removeItem(at: self.writer.outputURL) }
            DispatchQueue.main.async { done(ok) }
        }
    }
}
