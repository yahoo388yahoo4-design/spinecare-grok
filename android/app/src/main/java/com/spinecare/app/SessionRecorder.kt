package com.spinecare.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.Surface
import java.io.File

/** Records the session as MP4: camera image first, then the skeleton on top.
 *  The muxer starts only after the encoder announces its format. Starting it
 *  earlier drops every frame, which is why review showed no camera picture. */
class SessionRecorder(file: File, width: Int, height: Int) {

    private val codec = MediaCodec.createEncoderByType(MIME)
    private val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var track = -1
    private var muxerStarted = false
    @Volatile private var stopDrain = false
    @Volatile var samplesWritten = 0
        private set
    private val drainThread = Thread { drain() }

    val surface: Surface

    init {
        val w = (width.coerceAtLeast(2) / 2) * 2
        val h = (height.coerceAtLeast(2) / 2) * 2
        val fmt = MediaFormat.createVideoFormat(MIME, w, h)
        fmt.setInteger(MediaFormat.KEY_BIT_RATE, 4_000_000)
        fmt.setInteger(MediaFormat.KEY_FRAME_RATE, 15)
        fmt.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        fmt.setInteger(MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = codec.createInputSurface()
        codec.start()
        drainThread.start()
    }

    /** Draws one composited frame (camera bitmap + overlay) onto the encoder surface. */
    fun drawFrame(camera: Bitmap, lms: List<Metrics.LM>?, missing: List<String>, ready: Boolean,
                  metricsLine: String, cue: String, repsText: String, mirror: Boolean) {
        if (stopDrain) return
        val image = software(camera)
        try {
            val c: Canvas = surface.lockCanvas(null) ?: return
            try {
                c.drawColor(Color.BLACK)
                c.drawBitmap(image, null, RectF(0f, 0f, c.width.toFloat(), c.height.toFloat()), null)
                OverlayRenderer.draw(c, lms, missing, ready, metricsLine, cue, repsText, mirror)
            } finally {
                surface.unlockCanvasAndPost(c)
            }
        } catch (_: Exception) {
        } finally {
            if (image !== camera) image.recycle()
        }
    }

    fun stop() {
        stopDrain = true
        try { codec.signalEndOfInputStream() } catch (_: Exception) {}
        drainThread.join(4000)
        runCatching { codec.stop() }
        runCatching { codec.release() }
        if (muxerStarted) runCatching { muxer.stop() }
        runCatching { muxer.release() }
    }

    private fun drain() {
        val bi = MediaCodec.BufferInfo()
        var idleAfterStop = 0
        while (true) {
            val idx = try { codec.dequeueOutputBuffer(bi, 10_000) } catch (_: Exception) { break }
            when {
                idx >= 0 -> {
                    val config = bi.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (muxerStarted && bi.size > 0 && !config) {
                        val buf = codec.getOutputBuffer(idx)
                        if (buf != null) {
                            buf.position(bi.offset)
                            buf.limit(bi.offset + bi.size)
                            try {
                                muxer.writeSampleData(track, buf, bi)
                                samplesWritten++
                            } catch (_: Exception) {}
                        }
                    }
                    codec.releaseOutputBuffer(idx, false)
                    if (bi.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    idleAfterStop = 0
                }
                idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> if (!muxerStarted) {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                idx == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (stopDrain) {
                        idleAfterStop++
                        if (idleAfterStop > 20) break
                    }
                }
            }
        }
    }

    private fun software(src: Bitmap): Bitmap {
        if (src.config != Bitmap.Config.HARDWARE) return src
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(src, 0f, 0f, null)
        return out
    }

    companion object { private const val MIME = "video/avc" }
}
