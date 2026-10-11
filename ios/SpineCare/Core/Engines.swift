import Foundation

/// Shared body-segment metrics, mirroring server pose.py and Android Metrics.kt.
/// Landmarks: Vision body-pose joints mapped into a common name space.
/// All angles degrees. ESTIMATES only — not vertebral measurements.
enum Metrics {
    struct LM: Equatable { var x: Double; var y: Double; var z: Double; var conf: Double }

    private static func mid(_ a: LM, _ b: LM) -> LM {
        LM(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, z: (a.z + b.z) / 2, conf: min(a.conf, b.conf))
    }
    private static func angBetween(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let n1 = hypot(x1, y1), n2 = hypot(x2, y2)
        if n1 < 1e-6 || n2 < 1e-6 { return .nan }
        return acos(max(-1, min(1, (x1*x2 + y1*y2) / (n1*n2)))) * 180 / .pi
    }
    private static func angFromVertical(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
        angBetween(bx - ax, by - ay, 0, 1)
    }

    /// lms keys: nose, lear, rear, lsho, rsho, lelb, relb, lwr, rwr, lhip, rhip, lknee, rknee, lank, rank
    static func compute(_ lms: [String: LM]) -> [String: Double] {
        var out: [String: Double] = [:]
        func vis(_ k: String) -> Bool { (lms[k]?.conf ?? 0) > 0.5 }
        guard let lsho = lms["lsho"], let rsho = lms["rsho"],
              let lhip = lms["lhip"], let rhip = lms["rhip"],
              let lear = lms["lear"], let rear = lms["rear"], let nose = lms["nose"]
        else { return out }
        let shoMid = mid(lsho, rsho), hipMid = mid(lhip, rhip), earMid = mid(lear, rear)
        let torsoLen = max(hypot(shoMid.x - hipMid.x, shoMid.y - hipMid.y), 1e-3)
        let shoW = max(hypot(lsho.x - rsho.x, lsho.y - rsho.y), 1e-3)

        if vis("lsho") && vis("rsho") && vis("lhip") && vis("rhip") {
            out["trunk_tilt_frontal"] = angFromVertical(shoMid.x, shoMid.y, hipMid.x, hipMid.y)
            out["head_forward_proxy"] = (earMid.x - shoMid.x) / torsoLen
        }
        if vis("lear") && vis("rear") && vis("lsho") && vis("rsho") {
            out["cervical_tilt"] = angFromVertical(earMid.x, earMid.y, shoMid.x, shoMid.y)
        }
        // Signed lateral nose offset vs shoulder midline (front view). Ear-separation
        // proxies collapse when an ear occludes during rotation; nose stays visible.
        if vis("nose") && vis("lsho") && vis("rsho") {
            let noseDx = nose.x - shoMid.x
            let ratio = max(-1, min(1, noseDx / (0.28 * shoW)))
            out["neck_yaw_est"] = asin(ratio) * 180 / .pi
        }
        if vis("lsho") && vis("rsho") {
            let deg = atan2(rsho.y - lsho.y, rsho.x - lsho.x) * 180 / .pi
            let w = (deg + 90).truncatingRemainder(dividingBy: 180)
            out["shoulder_line_tilt"] = (w < 0 ? w + 180 : w) - 90
        }
        if vis("nose") && vis("lear") && vis("lsho") {
            out["cervical_sag_proxy"] = angBetween(nose.x - earMid.x, nose.y - earMid.y,
                                                   shoMid.x - earMid.x, shoMid.y - earMid.y)
        }
        return out
    }
}

/// Hysteresis rep counter — mirrors server RepEngine.
final class RepEngine {
    enum Phase { case rest, out, inn }
    private let low: Double, high: Double, minHold: TimeInterval
    private(set) var phase = Phase.rest
    private(set) var reps = 0
    private var tEnter: TimeInterval = 0
    init(low: Double, high: Double, minHold: TimeInterval = 0.4) {
        self.low = low; self.high = high; self.minHold = minHold
    }
    @discardableResult
    func update(_ value: Double?, _ t: TimeInterval) -> Bool {
        guard let v = value, !v.isNaN else { return false }
        var done = false
        switch phase {
        case .rest: if v >= high { phase = .out; tEnter = t }
        case .out:  if v <= low {
                        if t - tEnter >= minHold { reps += 1; done = true }
                        phase = .inn; tEnter = t
                     }
        case .inn:  if v >= high { phase = .out; tEnter = t }
        }
        return done
    }
}

/// Framing verification — mirrors server framing_check.
enum FramingGuide {
    static func check(_ lms: [String: Metrics.LM]?, required: [String], minConf: Double,
                      frameW: Int, frameH: Int, margin: Double = 0.03) -> (ready: Bool, issues: [String], missing: [String]) {
        guard let lms else { return (false, ["no_person"], required) }
        var issues: [String] = [], missing: [String] = []
        for name in required {
            guard let lm = lms[name] else { missing.append(name); issues.append("\(name):low_conf"); continue }
            if lm.conf < minConf { missing.append(name); issues.append("\(name):low_conf") }
            else if !(margin*Double(frameW) <= lm.x*Double(frameW) && lm.x*Double(frameW) <= (1-margin)*Double(frameW)
                      && margin*Double(frameH) <= lm.y*Double(frameH) && lm.y*Double(frameH) <= (1-margin)*Double(frameH)) {
                missing.append(name); issues.append("\(name):out_of_frame")
            }
        }
        return (missing.isEmpty, issues, missing)
    }
    static func fixFor(_ issue: String) -> String {
        if issue.hasSuffix(":low_conf") { return "Landmark not clearly detected — improve lighting or move closer." }
        if issue.hasSuffix(":out_of_frame") { return "A required body part is near the edge — step back or re-center." }
        if issue == "no_person" { return "No person detected — stand in view of the camera." }
        return "Adjust the camera until the outline turns green."
    }
}

/// Resolve an exercise signal name; "abs:<metric>" takes the absolute value.
func signalValue(_ metrics: [String: Double], _ signal: String) -> Double? {
    if signal.hasPrefix("abs:") {
        guard let v = metrics[String(signal.dropFirst(4))] else { return nil }
        return abs(v)
    }
    return metrics[signal]
}
