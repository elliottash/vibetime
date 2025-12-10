package com.example.vibetime

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import kotlinx.coroutines.delay
import java.util.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            VibeTimeTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    VibeTimeScreen()
                }
            }
        }
    }
}

@Composable
fun VibeTimeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFFE94560),
            secondary = Color(0xFF0F3460),
            background = Color(0xFF1A1A2E),
            surface = Color(0xFF16213E)
        ),
        content = content
    )
}

@Composable
fun VibeTimeScreen() {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    
    // State
    var currentTime by remember { mutableStateOf(Date()) }
    var isVibrating by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf("") }
    var patternDescription by remember { mutableStateOf("Tap a time to see pattern") }
    
    // Settings
    var use12HourFormat by remember { mutableStateOf(false) }
    var buzzInterval by remember { mutableStateOf(5) }
    var startMinute by remember { mutableStateOf(0) }
    var audioEnabled by remember { mutableStateOf(false) }
    var tallyBase by remember { mutableStateOf(5) }
    
    // Update clock every second and check for scheduled buzz
    LaunchedEffect(Unit) {
        while (true) {
            currentTime = Date()
            
            // Check for scheduled buzz
            val cal = Calendar.getInstance().apply { time = currentTime }
            if (!isVibrating && shouldBuzzNow(cal)) {
                vibrateTime(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
            }
            
            delay(1000)
        }
    }
    
    // Helper functions for time display
    fun formatTime(cal: Calendar): String {
        var hour = cal.get(Calendar.HOUR_OF_DAY)
        val minute = cal.get(Calendar.MINUTE)
        val second = cal.get(Calendar.SECOND)
        var suffix = ""
        
        if (use12HourFormat) {
            suffix = if (hour >= 12) " PM" else " AM"
            hour = when {
                hour == 0 -> 12
                hour > 12 -> hour - 12
                else -> hour
            }
        }
        
        return String.format("%02d:%02d:%02d%s", hour, minute, second, suffix)
    }
    
    fun getNextBuzzMinute(currentMinute: Int): Int {
        for (m in currentMinute until 60) {
            if ((m - startMinute) % buzzInterval == 0 && m >= startMinute) {
                return m
            }
        }
        return startMinute + 60 // Next hour
    }
    
    fun shouldBuzzNow(cal: Calendar): Boolean {
        val currentMinute = cal.get(Calendar.MINUTE)
        val currentSecond = cal.get(Calendar.SECOND)
        
        // Only buzz at second 0
        if (currentSecond != 0) return false
        
        // Check if current minute matches the pattern
        if (currentMinute < startMinute) return false
        return (currentMinute - startMinute) % buzzInterval == 0
    }
    
    fun getCountdownString(cal: Calendar): String {
        val currentMinute = cal.get(Calendar.MINUTE)
        val currentSecond = cal.get(Calendar.SECOND)
        
        var nextBuzzMinute = getNextBuzzMinute(currentMinute)
        
        // If exactly on buzz minute, show next one (unless at second 0)
        if (nextBuzzMinute == currentMinute && currentSecond > 0) {
            nextBuzzMinute = getNextBuzzMinute(currentMinute + 1)
        }
        
        val minutesLeft: Int
        val secondsLeft: Int
        
        if (nextBuzzMinute >= 60) {
            minutesLeft = (60 - currentMinute - 1) + (nextBuzzMinute - 60)
            secondsLeft = if (currentSecond == 0) 0 else 60 - currentSecond
        } else {
            minutesLeft = nextBuzzMinute - currentMinute - 1
            secondsLeft = if (currentSecond == 0) 0 else 60 - currentSecond
        }
        
        val adjustedMinutes = if (secondsLeft == 0 && currentSecond == 0) minutesLeft + 1 else minutesLeft
        val adjustedSeconds = if (currentSecond == 0) 0 else secondsLeft
        
        return String.format("%02d:%02d", adjustedMinutes, adjustedSeconds)
    }
    
    // Vibration function
    fun vibrateTime(hour: Int, minute: Int) {
        if (isVibrating) return
        
        if (hour == 0 && minute == 0) {
            statusMessage = "No vibration (00:00)"
            return
        }
        
        isVibrating = true
        statusMessage = if (audioEnabled) "Playing..." else "Vibrating..."
        
        // Get vibrator service
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        // Build and execute pattern
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val (timings, amplitudes) = TimeVibrationEncoder.buildTimePattern(hour, minute, tallyBase)
            if (timings.size > 1) {
                val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                vibrator.vibrate(effect)
            }
        } else {
            @Suppress("DEPRECATION")
            val pattern = TimeVibrationEncoder.buildLegacyPattern(hour, minute, tallyBase)
            if (pattern.size > 1) {
                vibrator.vibrate(pattern, -1)
            }
        }
        
        // Play audio if enabled
        if (audioEnabled) {
            playAudioPattern(hour, minute, tallyBase)
        }
        
        // Reset state after vibration completes
        val duration = TimeVibrationEncoder.calculateDuration(hour, minute, tallyBase)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            isVibrating = false
            statusMessage = ""
        }, duration)
    }
    
    // Play audio beeps for the time pattern
    fun playAudioPattern(hour: Int, minute: Int, base: Int) {
        Thread {
            try {
                val toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
                
                fun playBeeps(n: Int) {
                    val longs = n / base
                    val shorts = n % base
                    
                    repeat(longs) { i ->
                        if (i > 0) Thread.sleep(VibeTiming.INTER_PULSE_PAUSE)
                        toneGen.startTone(ToneGenerator.TONE_DTMF_A, VibeTiming.LONG_PULSE.toInt())
                        Thread.sleep(VibeTiming.LONG_PULSE)
                    }
                    
                    repeat(shorts) { i ->
                        if (i > 0 || longs > 0) Thread.sleep(VibeTiming.INTER_PULSE_PAUSE)
                        toneGen.startTone(ToneGenerator.TONE_DTMF_D, VibeTiming.SHORT_PULSE.toInt())
                        Thread.sleep(VibeTiming.SHORT_PULSE)
                    }
                }
                
                if (hour > 0) playBeeps(hour)
                if (hour > 0 && minute > 0) Thread.sleep(VibeTiming.SEPARATOR_PAUSE)
                if (minute > 0) playBeeps(minute)
                
                toneGen.release()
            } catch (e: Exception) {
                // Ignore audio errors
            }
        }.start()
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Title
        Text(
            text = "⏱ VibeTime",
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFFE94560)
        )
        
        Spacer(modifier = Modifier.height(20.dp))
        
        // Clock display
        val cal = Calendar.getInstance().apply { time = currentTime }
        Text(
            text = formatTime(cal),
            fontSize = 42.sp,
            fontWeight = FontWeight.Light,
            fontFamily = FontFamily.Monospace,
            color = Color.White
        )
        
        Spacer(modifier = Modifier.height(10.dp))
        
        // Countdown to next buzz
        Text(
            text = "Next buzz in ${getCountdownString(cal)}",
            fontSize = 18.sp,
            color = Color(0xFFE94560)
        )
        
        Spacer(modifier = Modifier.height(15.dp))
        
        // Main button
        Button(
            onClick = {
                val cal = Calendar.getInstance()
                cal.time = currentTime
                vibrateTime(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
            },
            enabled = !isVibrating,
            modifier = Modifier
                .height(60.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFFE94560)
            )
        ) {
            Text(
                text = "Feel Current Time",
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        
        Spacer(modifier = Modifier.height(10.dp))
        
        // Status
        Text(
            text = statusMessage,
            color = Color(0xFFE94560),
            fontSize = 14.sp,
            modifier = Modifier.height(20.dp)
        )
        
        Spacer(modifier = Modifier.height(20.dp))
        
        // Settings section
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF16213E))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "SETTINGS",
                    fontSize = 12.sp,
                    color = Color.Gray
                )
                
                Spacer(modifier = Modifier.height(10.dp))
                
                SettingRow("12-hour format", use12HourFormat) { use12HourFormat = it }
                Divider(color = Color(0xFF2A2A4E))
                NumberSettingRow("Buzz interval (min)", buzzInterval, 1..60) { buzzInterval = it }
                Divider(color = Color(0xFF2A2A4E))
                NumberSettingRow("Start minute", startMinute, 0..59) { startMinute = it }
                Divider(color = Color(0xFF2A2A4E))
                SettingRow("Audible beeps", audioEnabled) { audioEnabled = it }
                Divider(color = Color(0xFF2A2A4E))
                TallyBaseRow("Tally base", tallyBase) { tallyBase = it }
            }
        }
        
        Spacer(modifier = Modifier.height(20.dp))
        
        // Test times section
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF16213E))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "TEST TIMES",
                    fontSize = 12.sp,
                    color = Color.Gray
                )
                
                Spacer(modifier = Modifier.height(10.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    listOf(
                        Pair(0, 0),
                        Pair(8, 5),
                        Pair(14, 37),
                        Pair(23, 59)
                    ).forEach { (hour, minute) ->
                        TestTimeButton(hour, minute) {
                            patternDescription = TimeVibrationEncoder.describePattern(hour, minute, tallyBase)
                            vibrateTime(hour, minute)
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(10.dp))
                
                Text(
                    text = patternDescription,
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Color.Gray,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF0D1321), RoundedCornerShape(8.dp))
                        .padding(10.dp)
                )
            }
        }
        
        Spacer(modifier = Modifier.height(20.dp))
        
        // Help section
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF16213E).copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "How it works",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text("Time is encoded as vibrations:", color = Color.Gray, fontSize = 14.sp)
                Text("LONG (250ms) = $tallyBase units", color = Color.White, fontSize = 14.sp)
                Text("SHORT (100ms) = 1 unit", color = Color.White, fontSize = 14.sp)
                Text("Example: 14 = ${14 / tallyBase} LONG + ${14 % tallyBase} SHORT", color = Color.Gray, fontSize = 14.sp)
            }
        }
    }
}

@Composable
fun SettingRow(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = title, color = Color.White)
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Color(0xFFE94560)
            )
        )
    }
}

@Composable
fun NumberSettingRow(title: String, value: Int, range: IntRange, onValueChange: (Int) -> Unit) {
    var textValue by remember(value) { mutableStateOf(value.toString()) }
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = title, color = Color.White)
        OutlinedTextField(
            value = textValue,
            onValueChange = { newValue ->
                textValue = newValue
                newValue.toIntOrNull()?.let { num ->
                    val clamped = num.coerceIn(range)
                    onValueChange(clamped)
                }
            },
            modifier = Modifier.width(70.dp),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFFE94560),
                unfocusedBorderColor = Color(0xFF2A2A4E),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White
            )
        )
    }
}

@Composable
fun TallyBaseRow(title: String, value: Int, onValueChange: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = title, color = Color.White)
        Row {
            listOf(5, 10).forEach { base ->
                Button(
                    onClick = { onValueChange(base) },
                    modifier = Modifier.padding(start = 4.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (value == base) Color(0xFFE94560) else Color(0xFF2A2A4E)
                    ),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    Text(text = base.toString(), fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
fun TestTimeButton(hour: Int, minute: Int, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF2A2A4E)
        ),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Text(
            text = String.format("%02d:%02d", hour, minute),
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp
        )
    }
}
