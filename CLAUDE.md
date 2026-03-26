# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SlapMyMac is a macOS menu bar app (Swift/SwiftUI) that detects physical slaps on Apple Silicon MacBooks using the built-in BMI286 accelerometer and plays sound effects. Also reads the lid angle sensor. Based on [taigrr/spank](https://github.com/taigrr/spank) and [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor).

## Build & Run

```bash
swift build                              # Build (debug)
./Scripts/build.sh                       # Build + create .app bundle
./Scripts/build.sh --release             # Release .app bundle
./Scripts/build.sh --release --sandbox   # Release with App Sandbox entitlements
open .build/SlapMyMac.app                # Run
swift test                               # Run tests (8 tests)
./Scripts/create-dmg.sh                  # Create DMG (requires release build)
```

## Architecture

```
IOKit HID (bg thread) → ImpactDetector → SlapTracker → SoundManager (AVAudioEngine)
LidAngleSensor (main thread, 30Hz polling)     ↓
                                         AppState (@MainActor) → MenuBarView / PreferencesView
                                              ↓
                                         L10n (dictionary-based EN/FR localization)
```

- **AccelerometerService** (`Sensor/`): IOKit HID access using `IOHIDManager` (primary) with `IOServiceMatching` fallback. Runs CFRunLoop on dedicated thread, exposes `AsyncStream<AccelerometerSample>`. Must wake `AppleSPUHIDDriver` before reading. Reports are 22 bytes with Int32 LE XYZ at offsets 6/10/14, divided by 65536 for g-force. Device matching: VendorID `0x05AC`, ProductID `0x8104`, UsagePage `0xFF00`, Usage `3`.

- **LidAngleSensor** (`Sensor/`): Reads the MacBook lid angle sensor via IOKit HID feature reports (synchronous polling at 30Hz). Device matching: UsagePage `0x0020`, Usage `0x008A`. Parses 9-bit angle from bytes 1-2 of feature report. Provides smoothed angle and velocity.

- **ImpactDetector** (`Detection/`): 4 parallel algorithms ported from spank's Go detector:
  - STA/LTA (3 timescales) — short/long-term energy ratio
  - CUSUM — cumulative deviation control chart
  - Kurtosis — impulsiveness measure over 100-sample window
  - Peak/MAD — median absolute deviation outlier detection

- **Theme** (`App/Theme.swift`): Adaptive dark/light theme — orange accent, purple secondary. Detects system appearance via `NSApp.effectiveAppearance`. Reusable `cardStyle()` modifier.

- **L10n** (`App/L10n.swift`): Dictionary-based localization (EN + FR). `L10n.tr("key")` for plain strings, `L10n.tr("key", args...)` for format strings. Language auto-detected from system, overridable via `UserDefaults("appLanguage")`. Strings in `L10nEN.swift` / `L10nFR.swift`.

- **AppState** (`App/`): Central coordinator. Owns sensor stream Task, feeds detector, triggers audio. Tracks lifetime slaps (persisted). Manages mute timer, profiles, achievements, SSE broadcasts. All UI state flows through `@Published` properties.

- **AppLogger** (`App/AppLogger.swift`): File-based persistent logger to `~/Library/Application Support/SlapMyMac/slapmymac.log`. Auto-trims at 1MB.

## UI Structure

- **MenuBarView**: Adaptive popover — slap counter hero (animated), lid angle card, impact sparkline, expandable voice pack picker with preview, sensitivity slider, mute timer, debug card
- **PreferencesView**: 8 tabs — General, Sounds, Sensors, Stats, Leaderboard, Profiles, Roadmap, About
- **OnboardingView**: 4-step first-launch tutorial with skip option (localized)

## Key Constraints

- **Apple Silicon only**: Uses `AppleSPUHIDDevice` which only exists on Apple Silicon laptops.
- **macOS 14+**: Requires `MenuBarExtra` and `SMAppService` APIs.
- **LSUIElement = true**: Menu bar only app, no dock icon.
- **CoreMotion unavailable on macOS**: `CMMotionManager` is iOS-only. The Apple Silicon accelerometer (BMI286) is only accessible via IOKit HID on macOS.

## Distribution

Two distribution modes, controlled by build flags:

| Mode | Sandbox | IOKit | How |
|------|---------|-------|-----|
| **Direct (default)** | Off | Full access | `build.sh --release` + DMG + Developer ID notarization |
| **App Store** | On | Via `IOHIDLibFactory` exception | `build.sh --release --sandbox` + Xcode archive |

**App Store sandbox strategy**: The entitlements file (`Resources/SlapMyMac.entitlements`) enables App Sandbox with a `com.apple.security.temporary-exception.iokit-user-client-class` for `IOHIDLibFactory`. This allows `IOHIDManager` to function within the sandbox. Apple approves this exception for legitimate hardware access use cases. The entitlements also include `network.server` (MCP on port 7749) and `files.user-selected.read-only` (custom sound folders).

## Sound Modes

| Mode | Files | Selection |
|------|-------|-----------|
| Pain | 10 MP3s | Random |
| Sexy | 60 MP3s (00-59) | Escalation (decay score, halfLife=30s) |
| Halo | 9 MP3s | Random |
| + 12 more packs | 8–13 clips each | Random or escalating |
| Lid | 3 MP3s (open/close/slam) | Event-based |
| Custom | User folder | Random |

## Localization

Dictionary-based system (`L10n.swift` + `L10nEN.swift` + `L10nFR.swift`). ~290 keys covering all views. To add a language: create `L10nXX.swift` with matching keys and register in `L10n.allStrings`.

## SPM Resource Handling

Sound files in `Sources/SlapMyMac/Resources/Sounds/{Pain,Sexy,Halo,...}/`, declared as `.copy("Resources/Sounds")` in Package.swift. Build script copies them into `.app/Contents/Resources/Sounds/`.
