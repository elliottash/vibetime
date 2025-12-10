# VibeTime

A cross-platform vibration clock that encodes time into haptic patterns. Tap a button to "feel" the current time through a sequence of vibrations.

## How It Works

Time is encoded using a **tally-based system**:
- **LONG vibration (250ms)** = 5 units
- **SHORT vibration (100ms)** = 1 unit

For example, **14:37** is encoded as:
- Hour 14: 2 LONG + 4 SHORT (5+5+1+1+1+1)
- *400ms pause*
- Minute 37: 7 LONG + 2 SHORT (5×7 + 1×2)

## Platforms

### Web
Open `web/index.html` in a mobile browser (Chrome/Firefox on Android). Works as a PWA.

### iOS
1. Open `ios/VibeTimeApp` in Xcode
2. Build and run on a physical device (simulator doesn't vibrate)
3. Requires iOS 17.0+

### Android
1. Open `android/` in Android Studio
2. Build and run on a physical device
3. Requires API 26+ (Android 8.0)

## Features
- Real-time digital clock display
- 12/24 hour format toggle
- Include/exclude hours or minutes
- Test preset times (00:00, 08:05, 14:37, 23:59)

## Timing
| Parameter | Duration |
|-----------|----------|
| LONG pulse | 250ms |
| SHORT pulse | 100ms |
| Inter-pulse pause | 70ms |
| Hour/minute separator | 400ms |
