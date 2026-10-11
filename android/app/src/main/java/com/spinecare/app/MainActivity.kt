package com.spinecare.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.spinecare.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var b: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)
        if (savedInstanceState == null) show(HomeFragment())
        b.bottomNav.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.tab_home -> show(HomeFragment())
                R.id.tab_exercises -> show(ExercisesFragment())
                R.id.tab_sessions -> show(SessionsFragment())
                R.id.tab_sensors -> show(SensorsFragment())
                R.id.tab_sleep -> show(SleepFragment())
                R.id.tab_settings -> show(SettingsFragment())
            }
            true
        }
    }

    private fun show(f: androidx.fragment.app.Fragment) {
        supportFragmentManager.beginTransaction().replace(R.id.fragment, f).commit()
    }
}
