package com.spinecare.app

/** Hysteresis rep counter on a scalar signal — mirrors server RepEngine. */
class RepEngine(private val low: Double, private val high: Double, private val minHoldMs: Long = 400) {
    enum class Phase { REST, OUT, IN }
    var phase = Phase.REST; private set
    var reps = 0; private set
    private var tEnter = 0L

    /** returns true when a rep just completed */
    fun update(value: Double?, nowMs: Long): Boolean {
        if (value == null || value.isNaN()) return false
        var done = false
        when (phase) {
            Phase.REST -> if (value >= high) { phase = Phase.OUT; tEnter = nowMs }
            Phase.OUT -> if (value <= low) {
                if (nowMs - tEnter >= minHoldMs) { reps++; done = true }
                phase = Phase.IN; tEnter = nowMs
            }
            Phase.IN -> if (value >= high) { phase = Phase.OUT; tEnter = nowMs }
        }
        return done
    }
}
