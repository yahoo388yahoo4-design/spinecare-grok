package com.spinecare.app

import android.content.Context

/** Coaching-server endpoint + auth + runtime options. All persisted locally.
 *  The app is offline-first: mode AUTO tries the server and falls back to
 *  on-device MediaPipe; ON_DEVICE never touches the network. */
object ServerConfig {
    private const val PREFS = "spinecare"
    private const val DEFAULT_URL = "http://192.168.1.188:8300"

    const val MODE_AUTO = 0        // try GPU server, fall back to on-device
    const val MODE_ON_DEVICE = 1   // never use network for coaching
    const val MODE_SERVER = 2      // GPU server required for coaching

    private fun p(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun url(c: Context) = p(c).getString("server_url", DEFAULT_URL)!!
    fun setUrl(c: Context, v: String) = p(c).edit().putString("server_url", v).apply()

    fun user(c: Context) = p(c).getString("server_user", "")!!
    fun setUser(c: Context, v: String) = p(c).edit().putString("server_user", v).apply()

    fun pass(c: Context) = p(c).getString("server_pass", "")!!
    fun setPass(c: Context, v: String) = p(c).edit().putString("server_pass", v).apply()

    fun mode(c: Context) = p(c).getInt("mode", MODE_AUTO)
    fun setMode(c: Context, v: Int) = p(c).edit().putInt("mode", v).apply()

    /** analysis frame interval in ms (lower = smoother, more battery) */
    fun frameIntervalMs(c: Context) = p(c).getInt("frame_ms", 150)
    fun setFrameIntervalMs(c: Context, v: Int) = p(c).edit().putInt("frame_ms", v).apply()

    /** server frame interval (network budget) */
    fun serverFrameIntervalMs(c: Context) = p(c).getInt("server_frame_ms", 100)
    fun setServerFrameIntervalMs(c: Context, v: Int) = p(c).edit().putInt("server_frame_ms", v).apply()

    fun minConfidence(c: Context) = p(c).getFloat("min_conf", 0.5f)
    fun setMinConfidence(c: Context, v: Float) = p(c).edit().putFloat("min_conf", v).apply()

    fun haptics(c: Context) = p(c).getBoolean("haptics", true)
    fun setHaptics(c: Context, v: Boolean) = p(c).edit().putBoolean("haptics", v).apply()

    fun audioCues(c: Context) = p(c).getBoolean("audio_cues", false)
    fun setAudioCues(c: Context, v: Boolean) = p(c).edit().putBoolean("audio_cues", v).apply()

    /** Record sessions with the sensor overlay burned in (local MP4). */
    fun recordSessions(c: Context) = p(c).getBoolean("record_sessions", true)
    fun setRecordSessions(c: Context, v: Boolean) = p(c).edit().putBoolean("record_sessions", v).apply()
}
