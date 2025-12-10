# VibeTime - Project Specification

## Overview

**VibeTime** is a cross-platform vibration clock that encodes time into haptic patterns. Users tap a button to "feel" the current time through a sequence of vibrations.

## Core Concept

Time is encoded using a **tally-based system**:

- **LONG vibration** = 5 units
- **SHORT vibration** = 1 unit

Any number N is encoded as:
- `floor(N / 5)` LONG pulses
- `N % 5` SHORT pulses

Hours and minutes are vibrated sequentially, separated by a pause.

### Example: 14:37

| Component | Value | Encoding |
|-----------|-------|----------|
| Hour | 14 | 2 LONG + 4 SHORT |
| *pause* | | 400ms silence |
| Minute | 37 | 7 LONG + 2 SHORT |

## Timing Constants

| Parameter | Value |
|-----------|-------|
| LONG pulse duration | 250ms |
| SHORT pulse duration | 100ms |
| Inter-pulse pause | 70ms |
| Hour/minute separator | 400ms |

## User Interface

### Main Screen
1. **Current time display** - Digital clock showing HH:MM:SS
2. **"Feel Current Time" button** - Triggers vibration of current time
3. **Settings**:
   - 12/24 hour format toggle
   - Include hours toggle
   - Include minutes toggle

### Optional: Test Examples
Preset buttons to test specific times (00:00, 08:05, 14:37, 23:59)

### Optional: Encoding Help
Brief explanation of how the tally system works

### Optional: Sound version
Allow a setting where you get audible beeps instead of (or in addition to) the vibrations.

## Platform Implementations

### iOS (Swift/SwiftUI)
- Use `UIImpactFeedbackGenerator` for haptics
  - `.heavy` style for LONG pulses
  - `.light` style for SHORT pulses
- Run vibration sequence on background thread with `Thread.sleep()` for timing
- Dispatch haptic calls back to main thread
- Minimum iOS 17.0

### Android (Kotlin)
- Use `VibrationEffect.createWaveform()` for modern devices (API 26+)
- Use `VibratorManager` for API 31+
- Build complete timing array: `[0, LONG, pause, LONG, pause, SHORT, ...]`
- Fallback to legacy `Vibrator.vibrate()` for older devices

### Web (HTML/CSS/JavaScript)
- Use `navigator.vibrate(pattern)` where pattern is array of durations
- Single HTML file with embedded CSS and JS
- PWA meta tags for "Add to Home Screen" support
- Works on mobile Chrome/Firefox (not Safari)

## File Structure

VibeTime/
├── README.md
├── WARP.md
├── ios/
│ └── VibeTimeApp/
│ ├── VibeTimeApp.swift # @main entry point
│ ├── ContentView.swift # Main UI
│ └── HapticManager.swift # Vibration encoding logic
├── android/
│ └── app/src/main/java/com/example/vibetime/
│ ├── MainActivity.kt
│ └── TimeVibrationEncoder.kt
└── web/
└── index.html # Single-file PWA


## Key Functions

### `vibrateTime(hour: Int, minute: Int, config: Config)`
Main entry point. Validates inputs, applies 12-hour conversion if needed, orchestrates vibration sequence.

### `vibrateNumber(n: Int)`
Encodes and vibrates a single number using the tally system.

### `buildPattern(n: Int) -> [Duration]`
Builds the vibration timing array for a number without executing it.

## Configuration Object

Config {
use12HourFormat: Bool = false
includeHours: Bool = true
includeMinutes: Bool = true
}


## Edge Cases

| Input | Behavior |
|-------|----------|
| Hour = 0 (midnight, 24h) | No hour vibration (0 = no pulses) |
| Hour = 0 (midnight, 12h) | Convert to 12 |
| Minute = 0 | No minute vibration |
| Both = 0 | No vibration at all |

## Non-Goals

- No timers or alarms
- No scheduled or automatic vibrations
- No watch or wearable support
- No audio feedback
- No notification integration

## Technical Notes

- Haptics require physical device (simulators don't vibrate)
- Web Vibration API is mobile-only and requires user gesture
- Keep UI minimal, since this is a single-purpose utility app
