package com.spinecare.app

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/** Shared skeleton + HUD drawing used by the live OverlayView AND the session
 *  recorder, so saved videos show exactly what the user saw during the session. */
object OverlayRenderer {

    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = 5f; style = Paint.Style.STROKE }
    private val neck = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = 8f; style = Paint.Style.STROKE }
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val textBg = Paint().apply { style = Paint.Style.FILL }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 26f }
    private val bigText = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#34D399"); textSize = 56f; isFakeBoldText = true }

    private val conns = listOf(
        intArrayOf(Metrics.L_SHO, Metrics.R_SHO),
        intArrayOf(Metrics.L_SHO, Metrics.L_HIP), intArrayOf(Metrics.R_SHO, Metrics.R_HIP),
        intArrayOf(Metrics.L_HIP, Metrics.R_HIP),
        intArrayOf(Metrics.L_SHO, Metrics.L_ELB), intArrayOf(Metrics.R_SHO, Metrics.R_ELB),
        intArrayOf(Metrics.L_ELB, Metrics.L_WR), intArrayOf(Metrics.R_ELB, Metrics.R_WR),
        intArrayOf(Metrics.L_HIP, Metrics.L_KNEE), intArrayOf(Metrics.R_HIP, Metrics.R_KNEE),
        intArrayOf(Metrics.L_KNEE, Metrics.L_ANK), intArrayOf(Metrics.R_KNEE, Metrics.R_ANK),
    )

    /** Draws skeleton + HUD onto [canvas]. Landmarks are normalized 0..1.
     *  [mirror] flips x for front-camera WYSIWYG display/recording. */
    fun draw(canvas: Canvas, lms: List<Metrics.LM>?, missing: List<String>, ready: Boolean,
             metricsLine: String, cue: String, repsText: String, mirror: Boolean) {
        val w = canvas.width.toFloat(); val h = canvas.height.toFloat()
        fun px(x: Float) = if (mirror) (1f - x) * w else x * w

        val color = if (ready) Color.parseColor("#34D399") else Color.parseColor("#FBBF24")
        lms?.let { l ->
            line.color = color
            for ((a, b) in conns) {
                if (a < l.size && b < l.size) {
                    val la = l[a]; val lb = l[b]
                    if (la.visibility > 0.5f && lb.visibility > 0.5f)
                        canvas.drawLine(px(la.x), la.y * h, px(lb.x), lb.y * h, line)
                }
            }
            if (l.size > Metrics.R_HIP) {
                val ear = l[Metrics.L_EAR]; val sho = l[Metrics.L_SHO]
                neck.color = if (ready) Color.parseColor("#38BDF8") else Color.parseColor("#F87171")
                canvas.drawLine(px(ear.x), ear.y * h, px(sho.x), sho.y * h, neck)
            }
            for ((i, lm) in l.withIndex()) {
                if (lm.visibility > 0.5f) {
                    val isMissing = missing.any { nameMatches(it, i) }
                    dot.color = if (isMissing) Color.parseColor("#F87171") else color
                    canvas.drawCircle(px(lm.x), lm.y * h, if (isMissing) 14f else 7f, dot)
                }
            }
        }
        // HUD: reps top-right
        if (repsText.isNotEmpty()) {
            canvas.drawText(repsText, w - bigText.measureText(repsText) - 24f, 84f, bigText)
        }
        // HUD: cue + metrics bottom-left
        val lines = ArrayList<String>()
        if (cue.isNotEmpty()) lines.add(cue)
        if (metricsLine.isNotEmpty()) lines.add(metricsLine)
        if (lines.isNotEmpty()) {
            val blockH = lines.size * 34f + 16f
            textBg.color = 0xCC0B1220.toInt()
            canvas.drawRect(0f, h - blockH, w, h, textBg)
            var y = h - blockH + 34f
            for (ln in lines) { canvas.drawText(ln, 16f, y, text); y += 34f }
        }
    }

    private fun nameMatches(name: String, idx: Int): Boolean = when (name) {
        "lear" -> idx == Metrics.L_EAR; "rear" -> idx == Metrics.R_EAR
        "lsho" -> idx == Metrics.L_SHO; "rsho" -> idx == Metrics.R_SHO
        "lhip" -> idx == Metrics.L_HIP; "rhip" -> idx == Metrics.R_HIP
        "lkne" -> idx == Metrics.L_KNEE; "rkne" -> idx == Metrics.R_KNEE
        else -> false
    }
}
