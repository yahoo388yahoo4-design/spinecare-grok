package com.spinecare.app

import android.graphics.Bitmap
import android.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

/** GPU-server streaming client. Sends JPEG frames + IMU over WebSocket;
 *  receives pose metrics, framing status, rep counts, and coaching cues.
 *  Falls back to on-device engine when the server is unreachable. */
class ServerClient(private val baseUrl: String, user: String = "", pass: String = "") {
    private val credentials: String? = if (user.isNotEmpty()) okhttp3.Credentials.basic(user, pass) else null
    private val http = OkHttpClient.Builder()
        .pingInterval(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()
    private var ws: WebSocket? = null
    var connected = false; private set

    interface Listener {
        fun onPose(msg: JSONObject)
        fun onSessionStarted(exercise: JSONObject)
        fun onSessionSaved(summary: JSONObject)
        fun onStatus(connected: Boolean)
    }
    private var listener: Listener? = null

    fun connect(listener: Listener) {
        this.listener = listener
        val req = Request.Builder().url(baseUrl.replace("http", "ws") + "/ws/session")
            .apply { credentials?.let { header("Authorization", it) } }.build()
        ws = http.newWebSocket(req, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) { connected = true; listener.onStatus(true) }
            override fun onMessage(webSocket: WebSocket, text: String) {
                val o = JSONObject(text)
                when (o.getString("type")) {
                    "pose" -> listener.onPose(o)
                    "session_started" -> listener.onSessionStarted(o.getJSONObject("exercise"))
                    "session_saved" -> listener.onSessionSaved(o)
                }
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { connected = false; listener.onStatus(false) }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { connected = false; listener.onStatus(false) }
        })
    }

    fun startSession(exerciseId: String) {
        ws?.send(JSONObject().put("type", "session").put("exercise_id", exerciseId).toString())
    }

    fun sendFrame(bitmap: Bitmap, tMs: Long, imu: JSONObject?, scale: Float = 0.5f) {
        if (!connected) return
        val w = (bitmap.width * scale).toInt(); val h = (bitmap.height * scale).toInt()
        val scaled = Bitmap.createScaledBitmap(bitmap, w, h, true)
        val baos = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 70, baos)
        val b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
        val msg = JSONObject().put("type", "frame").put("t", tMs).put("img", b64).put("w", w).put("h", h)
        if (imu != null) msg.put("imu", imu)
        ws?.send(msg.toString())
    }

    fun endSession() = ws?.send(JSONObject().put("type", "end_session").toString())
    fun close() { ws?.close(1000, "bye"); connected = false }
}
