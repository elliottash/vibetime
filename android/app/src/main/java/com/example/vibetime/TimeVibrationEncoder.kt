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
 * Configuration for time vibration
 */
data class VibeConfig(
    val use12HourFormat: Boolean = false,
    val includeHours: Boolean = true,
    val includeMinutes: Boolean = true
)

/**
 * Encodes time into vibration patterns using a tally system
 * LONG (250ms) = 5 units
 * SHORT (100ms) = 1 unit
 */
object TimeVibrationEncoder {
    
    /**
     * Build vibration pattern for a given time
     * Returns Pair<timings, amplitudes> for VibrationEffect.createWaveform()
     * timings: [0, vibrate1, pause1, vibrate2, pause2, ...]
     * amplitudes: [0, 255, 0, 255, 0, ...] where 255=vibrate, 0=pause
     */
    fun buildTimePattern(hour: Int, minute: Int, config: VibeConfig): Pair<LongArray, IntArray> {
        var h = hour
        
        // Handle 12-hour format
        if (config.use12HourFormat) {
            h = when {
                h == 0 -> 12
                h > 12 -> h - 12
                else -> h
            }
        }
        
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        
        // Start with 0 delay
        timings.add(0)
        amplitudes.add(0)
        
        var addedContent = false
        
        // Add hour pattern
        if (config.includeHours && h > 0) {
            addNumberPattern(h, timings, amplitudes)
            addedContent = true
        }
        
        // Add minute pattern
        if (config.includeMinutes && minute > 0) {
            // Add separator if we had hours
            if (addedContent) {
                timings.add(VibeTiming.SEPARATOR_PAUSE)
                amplitudes.add(0)
            }
            addNumberPattern(minute, timings, amplitudes)
        }
        
        return Pair(timings.toLongArray(), amplitudes.toIntArray())
    }
    
    /**
     * Add vibration pattern for a single number to the lists
     */
    private fun addNumberPattern(n: Int, timings: MutableList<Long>, amplitudes: MutableList<Int>) {
        val longs = n / 5
        val shorts = n % 5
        
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
    fun buildLegacyPattern(hour: Int, minute: Int, config: VibeConfig): LongArray {
        var h = hour
        
        if (config.use12HourFormat) {
            h = when {
                h == 0 -> 12
                h > 12 -> h - 12
                else -> h
            }
        }
        
        val pattern = mutableListOf<Long>()
        
        // Add initial delay of 0
        pattern.add(0)
        
        var addedContent = false
        
        if (config.includeHours && h > 0) {
            addLegacyNumberPattern(h, pattern)
            addedContent = true
        }
        
        if (config.includeMinutes && minute > 0) {
            if (addedContent) {
                pattern.add(VibeTiming.SEPARATOR_PAUSE)
            }
            addLegacyNumberPattern(minute, pattern)
        }
        
        return pattern.toLongArray()
    }
    
    private fun addLegacyNumberPattern(n: Int, pattern: MutableList<Long>) {
        val longs = n / 5
        val shorts = n % 5
        
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
    fun describePattern(hour: Int, minute: Int, config: VibeConfig): String {
        var h = hour
        if (config.use12HourFormat) {
            h = when {
                h == 0 -> 12
                h > 12 -> h - 12
                else -> h
            }
        }
        
        val parts = mutableListOf<String>()
        
        if (config.includeHours) {
            parts.add(describeNumber(h, "Hour"))
        }
        
        if (config.includeMinutes) {
            parts.add(describeNumber(minute, "Min"))
        }
        
        return parts.joinToString(" | ")
    }
    
    private fun describeNumber(n: Int, label: String): String {
        if (n == 0) return "$label $n: (none)"
        
        val longs = n / 5
        val shorts = n % 5
        val components = mutableListOf<String>()
        
        if (longs > 0) components.add("${longs}L")
        if (shorts > 0) components.add("${shorts}S")
        
        return "$label $n: ${components.joinToString("+")}"
    }
    
    /**
     * Calculate total duration of pattern
     */
    fun calculateDuration(hour: Int, minute: Int, config: VibeConfig): Long {
        val (timings, _) = buildTimePattern(hour, minute, config)
        return timings.sum()
    }
}
