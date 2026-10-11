import SwiftUI
import UIKit

/// Shared skeleton + HUD drawing for the live overlay AND the session recorder,
/// so saved videos show exactly what the user saw during the session.
/// Two entry points:
///  - `draw(cg:...)`  CoreGraphics (recorder path, via UIGraphicsImageRenderer,
///    y-down top-left origin) — thread-safe, runs on the camera queue.
///  - `draw(ctx:...)` SwiftUI Canvas (live preview path).
/// Landmarks are normalized 0..1 with y top-down (PoseTracker flips Vision's
/// bottom-up y so both paths agree).
enum OverlayRenderer {

    // Neck/shoulder/torso connections in the shared name space.
    private static let conns: [(String, String)] = [
        ("lsho", "rsho"), ("lsho", "lhip"), ("rsho", "rhip"), ("lhip", "rhip"),
        ("lsho", "lelb"), ("rsho", "relb"), ("lelb", "lwr"), ("relb", "rwr"),
        ("lhip", "lknee"), ("rhip", "rknee"), ("lknee", "lank"), ("rknee", "rank"),
    ]

    private static var green: CGColor { CGColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1) }
    private static var amber: CGColor { CGColor(red: 0.98, green: 0.75, blue: 0.15, alpha: 1) }
    private static var sky: CGColor { CGColor(red: 0.22, green: 0.74, blue: 0.98, alpha: 1) }

    // MARK: CoreGraphics path (recorder)

    static func draw(cg: CGContext, size: CGSize, lms: [String: Metrics.LM],
                     cue: String, metrics: String, reps: String, mirror: Bool) {
        func px(_ x: Double) -> CGFloat { CGFloat(mirror ? (1 - x) : x) * size.width }
        func py(_ y: Double) -> CGFloat { CGFloat(y) * size.height }

        let ready = !lms.isEmpty
        let lineColor = ready ? green : amber

        cg.setLineWidth(3)
        cg.setStrokeColor(lineColor)
        for (a, b) in conns {
            guard let la = lms[a], let lb = lms[b], la.conf > 0.5, lb.conf > 0.5 else { continue }
            cg.move(to: CGPoint(x: px(la.x), y: py(la.y)))
            cg.addLine(to: CGPoint(x: px(lb.x), y: py(lb.y)))
            cg.strokePath()
        }
        // Neck line (ear -> shoulder), highlighted
        if let lear = lms["lear"], let lsho = lms["lsho"], lear.conf > 0.5, lsho.conf > 0.5 {
            cg.setLineWidth(5)
            cg.setStrokeColor(sky)
            cg.move(to: CGPoint(x: px(lear.x), y: py(lear.y)))
            cg.addLine(to: CGPoint(x: px(lsho.x), y: py(lsho.y)))
            cg.strokePath()
        }
        cg.setFillColor(lineColor)
        for lm in lms.values where lm.conf > 0.5 {
            cg.fillEllipse(in: CGRect(x: px(lm.x) - 3.5, y: py(lm.y) - 3.5, width: 7, height: 7))
        }

        // HUD: reps top-right
        if !reps.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1),
            ]
            let s = NSAttributedString(string: reps, attributes: attrs)
            s.draw(at: CGPoint(x: size.width - s.size().width - 20, y: 20))
        }
        // HUD: cue + metrics bottom band
        if !cue.isEmpty || !metrics.isEmpty {
            let block = NSMutableAttributedString()
            if !cue.isEmpty {
                block.append(NSAttributedString(string: cue + "\n", attributes: [
                    .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: UIColor.systemYellow]))
            }
            if !metrics.isEmpty {
                block.append(NSAttributedString(string: metrics, attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.white]))
            }
            let bgH = block.size().height + 16
            cg.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
            cg.fill(CGRect(x: 0, y: size.height - bgH, width: size.width, height: bgH))
            block.draw(in: CGRect(x: 12, y: size.height - bgH + 8,
                                  width: size.width - 24, height: bgH))
        }
    }

    // MARK: SwiftUI Canvas path (live preview)

    static func draw(ctx: inout GraphicsContext, size: CGSize, lms: [String: Metrics.LM],
                     cue: String, metrics: String, reps: String, mirror: Bool) {
        func px(_ x: Double) -> CGFloat { CGFloat(mirror ? (1 - x) : x) * size.width }
        func py(_ y: Double) -> CGFloat { CGFloat(y) * size.height }

        let ready = !lms.isEmpty
        let lineColor = ready ? Color.green : Color.yellow

        for (a, b) in conns {
            guard let la = lms[a], let lb = lms[b], la.conf > 0.5, lb.conf > 0.5 else { continue }
            var path = Path()
            path.move(to: CGPoint(x: px(la.x), y: py(la.y)))
            path.addLine(to: CGPoint(x: px(lb.x), y: py(lb.y)))
            ctx.stroke(path, with: .color(lineColor), lineWidth: 3)
        }
        if let lear = lms["lear"], let lsho = lms["lsho"], lear.conf > 0.5, lsho.conf > 0.5 {
            var path = Path()
            path.move(to: CGPoint(x: px(lear.x), y: py(lear.y)))
            path.addLine(to: CGPoint(x: px(lsho.x), y: py(lsho.y)))
            ctx.stroke(path, with: .color(Color(red: 0.22, green: 0.74, blue: 0.98)), lineWidth: 5)
        }
        for lm in lms.values where lm.conf > 0.5 {
            let rect = CGRect(x: px(lm.x) - 3.5, y: py(lm.y) - 3.5, width: 7, height: 7)
            ctx.fill(Path(ellipseIn: rect), with: .color(lineColor))
        }

        if !reps.isEmpty {
            ctx.draw(Text(reps).font(.system(size: 40, weight: .bold)).foregroundColor(.green),
                     at: CGPoint(x: size.width - 70, y: 50))
        }
        if !cue.isEmpty || !metrics.isEmpty {
            var text = Text("")
            if !cue.isEmpty { text = text + Text(cue).foregroundColor(.yellow) + Text("\n") }
            if !metrics.isEmpty {
                text = text + Text(metrics).font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
            }
            ctx.draw(text, at: CGPoint(x: size.width / 2, y: size.height - 60), anchor: .center)
        }
    }
}
