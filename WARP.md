# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

VibeTime is a cross-platform vibration clock that encodes time into haptic patterns using a tally-based system:
- **LONG pulse (250ms)** = 5 units
- **SHORT pulse (100ms)** = 1 unit
- Numbers are encoded as `floor(N/5)` LONG + `N%5` SHORT pulses

## Architecture

Three independent platform implementations sharing the same encoding logic:

| Platform | Entry Point | Vibration Logic |
|----------|-------------|-----------------|
| **Web** | `web/index.html` | Single-file PWA using `navigator.vibrate()` |
| **iOS** | `ios/VibeTimeApp/VibeTimeApp.swift` | SwiftUI with `UIImpactFeedbackGenerator` |
| **Android** | `android/app/.../MainActivity.kt` | Kotlin/Compose with `VibrationEffect.createWaveform()` |

### Key Components

**iOS** (`ios/VibeTimeApp/`):
- `HapticManager.swift` - Singleton managing haptic sequences; uses `.heavy` for LONG, `.light` for SHORT
- `ContentView.swift` - Main SwiftUI view with settings and test buttons

**Android** (`android/app/src/main/java/com/example/vibetime/`):
- `TimeVibrationEncoder.kt` - Static encoder producing `(timings, amplitudes)` arrays
- `MainActivity.kt` - Compose UI; handles API 31+ (`VibratorManager`) and legacy fallback

**Web**:
- `index.html` - Complete PWA with embedded JS; `buildTimePattern()` creates vibration array

### Timing Constants (consistent across platforms)

| Constant | Value |
|----------|-------|
| LONG_PULSE | 250ms |
| SHORT_PULSE | 100ms |
| INTER_PULSE_PAUSE | 70ms |
| SEPARATOR_PAUSE | 400ms |

## Build & Run

### Web
```bash
# Open directly in browser (requires HTTPS or localhost for vibration API)
open web/index.html
# Or serve locally
python3 -m http.server 8000 --directory web
```

### iOS
```bash
# Open in Xcode
open ios/VibeTimeApp.xcodeproj
# Build: Cmd+B, Run: Cmd+R
# NOTE: Haptics only work on physical device, not simulator
```
- Requires iOS 17.0+

### Android
```bash
cd android
./gradlew assembleDebug
# Install APK from android/app/build/outputs/apk/debug/
```
- Requires API 26+ (Android 8.0)
- Uses Gradle 8.2.0, Kotlin 1.9.0

## Platform-Specific Notes

- **Web**: Vibration API works on Chrome/Firefox Android only (not Safari/iOS Safari)
- **iOS**: Must test on physical device; simulator cannot produce haptic feedback
- **Android**: Amplitude control requires API 26+; uses different amplitude values (255 for LONG, 128 for SHORT)
