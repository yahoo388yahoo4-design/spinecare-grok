package com.spinecare.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Simple append-only JSONL store for sessions + daily check-ins.
 *  Production: Room + encryption; this keeps the prototype honest and exportable. */
class LocalStore(context: Context) {
    private val dir = File(context.filesDir, "data").apply { mkdirs() }
    private val sessions = File(dir, "sessions.jsonl")
    private val checkins = File(dir, "checkins.jsonl")
    private val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun saveSession(exId: String, reps: Int, avg: Map<String, Double>, cues: Map<String, Int>, frames: Int, source: String,
                    videoPath: String? = null, recordedFrames: Int = 0) {
        val o = JSONObject()
            .put("ts", System.currentTimeMillis())
            .put("date", fmt.format(Date()))
            .put("exercise", exId).put("reps", reps)
            .put("avg", JSONObject(avg as Map<*, *>))
            .put("cues", JSONObject(cues as Map<*, *>))
            .put("frames", frames).put("source", source)
        if (videoPath != null) o.put("video", videoPath).put("recorded_frames", recordedFrames)
        sessions.appendText(o.toString() + "\n")
    }

    fun saveCheckin(date: String, neckPain: Int, armSymptoms: Int, sleepQuality: Int, notes: String) {
        val o = JSONObject().put("date", date).put("neck_pain", neckPain)
            .put("arm_symptoms", armSymptoms).put("sleep_quality", sleepQuality).put("notes", notes)
        checkins.appendText(o.toString() + "\n")
    }

    fun sessionsFor(exId: String): List<JSONObject> =
        if (!sessions.exists()) emptyList() else
        sessions.readLines().mapNotNull { runCatching { JSONObject(it) }.getOrNull() }
            .filter { it.optString("exercise") == exId }

    fun allSessions(): List<JSONObject> =
        if (!sessions.exists()) emptyList() else
        sessions.readLines().mapNotNull { runCatching { JSONObject(it) }.getOrNull() }

    fun latestCheckin(): JSONObject? =
        if (!checkins.exists()) null else checkins.readLines().lastOrNull()?.let { runCatching { JSONObject(it) }.getOrNull() }

    /** CSV export of all sessions to Downloads/SpineCare/ for clinician sharing. */
    fun exportCsv(): Int {
        val all = allSessions()
        val name = "spinecare_sessions_${fmt.format(Date())}.csv"
        val dir = java.io.File(android.os.Environment.getExternalStoragePublicDirectory(
            android.os.Environment.DIRECTORY_DOWNLOADS), "SpineCare").apply { mkdirs() }
        val f = java.io.File(dir, name)
        val sb = StringBuilder("ts,date,exercise,reps,frames,source,avg,cues\n")
        for (o in all) {
            sb.append(o.optLong("ts")).append(',')
              .append(o.optString("date")).append(',')
              .append(o.optString("exercise")).append(',')
              .append(o.optInt("reps")).append(',')
              .append(o.optInt("frames")).append(',')
              .append(o.optString("source")).append(',')
              .append('"').append(o.optJSONObject("avg")?.toString()?.replace("\"", "\"\"")).append("\",")
              .append('"').append(o.optJSONObject("cues")?.toString()?.replace("\"", "\"\"")).append("\"\n")
        }
        f.writeText(sb.toString())
        return all.size
    }
}
