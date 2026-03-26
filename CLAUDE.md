# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SlapMyMac is a macOS menu bar app (Swift/SwiftUI) that detects physical slaps on Apple Silicon MacBooks using the built-in BMI286 accelerometer and plays sound effects. Also reads the lid angle sensor. Based on [taigrr/spank](https://github.com/taigrr/spank) and [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor).

## Build & Run

```bash
swift build                    # Build (debug)
./Scripts/build.sh             # Build + create .app bundle
./Scripts/build.sh --release   # Release .app bundle
open .build/SlapMyMac.app      # Run
swift test                     # Run tests (8 tests)
./Scripts/create-dmg.sh        # Create DMG (requires release build)
```

## Architecture

```
IOKit HID (bg thread) → ImpactDetector → SlapTracker → SoundManager (AVAudioPlayer)
LidAngleSensor (main thread, 30Hz polling)     ↓
                                         AppState (@MainActor) → MenuBarView / PreferencesView
```

- **AccelerometerService** (`Sensor/`): IOKit HID access using `IOHIDManager` (primary) with `IOServiceMatching` fallback. Runs CFRunLoop on dedicated thread, exposes `AsyncStream<AccelerometerSample>`. Must wake `AppleSPUHIDDriver` before reading. Reports are 22 bytes with Int32 LE XYZ at offsets 6/10/14, divided by 65536 for g-force. Device matching: VendorID `0x05AC`, ProductID `0x8104`, UsagePage `0xFF00`, Usage `3`.

- **LidAngleSensor** (`Sensor/`): Reads the MacBook lid angle sensor via IOKit HID feature reports (synchronous polling at 30Hz). Device matching: UsagePage `0x0020`, Usage `0x008A`. Parses 9-bit angle from bytes 1-2 of feature report. Provides smoothed angle and velocity.

- **ImpactDetector** (`Detection/`): 4 parallel algorithms ported from spank's Go detector:
  - STA/LTA (3 timescales) — short/long-term energy ratio
  - CUSUM — cumulative deviation control chart
  - Kurtosis — impulsiveness measure over 100-sample window
  - Peak/MAD — median absolute deviation outlier detection

- **Theme** (`App/Theme.swift`): Dark theme design tokens — orange accent, purple secondary, dark surfaces. Reusable `cardStyle()` modifier.

- **AppState** (`App/`): Central coordinator. Owns sensor stream Task, feeds detector, triggers audio. Tracks lifetime slaps (persisted). All UI state flows through `@Published` properties.

## UI Structure

- **MenuBarView**: Rich dark popover — slap counter hero (animated), lid angle card, expandable voice pack picker with preview, sensitivity slider, debug card
- **PreferencesView**: 5 tabs — General, Sounds, Sensors, Roadmap, About
- **OnboardingView**: 4-step first-launch tutorial with skip option

## Key Constraints

- **No App Sandbox**: IOKit HID requires unsandboxed execution. Distribution via Developer ID + notarization.
- **Apple Silicon only**: Uses `AppleSPUHIDDevice` which only exists on Apple Silicon laptops.
- **macOS 14+**: Requires `MenuBarExtra` and `SMAppService` APIs.
- **LSUIElement = true**: Menu bar only app, no dock icon.

## Sound Modes

| Mode | Files | Selection |
|------|-------|-----------|
| Pain | 10 MP3s | Random |
| Sexy | 60 MP3s (00-59) | Escalation (decay score, halfLife=30s) |
| Halo | 9 MP3s | Random |
| Custom | User folder | Random |

## SPM Resource Handling

Sound files in `Sources/SlapMyMac/Resources/Sounds/{Pain,Sexy,Halo}/`, declared as `.copy("Resources/Sounds")` in Package.swift. Build script copies them into `.app/Contents/Resources/Sounds/`.
