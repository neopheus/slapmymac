# SlapMyMac

**Your MacBook fights back.** A macOS menu bar app that detects physical slaps on Apple Silicon MacBooks using the built-in accelerometer and plays sound effects. Slap it. It screams.

<!--
TODO: Add screenshot/demo GIF here
![SlapMyMac Demo](docs/assets/demo.gif)
-->

## Features

- **Slap Detection** -- Uses the BMI286 accelerometer via IOKit HID with 4 parallel detection algorithms (STA/LTA, CUSUM, Kurtosis, Peak/MAD) for accurate impact recognition
- **13 Sound Packs** -- Pain, Sexy (escalating), Halo, Cat, Kung Fu, Metal, 8-Bit, Drum, Glass, Whip, Cartoon, WWE, Thunder -- or bring your own
- **Lid Angle Sensor** -- Reads lid position in real-time at 30Hz. Detects opens, closes, slams, and plays creaking sounds
- **Dark Menu Bar UI** -- Slap counter with animations, lid angle display, voice pack picker with preview, sensitivity slider, and live accelerometer debug
- **MCP Server** -- Local HTTP API on port 7749 for integration with Claude Code, Shortcuts, and scripts
- **Adjustable Sensitivity** -- Fine-tune detection threshold and cooldown between triggers
- **Volume Scaling** -- Louder slaps = louder sounds
- **Launch at Login** -- Runs silently in the menu bar via SMAppService
- **Slap Stats** -- Tracks lifetime slap count across sessions

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (M1/M2/M3/M4) -- uses `AppleSPUHIDDevice` which only exists on Apple Silicon laptops

## Install

### Download

Grab the latest `.dmg` from [Releases](https://github.com/neopheus/slapmymac/releases), mount it, and drag SlapMyMac to Applications.

### Build from Source

```bash
git clone https://github.com/neopheus/slapmymac.git
cd slapmymac
./Scripts/build.sh --release
open .build/SlapMyMac.app
```

## Sound Packs

| Pack | Clips | Style |
|------|-------|-------|
| Pain | 10 | Voice -- "Ow!", "Ouch!", "Hey that hurts!" |
| Sexy | 60 | Escalating moans with decay scoring (halfLife=30s) |
| Halo | 8 | Sci-fi energy weapons |
| Cat | 10 | Cat reactions |
| Kung Fu | 10 | Martial arts hits |
| Metal | 10 | Metal impacts |
| 8-Bit | 10 | Retro game sounds |
| Drum | 9 | Drum hits |
| Glass | 13 | Glass shatters |
| Whip | 8 | Whip cracks |
| Cartoon | 10 | Classic cartoon sound effects |
| WWE | 10 | Wrestling crowd & hits |
| Thunder | 8 | Thunder & lightning |
| Custom | -- | Drop your own MP3s in a folder |

## How It Works

```
IOKit HID (background thread)
    |
    v
AccelerometerService -- reads BMI286 via IOHIDManager
    |                   (22-byte reports, Int32 LE XYZ at offsets 6/10/14)
    v
ImpactDetector -- 4 parallel algorithms vote on impacts
    |             STA/LTA | CUSUM | Kurtosis | Peak/MAD
    v
SlapTracker -- decay score for escalation modes
    |
    v
SoundManager -- AVAudioPlayer, random or escalating selection
    |
    v
AppState (@MainActor) -- central coordinator
    |
    v
MenuBarView -- dark popover with counter, controls, debug
```

The lid angle sensor runs independently at 30Hz, detecting open/close/slam events and driving creak sound synthesis.

## MCP Server

SlapMyMac exposes a local HTTP API for automation:

```bash
curl http://localhost:7749/status    # Current state
curl http://localhost:7749/stats     # Slap statistics
curl http://localhost:7749/history   # Recent impacts
curl -X POST http://localhost:7749/trigger  # Trigger a slap sound
curl -X POST -d '{"mode":"cat"}' http://localhost:7749/mode  # Switch sound pack
```

See [docs/MCP.md](docs/MCP.md) for Claude Code integration and Shortcuts setup.

## Development

```bash
swift build          # Debug build
swift test           # Run 8 unit tests
./Scripts/build.sh   # Build .app bundle
```

### Creating a DMG for distribution

```bash
./Scripts/build.sh --release
./Scripts/create-dmg.sh
# Optional: set DEVELOPER_ID, APPLE_ID, TEAM_ID, APP_PASSWORD env vars for signing & notarization
```

### Project Structure

```
Sources/SlapMyMac/
  App/           -- Entry point, AppState, Theme, Constants
  Sensor/        -- AccelerometerService, LidAngleSensor
  Detection/     -- ImpactDetector (4 algorithms), LidEventDetector
  Audio/         -- SoundManager, SoundPack, SlapTracker, CreakEngine, ThereminEngine
  MCP/           -- HTTP server, thread-safe snapshots
  Settings/      -- UserSettings, LaunchAtLogin
  Views/         -- MenuBarView, PreferencesView, OnboardingView
  Resources/     -- Info.plist, Sounds/ (178 audio files)
```

## Credits

Based on [taigrr/spank](https://github.com/taigrr/spank) (Go) and [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor). Sound samples from [Mixkit](https://mixkit.co/) and [Kenney](https://kenney.nl/).

## License

[MIT](LICENSE)
