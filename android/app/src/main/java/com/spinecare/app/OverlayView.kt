package com.spinecare.app

import android.content.Context
import android.graphics.Canvas
import android.util.AttributeSet
import android.view.View

/** Draws pose skeleton + framing status + cue highlights over the camera preview.
 *  Delegates all drawing to OverlayRenderer so recordings match the live view. */
class OverlayView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null)
    : View(context, attrs) {

    var landmarks: List<Metrics.LM>? = null
    var missing: List<String> = emptyList()
    var ready = false
    var metricsLine: String = ""
    var cue: String = ""
    var repsText: String = ""
    var mirror = false

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        OverlayRenderer.draw(canvas, landmarks, missing, ready, metricsLine, cue, repsText, mirror)
    }
}
