package com.spinecare.app

import android.os.Bundle
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.google.android.material.button.MaterialButton
import com.spinecare.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var b: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)
        addTab("Home") { HomeFragment() }
        addTab("Exercises") { ExercisesFragment() }
        addTab("Sessions") { SessionsFragment() }
        addTab("Sensors") { SensorsFragment() }
        addTab("Sleep") { SleepFragment() }
        addTab("Settings") { SettingsFragment() }
        if (savedInstanceState == null) show(HomeFragment())
    }

    private fun addTab(label: String, make: () -> Fragment) {
        val button = MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = label
            isAllCaps = false
            minHeight = (48 * resources.displayMetrics.density).toInt()
            val pad = (12 * resources.displayMetrics.density).toInt()
            setPadding(pad, 0, pad, 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            setOnClickListener { show(make()) }
        }
        b.tabs.addView(button)
    }

    private fun show(f: Fragment) {
        supportFragmentManager.beginTransaction().replace(R.id.fragment, f).commit()
    }
}
