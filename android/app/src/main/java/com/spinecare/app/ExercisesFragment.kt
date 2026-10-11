package com.spinecare.app

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.fragment.app.Fragment

class ExercisesFragment : Fragment() {
    override fun onCreateView(i: LayoutInflater, c: ViewGroup?, s: Bundle?): View {
        val ctx = requireContext()
        val root = ScrollView(ctx)
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32) }
        root.addView(col)

        val warn = TextView(ctx).apply {
            text = "⚠ These exercises must be approved by your physiotherapist/spine specialist before use. The app guides an approved plan; it does not prescribe one."
            setTextColor(0xFFF87171.toInt()); textSize = 13f; setPadding(0, 0, 0, 16)
        }
        col.addView(warn)

        for (ex in Plan.exercises) {
            val card = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(0xFF121A2B.toInt()); setPadding(24, 24, 24, 24)
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = 24 }
            }
            card.addView(TextView(ctx).apply { text = ex.name; setTextColor(0xFFE5E7EB.toInt()); textSize = 17f })
            card.addView(TextView(ctx).apply {
                text = "${ex.view.uppercase()} view • ${ex.targetReps} reps • signal: ${ex.signal}"
                setTextColor(0xFF94A3B8.toInt()); textSize = 12f
            })
            card.addView(TextView(ctx).apply { text = ex.description; setTextColor(0xFF94A3B8.toInt()); textSize = 13f; setPadding(0, 8, 0, 8) })
            card.addView(TextView(ctx).apply {
                text = "Stop immediately if: ${ex.stopConditions.joinToString()}"
                setTextColor(0xFFFBBF24.toInt()); textSize = 12f
            })
            card.addView(Button(ctx).apply {
                text = "Start guided session"
                setOnClickListener {
                    startActivity(Intent(ctx, ExerciseActivity::class.java).putExtra("exercise_id", ex.id))
                }
            })
            col.addView(card)
        }
        return root
    }
}
