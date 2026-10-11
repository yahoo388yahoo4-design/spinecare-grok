package com.spinecare.app

import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** Shared body-segment metrics, mirroring the server pose.py.
 *  Landmarks: MediaPipe 33-index space. All angles degrees. ESTIMATES only. */
object Metrics {
    // MediaPipe Pose landmark indices
    const val NOSE = 0
    const val L_EAR = 7
    const val R_EAR = 8
    const val L_SHO = 11
    const val R_SHO = 12
    const val L_ELB = 13
    const val R_ELB = 14
    const val L_WR = 15
    const val R_WR = 16
    const val L_HIP = 23
    const val R_HIP = 24
    const val L_KNEE = 25
    const val R_KNEE = 26
    const val L_ANK = 27
    const val R_ANK = 28

    data class LM(val x: Float, val y: Float, val z: Float, val visibility: Float)

    private fun mid(a: LM, b: LM) = LM((a.x + b.x) / 2f, (a.y + b.y) / 2f, (a.z + b.z) / 2f, min(a.visibility, b.visibility))

    private fun angBetween(x1: Float, y1: Float, x2: Float, y2: Float): Double {
        val n1 = hypot(x1.toDouble(), y1.toDouble()); val n2 = hypot(x2.toDouble(), y2.toDouble())
        if (n1 < 1e-6 || n2 < 1e-6) return Double.NaN
        return Math.toDegrees(acos(max(-1.0, min(1.0, (x1 * x2 + y1 * y2) / (n1 * n2)))))
    }

    private fun angFromVertical(ax: Float, ay: Float, bx: Float, by: Float) =
        angBetween(bx - ax, by - ay, 0f, 1f)

    fun compute(lms: List<LM>): Map<String, Double> {
        val out = HashMap<String, Double>()
        if (lms.size < 33) return out
        val lsho = lms[L_SHO]; val rsho = lms[R_SHO]; val lhip = lms[L_HIP]; val rhip = lms[R_HIP]
        val lear = lms[L_EAR]; val rear = lms[R_EAR]; val nose = lms[NOSE]
        val shoMid = mid(lsho, rsho); val hipMid = mid(lhip, rhip); val earMid = mid(lear, rear)
        val torsoLen = max(hypot((shoMid.x - hipMid.x).toDouble(), (shoMid.y - hipMid.y).toDouble()), 1e-3)
        val shoW = max(hypot((lsho.x - rsho.x).toDouble(), (lsho.y - rsho.y).toDouble()), 1e-3)

        if (lsho.visibility > .5f && rsho.visibility > .5f && lhip.visibility > .5f && rhip.visibility > .5f) {
            out["trunk_tilt_frontal"] = angFromVertical(shoMid.x, shoMid.y, hipMid.x, hipMid.y)
            out["head_forward_proxy"] = (earMid.x - shoMid.x) / torsoLen
        }
        if (lear.visibility > .5f && rear.visibility > .5f && lsho.visibility > .5f && rsho.visibility > .5f) {
            out["cervical_tilt"] = angFromVertical(earMid.x, earMid.y, shoMid.x, shoMid.y)
        }
        // Signed lateral nose offset vs shoulder midline (front view). Ear-separation
        // proxies collapse when an ear occludes during rotation; nose stays visible.
        if (nose.visibility > .5f && lsho.visibility > .5f && rsho.visibility > .5f) {
            val noseDx = (nose.x - shoMid.x).toDouble()
            val ratio = max(-1.0, min(1.0, noseDx / (0.28 * shoW)))
            out["neck_yaw_est"] = Math.toDegrees(asin(ratio))
        }
        if (lsho.visibility > .5f && rsho.visibility > .5f) {
            val deg = Math.toDegrees(atan2((rsho.y - lsho.y).toDouble(), (rsho.x - lsho.x).toDouble()))
            out["shoulder_line_tilt"] = ((deg + 90.0).rem(180.0) + 180.0).rem(180.0) - 90.0
        }
        if (nose.visibility > .5f && lear.visibility > .5f && lsho.visibility > .5f) {
            out["cervical_sag_proxy"] = angBetween(nose.x - earMid.x, nose.y - earMid.y, shoMid.x - earMid.x, shoMid.y - earMid.y)
        }
        return out
    }
}

/** Resolve an exercise signal name; "abs:<metric>" takes the absolute value. */
fun signalValue(metrics: Map<String, Double?>, signal: String): Double? {
    if (signal.startsWith("abs:")) {
        val v = metrics[signal.removePrefix("abs:")] ?: return null
        return kotlin.math.abs(v)
    }
    return metrics[signal]
}
