package com.spinecare.app

import android.app.AlertDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import android.widget.VideoView
import androidx.fragment.app.Fragment
import java.io.File

/** Sessions tab: list saved sessions; open the recorded video (sensor overlay
 *  burned in) in the system player, plus per-session metrics summary. */
class SessionsFragment : Fragment() {
    override fun onCreateView(i: LayoutInflater, c: ViewGroup?, s: Bundle?): View {
        val ctx = requireContext()
        val store = LocalStore(ctx)
        val root = ScrollView(ctx)
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32) }
        root.addView(col)

        fun h(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFF38BDF8.toInt()); textSize = 20f; setPadding(0, 16, 0, 8) }
        fun p(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFFE5E7EB.toInt()); textSize = 13f; setPadding(0, 4, 0, 4) }

        col.addView(h("Saved sessions"))
        val all = store.allSessions().reversed()
        if (all.isEmpty()) {
            col.addView(p("No sessions yet — run an exercise from the Exercises tab. " +
                "With recording on, each session is saved with the skeleton, angles and cues burned into the video."))
            return root
        }
        for (srow in all) {
            val exId = srow.optString("exercise")
            val name = Plan.byId(exId)?.name ?: exId
            val line = "${srow.optString("date")}  ${name}  reps=${srow.optInt("reps")}  " +
                "frames=${srow.optInt("frames")}  [${srow.optString("source")}]"
            col.addView(p(line))
            val avg = srow.optJSONObject("avg")
            if (avg != null) {
                val keys = avg.keys().asSequence().toList()
                if (keys.isNotEmpty())
                    col.addView(p("  " + keys.joinToString("  ") { k -> "$k=${avg.optString(k, "-")}" }))
            }
            val video = srow.optString("video")
            if (video.isNotEmpty() && video != "null") {
                val f = File(video)
                if (f.exists()) {
                    val btn = Button(ctx).apply { text = "▶ Review recording (${srow.optInt("recorded_frames")} frames)" }
                    btn.setOnClickListener { play(f) }
                    col.addView(btn)
                } else {
                    col.addView(p("  recording file missing"))
                }
            }
        }
        return root
    }

    /** Plays the saved camera recording inside the app, with the burned-in skeleton. */
    private fun play(file: File) {
        val ctx = requireContext()
        val video = VideoView(ctx)
        val h = (resources.displayMetrics.heightPixels * 0.62f).toInt()
        val wrap = FrameLayout(ctx)
        wrap.addView(video, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, h))
        val controls = MediaController(ctx)
        controls.setAnchorView(video)
        video.setMediaController(controls)
        video.setVideoPath(file.absolutePath)
        video.setOnPreparedListener { it.isLooping = false; video.start() }
        video.setOnErrorListener { _, _, _ ->
            Toast.makeText(ctx, "Could not play this recording.", Toast.LENGTH_SHORT).show()
            true
        }
        AlertDialog.Builder(ctx)
            .setTitle("Session review")
            .setView(wrap)
            .setPositiveButton("Close") { _, _ -> video.stopPlayback() }
            .show()
    }
}
