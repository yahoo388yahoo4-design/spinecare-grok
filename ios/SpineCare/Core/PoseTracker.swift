import Foundation
import AVFoundation
import Vision

/// On-device pose via Apple Vision (VNDetectHumanBodyPoseRequest) — works on
/// every iPhone/iPad, no network. Maps Vision joints into the shared name space
/// used by Metrics/Plan (nose, lear, rear, lsho, rsho, lelb, relb, lwr, rwr,
/// lhip, rhip, lknee, rknee, lank, rank).
final class PoseTracker: NSObject, ObservableObject {
    @Published var landmarks: [String: Metrics.LM] = [:]
    @Published var lastMs: Double = 0

    private let request = VNDetectHumanBodyPoseRequest()

    /// Vision body pose joint names mapped into the shared name space.
    static let jointMap: [VNHumanBodyPoseObservation.JointName: String] = [
        .nose: "nose", .leftEye: "leye", .rightEye: "reye",
        .leftEar: "lear", .rightEar: "rear",
        .leftShoulder: "lsho", .rightShoulder: "rsho",
        .leftElbow: "lelb", .rightElbow: "relb",
        .leftWrist: "lwr", .rightWrist: "rwr",
        .leftHip: "lhip", .rightHip: "rhip",
        .leftKnee: "lknee", .rightKnee: "rknee",
        .leftAnkle: "lank", .rightAnkle: "rank",
    ]

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!, options: [:])
        let t0 = CFAbsoluteTimeGetCurrent()
        try? handler.perform([request])
        guard let obs = request.results?.first else {
            DispatchQueue.main.async { self.landmarks = [:] }
            return
        }
        let points = try? obs.recognizedPoints(.all)
        var out: [String: Metrics.LM] = [:]
        for (joint, name) in Self.jointMap {
            if let pt = points?[joint], pt.confidence > 0.1 {
                out[name] = Metrics.LM(x: Double(pt.x), y: Double(1 - pt.y),
                                       z: 0, conf: Double(pt.confidence))
            }
        }
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        DispatchQueue.main.async { self.landmarks = out; self.lastMs = ms }
    }
}
