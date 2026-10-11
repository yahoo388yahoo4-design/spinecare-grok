package com.spinecare.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
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
                    btn.setOnClickListener {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            ctx, "${requireContext().packageName}.fileprovider", f)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "video/mp4")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try { startActivity(intent) }
                        catch (e: Exception) {
                            // Fallback: share sheet so any player can open it
                            val share = Intent(Intent.ACTION_SEND).apply {
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            try { startActivity(Intent.createChooser(share, "Review session")) }
                            catch (_: Exception) { }
                        }
                    }
                    col.addView(btn)
                } else {
                    col.addView(p("  recording file missing"))
                }
            }
        }
        return root
    }
}
