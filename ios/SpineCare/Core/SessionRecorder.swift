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
    private var lastTime = CMTime.zero
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
                timestamp: CMTime) {
        guard input.isReadyForMoreMediaData else { return }
        if !started { started = true; writer.startSession(atSourceTime: timestamp) }

        // 1. Camera frame -> upright portrait CIImage (sensor frame is landscape).
        var ci = CIImage(cvPixelBuffer: pixelBuffer)
        // Rotate 90° CW so the portrait-held phone scene is upright, then shift
        // into positive space.
        ci = ci.transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
        ci = ci.transformed(by: CGAffineTransform(translationX: 0, y: ci.extent.height))
        if mirror {
            ci = ci.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            ci = ci.transformed(by: CGAffineTransform(translationX: ci.extent.width, y: 0))
        }
        // Scale to the output canvas.
        let sx = CGFloat(width) / ci.extent.width
        let sy = CGFloat(height) / ci.extent.height
        ci = ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        // 2. Overlay via UIGraphicsImageRenderer (y-down context, thread-safe).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                               format: format)
        let overlayImage = renderer.image { r in
            OverlayRenderer.draw(cg: r.cgContext, size: CGSize(width: width, height: height),
                                 lms: landmarks, cue: cue, metrics: metrics, reps: reps,
                                 mirror: mirror) // landmarks are from the raw frame; flip with the camera
        }
        guard let overlayCG = overlayImage.cgImage else { return }
        let overlayCI = CIImage(cgImage: overlayCG)
        let composed = overlayCI.composited(over: ci)

        // 3. Write into the adaptor's buffer pool.
        var out: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool else { return }
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        guard status == kCVReturnSuccess, let ob = out else { return }
        ciContext.render(composed, to: ob)
        adaptor.append(ob, withPresentationTime: timestamp)
        lastTime = timestamp
    }

    func finish() {
        guard started else { writer.cancelWriting(); return }
        input.markAsFinished()
        writer.endSession(atSourceTime: lastTime)
    }
}
