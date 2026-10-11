package com.spinecare.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.Surface
import java.io.File

/** Records the session as MP4 with the sensor overlay burned in: each frame is
 *  the camera image + skeleton/metrics/cues drawn via OverlayRenderer, encoded
 *  through MediaCodec (surface input) and muxed with MediaMuxer. */
class SessionRecorder(file: File, width: Int, height: Int) {

    private val codec = MediaCodec.createEncoderByType(MIME)
    private val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var track = -1
    @Volatile private var stopDrain = false
    private val drainThread = Thread { drain() }

    val surface: Surface

    init {
        val fmt = MediaFormat.createVideoFormat(MIME, width, height)
        fmt.setInteger(MediaFormat.KEY_BIT_RATE, 4_000_000)
        fmt.setInteger(MediaFormat.KEY_FRAME_RATE, 15)
        fmt.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        fmt.setInteger(MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = codec.createInputSurface()
        muxer.start()
        codec.start()
        drainThread.start()
    }

    /** Draws one composited frame (camera bitmap + overlay) onto the encoder surface. */
    fun drawFrame(camera: Bitmap, lms: List<Metrics.LM>?, missing: List<String>, ready: Boolean,
                  metricsLine: String, cue: String, repsText: String, mirror: Boolean) {
        if (stopDrain) return
        try {
            val c: Canvas = surface.lockCanvas(null) ?: return
            try {
                c.drawBitmap(camera, null, RectF(0f, 0f, c.width.toFloat(), c.height.toFloat()), null)
                OverlayRenderer.draw(c, lms, missing, ready, metricsLine, cue, repsText, mirror)
            } finally {
                surface.unlockCanvasAndPost(c)
            }
        } catch (e: Exception) { /* surface gone */ }
    }

    fun stop() {
        try { codec.signalEndOfInputStream() } catch (_: Exception) {}
        stopDrain = true
        drainThread.join(3000)
        runCatching { codec.stop() }; codec.release()
        runCatching { muxer.stop() }; muxer.release()
    }

    private fun drain() {
        val bi = MediaCodec.BufferInfo()
        while (true) {
            val idx = try { codec.dequeueOutputBuffer(bi, 10_000) } catch (e: Exception) { break }
            when {
                idx >= 0 -> {
                    if (track >= 0 && bi.size > 0) {
                        val buf = codec.getOutputBuffer(idx)
                        if (buf != null) {
                            buf.position(bi.offset); buf.limit(bi.offset + bi.size)
                            try { muxer.writeSampleData(track, buf, bi) } catch (_: Exception) {}
                        }
                    }
                    codec.releaseOutputBuffer(idx, false)
                    if (bi.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
                idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED ->
                    if (track < 0) track = muxer.addTrack(codec.outputFormat)
                idx == MediaCodec.INFO_TRY_AGAIN_LATER -> if (stopDrain) break
            }
        }
    }

    companion object { private const val MIME = "video/avc" }
}
