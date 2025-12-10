# VibeTime

A cross-platform vibration clock that encodes time into haptic patterns. Tap a button to "feel" the current time through a sequence of vibrations.

## How It Works

Time is encoded using a **tally-based system**:
- **LONG vibration (250ms)** = N units (configurable: 5 or 10)
- **SHORT vibration (100ms)** = 1 unit

Any number N is encoded as:
- `floor(N / tallyBase)` LONG pulses
- `N % tallyBase` SHORT pulses

### Example: 14:37 (with tally base = 5)

| Component | Value | Encoding |
|-----------|-------|----------|
| Hour | 14 | 2 LONG + 4 SHORT |
| *pause* | | 400ms silence |
| Minute | 37 | 7 LONG + 2 SHORT |

With tally base = 10: Hour 14 = 1 LONG + 4 SHORT, Minute 37 = 3 LONG + 7 SHORT

## Timing Constants

| Parameter | Duration |
|-----------|----------|
| LONG pulse | 250ms |
| SHORT pulse | 100ms |
| Inter-pulse pause | 70ms |
| Hour/minute separator | 400ms |

## User Interface

### Main Screen
1. **Current time display** - Digital clock showing HH:MM:SS (respects 12/24h setting)
2. **Countdown to next buzz** - Shows time remaining until next scheduled vibration
3. **"Feel Current Time" button** - Triggers vibration of current time
4. **Settings**:
   - 12/24 hour format toggle (affects display only)
   - Buzz interval (default: 5 minutes) - how often to vibrate
   - Start minute (default: 0) - first minute of each hour to buzz
   - Audible beeps - play tones alongside vibration (all platforms)
   - Tally base (5 or 10) - how many short pulses equal one long pulse

### Scheduled Buzzes
The app automatically vibrates/beeps at scheduled intervals:
- `nextBuzzMinute = startMinute + (n * interval)` where n makes it >= current minute
- Example: interval=5, start=0 → buzzes at :00, :05, :10, :15...
- Example: interval=15, start=3 → buzzes at :03, :18, :33, :48
- The countdown shows time until the next automatic buzz

### Test Examples
Preset buttons to test specific times (00:00, 08:05, 14:37, 23:59)

### Encoding Help
Brief explanation of how the tally system works

## Platforms

### Web (`web/index.html`)
- Single-file PWA with `navigator.vibrate(pattern)`
- Works on mobile Chrome/Firefox (not Safari)
- PWA meta tags for "Add to Home Screen" support
- **Audible beeps option**: plays tones (440Hz for LONG, 880Hz for SHORT) for testing on desktop or devices without vibration

### iOS (`ios/VibeTimeApp.xcodeproj`)
- SwiftUI app using `UIImpactFeedbackGenerator`
  - `.heavy` style for LONG pulses
  - `.light` style for SHORT pulses
- Runs vibration sequence on background thread
- **Audible beeps option** using system sounds
- Requires iOS 17.0+
- **Haptics require physical device** (simulator doesn't vibrate)

### Android (`android/`)
- Kotlin/Compose app using `VibrationEffect.createWaveform()`
- Uses `VibratorManager` for API 31+
- Fallback to legacy `Vibrator.vibrate()` for older devices
- **Audible beeps option** using `ToneGenerator`
- Requires API 26+ (Android 8.0)

## File Structure

```
VibeTime/
├── README.md
├── ios/
│   └── VibeTimeApp.xcodeproj/
│       └── VibeTimeApp/
│           ├── VibeTimeApp.swift      # @main entry point
│           ├── ContentView.swift      # Main UI
│           └── HapticManager.swift    # Vibration encoding logic
├── android/
│   └── app/src/main/java/com/example/vibetime/
│       ├── MainActivity.kt
│       └── TimeVibrationEncoder.kt
└── web/
    └── index.html                     # Single-file PWA
```

## Key Functions

### `vibrateTime(hour, minute, config)`
Main entry point. Validates inputs, applies 12-hour conversion if needed, orchestrates vibration sequence.

### `vibrateNumber(n)` / `buildNumberPattern(n)`
Encodes and vibrates a single number using the tally system.

## Configuration

```
Config {
  use12HourFormat: Bool = false    // Display format only
  buzzInterval: Int = 5            // Minutes between buzzes (1-60)
  startMinute: Int = 0             // First minute of hour to buzz (0-59)
  tallyBase: Int = 5               // 5 or 10 - units per LONG pulse
  audioEnabled: Bool = false       // Play audible beeps
}
```

## Edge Cases

| Input | Behavior |
|-------|----------|
| Hour = 0 (midnight, 24h) | No hour vibration (0 = no pulses) |
| Hour = 0 (midnight, 12h) | Convert to 12 |
| Minute = 0 | No minute vibration |
| Both = 0 | No vibration at all |

## Non-Goals

- No timers or alarms (beyond the scheduled time buzzes)
- No watch or wearable support
- No notification integration
