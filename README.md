# SlapMyMac

**Your MacBook fights back.** A macOS menu bar app that detects physical slaps on Apple Silicon MacBooks using the built-in accelerometer and plays sound effects.

Slap it. It screams.

## Install

**[Download SlapMyMac.dmg](https://github.com/neopheus/slapmymac/releases/latest/download/SlapMyMac.dmg)** (macOS 14+, Apple Silicon)

Open the DMG, drag SlapMyMac to Applications, done. The app is signed and notarized by Apple — no security warnings.

### Build from Source

```bash
git clone https://github.com/neopheus/slapmymac.git
cd slapmymac
./Scripts/build.sh --release
open .build/SlapMyMac.app
```

## Features

### Core
- **4 parallel detection algorithms** — STA/LTA, CUSUM, Kurtosis, Peak/MAD
- **15 sound packs** (181 clips) — Pain, Sexy, Halo, Whip, Cartoon, Kung Fu, Drum, Cat, Glass, 8-Bit, Thunder, WWE, Metal, Slap, Mario
- **Custom sound packs** — Load any folder of MP3s
- **Lid angle sensor** — Detects open/close/slam, continuous creak/theremin audio
- **Custom lid sounds** — Pick your own MP3 for each lid event

### Stats & Gamification
- **Slap history** — 500 records with CSV export
- **Leaderboard** — Top 10 hardest slaps, best sessions
- **15 achievements** — Milestones, amplitude records, speed badges
- **Achievement notifications** — macOS alerts when you unlock badges

### Controls
- **Configurable global hotkey** — Record any key combination (default: Cmd+Shift+S)
- **Sound profiles** — Save/recall pack + sensitivity + volume combos
- **Mute timer** — Quick-mute for 5/15/30/60 minutes
- **Focus mode** — Mutes when macOS Do Not Disturb is active
- **Sensitivity tuning** — From "earthquake detector" to "needs a running start"

### Technical
- **Adaptive theme** — Follows macOS light/dark mode
- **FR/EN localization** — Auto-detects system language, 290+ strings
- **Sparkle auto-updater** — Check for updates from the app
- **Settings export/import** — Full JSON backup including leaderboard
- **MCP server** — HTTP API + Server-Sent Events on localhost:7749
- **Persistent logs** — File logging for debugging

## Sound Packs

| Pack | Clips | Style |
|------|-------|-------|
| Pain | 10 | Protest reactions |
| Sexy | 60 | Escalating intensity (decay scoring) |
| Halo | 9 | Game death sounds |
| Whip | 8 | Whip cracks & lashes |
| Cartoon | 10 | Bonk, boing, splat |
| Kung Fu | 10 | Martial arts hits |
| Drum | 10 | Snare, kick, crash |
| Cat | 10 | Surprised meows |
| Glass | 13 | Cracks to full shatter |
| 8-Bit | 10 | Retro game sounds |
| Thunder | 8 | Thunder & lightning |
| WWE | 10 | Body slams & crowd |
| Metal | 10 | Clang, gong, anvil |
| Slap | 10 | Claques & gifles |
| Mario | 10 | Jump, coin, power-up |
| Custom | — | Your own MP3s |

## How It Works

```
IOKit HID (background thread)
    │
    ▼
AccelerometerService — reads BMI286 via IOHIDManager
    │                  (22-byte reports, Int32 LE XYZ)
    ▼
ImpactDetector — 4 parallel algorithms vote
    │            STA/LTA │ CUSUM │ Kurtosis │ Peak/MAD
    ▼
SlapTracker — decay score for escalation modes
    │
    ▼
SoundManager — AVAudioEngine, PCM buffers (~2ms latency)
    │
    ▼
AppState (@MainActor) — central coordinator
    │
    ▼
MenuBarView — adaptive popover with counter, sparkline, controls
```

## MCP Server

SlapMyMac exposes a local HTTP API for automation:

```bash
curl http://localhost:7749/status       # Current state
curl http://localhost:7749/stats        # Slap statistics
curl http://localhost:7749/history      # Recent impacts (JSON)
curl http://localhost:7749/events       # Server-Sent Events (real-time)
curl -X POST http://localhost:7749/trigger           # Trigger a sound
curl -X POST -d '{"mode":"cat"}' http://localhost:7749/mode  # Switch pack
```

## Preferences

8 tabs: General, Sounds, Sensors, Stats, Leaderboard, Profiles, Roadmap, About.

- **General** — Startup, language, detection, audio, lid sounds, performance, menu bar, MCP, hotkey
- **Sounds** — Pack picker, custom folder browser, pack info
- **Sensors** — Accelerometer & lid sensor status, permission guidance
- **Stats** — Session/all-time stats, recent history, CSV export
- **Leaderboard** — Top slaps, best sessions, achievement badges
- **Profiles** — Save/load/delete sound profiles
- **About** — Credits, settings export/import, logs, check for updates

## Development

```bash
swift build          # Debug build
swift test           # Run unit tests
./Scripts/build.sh   # Build .app bundle
```

### Signed release build

```bash
DEVELOPER_ID="Developer ID Application: YOUR NAME (TEAMID)" ./Scripts/build.sh --release
./Scripts/create-dmg.sh
```

### Notarization

```bash
xcrun notarytool submit .build/SlapMyMac.dmg --keychain-profile "SlapMyMac" --wait
xcrun stapler staple .build/SlapMyMac.dmg
```

### Project Structure

```
Sources/SlapMyMac/
  App/           — AppState, Theme, L10n, Leaderboard, Constants, GlobalHotKey, KeyCodeMap, AppLogger, AppUpdater
  Sensor/        — AccelerometerService, LidAngleSensor
  Detection/     — ImpactDetector (4 algorithms), LidEventDetector
  Audio/         — SoundManager, SoundPack, SlapTracker, CreakEngine, ThereminEngine
  MCP/           — HTTP server + SSE, thread-safe snapshots
  Settings/      — UserSettings, LaunchAtLogin, SoundProfile, SettingsExporter
  Views/         — MenuBarView, PreferencesView, OnboardingView
  Resources/     — Info.plist, AppIcon.icns, Sounds/ (181 audio files)
```

## Credits

Based on [taigrr/spank](https://github.com/taigrr/spank) (Go) and [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor). Sound samples from [Mixkit](https://mixkit.co/) and [Kenney](https://kenney.nl/).

## License

MIT
