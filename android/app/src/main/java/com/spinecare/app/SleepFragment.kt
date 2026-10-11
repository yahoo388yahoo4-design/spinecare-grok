package com.spinecare.app

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.fragment.app.Fragment

class SleepFragment : Fragment() {
    override fun onCreateView(i: LayoutInflater, c: ViewGroup?, s: Bundle?): View {
        val ctx = requireContext()
        val root = ScrollView(ctx)
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32) }
        root.addView(col)
        fun h(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFF38BDF8.toInt()); textSize = 19f; setPadding(0, 20, 0, 6) }
        fun p(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFFE5E7EB.toInt()); textSize = 13f; setPadding(0, 2, 0, 2) }

        col.addView(h("Sleep setup (7-night experiment)"))
        p("1. Log your current pillow + mattress tonight (pillow type, height, position you wake in).")
        p("2. Rate morning neck pain and arm symptoms each day (Home tab check-in).")
        p("3. Trial ONE change at a time (e.g. adjustable-height pillow) for ≥3 nights before judging.")
        p("4. Side sleeping: pillow should fill the shoulder-to-head gap without tilting the head up.")
        p("5. Back sleeping: support the neck curve without pushing the chin toward the chest.")
        p("6. Avoid stomach sleeping — it holds the neck rotated for long periods.")

        col.addView(h("Position tracking options"))
        p("• Bed pressure mat (FSR array or commercial) under the mattress → back/side/stomach + turns.")
        p("• Upper-trunk IMU node worn in a shirt pocket → orientation + turning events.")
        p("• Smartwatch via Health Connect → sleep windows + movement (imported, not diagnostic).")
        p("The app reports position CLASS with uncertainty; it never claims to know your neck angle at 3am.")

        col.addView(h("Pillow/mattress guidance"))
        p("Start with an adjustable-height pillow before buying an expensive mattress.")
        p("Track whether a change correlates with better morning scores — the data decides, not marketing.")

        col.addView(h("Health Connect"))
        val hc = HealthConnectHelper(ctx)
        p(if (hc.isAvailable()) "Health Connect available — steps/sleep import enabled in later builds."
          else "Health Connect not available on this device; using phone + wearable data only.")
        return root
    }
}
