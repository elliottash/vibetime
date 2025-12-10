package com.example.vibetime

/**
 * Timing constants in milliseconds
 */
object VibeTiming {
    const val LONG_PULSE: Long = 250
    const val SHORT_PULSE: Long = 100
    const val INTER_PULSE_PAUSE: Long = 70
    const val SEPARATOR_PAUSE: Long = 400
}

/**
 * Audio frequencies for beeps (Hz)
 */
object BeepFrequency {
    const val LONG_TONE: Int = 440   // A4
    const val SHORT_TONE: Int = 880  // A5
}

/**
 * Configuration for time vibration
 */
data class VibeConfig(
    val use12HourFormat: Boolean = false,
    val buzzInterval: Int = 5,      // Minutes between buzzes
    val startMinute: Int = 0,       // First minute of hour to buzz
    val tallyBase: Int = 5,         // 5 or 10
    val audioEnabled: Boolean = false // Play beeps
)

/**
 * Encodes time into vibration patterns using a tally system
 * LONG (250ms) = tallyBase units (default 5)
 * SHORT (100ms) = 1 unit
 */
object TimeVibrationEncoder {
    
    /**
     * Build vibration pattern for a given time
     * Returns Pair<timings, amplitudes> for VibrationEffect.createWaveform()
     * timings: [0, vibrate1, pause1, vibrate2, pause2, ...]
     * amplitudes: [0, 255, 0, 255, 0, ...] where 255=vibrate, 0=pause
     */
    fun buildTimePattern(hour: Int, minute: Int, tallyBase: Int = 5): Pair<LongArray, IntArray> {
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        
        // Start with 0 delay
        timings.add(0)
        amplitudes.add(0)
        
        // Add hour pattern
        if (hour > 0) {
            addNumberPattern(hour, timings, amplitudes, tallyBase)
        }
        
        // Add minute pattern
        if (minute > 0) {
            // Add separator if we had hours
            if (hour > 0) {
                timings.add(VibeTiming.SEPARATOR_PAUSE)
                amplitudes.add(0)
            }
            addNumberPattern(minute, timings, amplitudes, tallyBase)
        }
        
        return Pair(timings.toLongArray(), amplitudes.toIntArray())
    }
    
    /**
     * Add vibration pattern for a single number to the lists
     */
    private fun addNumberPattern(n: Int, timings: MutableList<Long>, amplitudes: MutableList<Int>, tallyBase: Int) {
        val longs = n / tallyBase
        val shorts = n % tallyBase
        
        var first = true
        
        // Add LONG pulses
        repeat(longs) {
            if (!first) {
                timings.add(VibeTiming.INTER_PULSE_PAUSE)
                amplitudes.add(0)
            }
            timings.add(VibeTiming.LONG_PULSE)
            amplitudes.add(255) // Full amplitude for long
            first = false
        }
        
        // Add SHORT pulses
        repeat(shorts) {
            if (!first) {
                timings.add(VibeTiming.INTER_PULSE_PAUSE)
                amplitudes.add(0)
            }
            timings.add(VibeTiming.SHORT_PULSE)
            amplitudes.add(128) // Medium amplitude for short
            first = false
        }
    }
    
    /**
     * Build simple timing pattern for legacy vibration API
     * Returns array: [vibrate, pause, vibrate, pause, ...]
     */
    fun buildLegacyPattern(hour: Int, minute: Int, tallyBase: Int = 5): LongArray {
        val pattern = mutableListOf<Long>()
        
        // Add initial delay of 0
        pattern.add(0)
        
        if (hour > 0) {
            addLegacyNumberPattern(hour, pattern, tallyBase)
        }
        
        if (minute > 0) {
            if (hour > 0) {
                pattern.add(VibeTiming.SEPARATOR_PAUSE)
            }
            addLegacyNumberPattern(minute, pattern, tallyBase)
        }
        
        return pattern.toLongArray()
    }
    
    private fun addLegacyNumberPattern(n: Int, pattern: MutableList<Long>, tallyBase: Int) {
        val longs = n / tallyBase
        val shorts = n % tallyBase
        
        repeat(longs) { i ->
            if (i > 0 || pattern.size > 1) {
                pattern.add(VibeTiming.INTER_PULSE_PAUSE)
            }
            pattern.add(VibeTiming.LONG_PULSE)
        }
        
        repeat(shorts) { i ->
            if (i > 0 || pattern.size > 1) {
                pattern.add(VibeTiming.INTER_PULSE_PAUSE)
            }
            pattern.add(VibeTiming.SHORT_PULSE)
        }
    }
    
    /**
     * Describe the pattern for a given time (for UI display)
     */
    fun describePattern(hour: Int, minute: Int, tallyBase: Int = 5): String {
        val hourDesc = describeNumber(hour, "Hour", tallyBase)
        val minDesc = describeNumber(minute, "Min", tallyBase)
        return "$hourDesc | $minDesc"
    }
    
    private fun describeNumber(n: Int, label: String, tallyBase: Int): String {
        if (n == 0) return "$label $n: (none)"
        
        val longs = n / tallyBase
        val shorts = n % tallyBase
        val components = mutableListOf<String>()
        
        if (longs > 0) components.add("${longs}L")
        if (shorts > 0) components.add("${shorts}S")
        
        return "$label $n: ${components.joinToString("+")}"
    }
    
    /**
     * Calculate total duration of pattern
     */
    fun calculateDuration(hour: Int, minute: Int, tallyBase: Int = 5): Long {
        val (timings, _) = buildTimePattern(hour, minute, tallyBase)
        return timings.sum()
    }
}
