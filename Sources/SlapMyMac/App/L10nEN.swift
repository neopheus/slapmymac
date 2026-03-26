import Foundation

enum L10nEN {
    static let strings: [String: String] = [
        // App
        "app.name": "SlapMyMac",
        "app.tagline": "Slap your Mac, it yells back.",
        "app.version": "v1.6 \u{2014} macOS 14+ \u{2014} Apple Silicon",

        // Menu bar header
        "menubar.listening": "Listening for slaps...",
        "menubar.paused": "Paused",
        "menubar.slaps": "slaps",
        "menubar.lifetime": "Lifetime: %d",
        "menubar.detectors": "(%d detectors)",

        // Lid events
        "lid.opened": "OPENED",
        "lid.closed": "CLOSED",
        "lid.slammed": "SLAMMED",
        "lid.creak": "CREAK",
        "lid.angle": "Lid Angle",

        // Voice pack card
        "voicepack.title": "Voice Pack",
        "voicepack.clips": "%d clips",

        // Sensitivity card
        "sensitivity.title": "Sensitivity",
        "sensitivity.cooldown": "Cooldown: %@",
        "sensitivity.volumeScaling": "Volume scaling",

        // Debug card
        "debug.accelerometer": "ACCELEROMETER",

        // Impact badges
        "impact.major": "MAJOR",
        "impact.medium": "MEDIUM",
        "impact.micro": "MICRO",
        "impact.vibration": "VIBRATION",

        // Mute timer
        "mute.title": "Mute Timer",
        "mute.for": "Mute for %d min",
        "mute.remaining": "Muted \u{2014} %@ remaining",
        "mute.cancel": "Cancel Mute",
        "mute.5min": "5 min",
        "mute.15min": "15 min",
        "mute.30min": "30 min",
        "mute.60min": "1 hour",

        // Sparkline
        "sparkline.title": "RECENT IMPACTS",
        "sparkline.empty": "No impacts yet",

        // Preferences tabs
        "tab.general": "General",
        "tab.sounds": "Sounds",
        "tab.sensors": "Sensors",
        "tab.stats": "Stats",
        "tab.leaderboard": "Leaderboard",
        "tab.profiles": "Profiles",
        "tab.roadmap": "Roadmap",
        "tab.about": "About",

        // General tab - Startup
        "general.startup": "Startup",
        "general.launchAtLogin": "Launch at login",

        // General tab - Language
        "general.language": "Language",
        "general.language.label": "App Language",
        "general.language.restart": "Restart the app for the change to take effect",

        // General tab - Detection
        "general.detection": "Detection",
        "general.sensitivity": "Sensitivity",
        "general.sensitivity.earthquake": "Earthquake detector",
        "general.sensitivity.feather": "Feather touch",
        "general.sensitivity.light": "Light tap",
        "general.sensitivity.normal": "Normal slap",
        "general.sensitivity.strong": "Strong hit",
        "general.sensitivity.running": "Needs a running start",
        "general.cooldown": "Cooldown",
        "general.cooldown.desc": "Minimum delay between sound effects",

        // General tab - Audio
        "general.audio": "Audio",
        "general.masterVolume": "Master Volume",
        "general.volumeScaling": "Scale volume by impact force",
        "general.volumeScaling.desc": "Harder slaps play louder sounds",
        "general.respectFocus": "Respect Focus / Do Not Disturb",
        "general.respectFocus.desc": "Mute all sounds when macOS Focus mode is active",
        "general.startupSound": "Play sound on start/stop",
        "general.startupSound.desc": "Audio feedback when toggling detection",

        // General tab - Lid
        "general.lidSounds": "Lid Sounds",
        "general.lidContinuous": "Continuous lid audio (creak/theremin)",
        "general.lidEvents": "Lid event sounds (open/close/slam)",
        "general.lidSound.open": "Open sound",
        "general.lidSound.close": "Close sound",
        "general.lidSound.slam": "Slam sound",
        "general.lidSound.default": "Default (bundled)",
        "general.lidSound.chooseDesc": "Choose an MP3 file for this lid event",
        "general.lidMode": "Mode",

        // General tab - Lid Performance
        "general.lidPerformance": "Lid Performance",
        "general.pollRate": "Poll Rate",
        "general.pollRate.low": "15 Hz (light)",
        "general.pollRate.high": "120 Hz (fastest)",
        "general.angleSmoothing": "Angle Smoothing",
        "general.angleSmoothing.desc": "Time constant \u{2014} lower = faster response, noisier signal",
        "general.eventCooldown": "Event Cooldown",
        "general.eventCooldown.desc": "Minimum delay between lid open/close/slam events",
        "general.lidEngine": "Lid audio: AVAudioEngine with ~6ms hardware buffer",

        // General tab - Performance
        "general.performance": "Performance",
        "general.sampleRate": "Sample Rate",
        "general.sampleRate.fast": "400 Hz (fastest)",
        "general.sampleRate.light": "100 Hz (lightest)",
        "general.suppression": "Post-Impact Suppression",
        "general.suppression.desc": "Blocks re-triggers from aftershock vibrations",
        "general.kurtosis": "Kurtosis Evaluation",
        "general.kurtosis.every": "Every sample",
        "general.kurtosis.everyN": "Every %d samples",
        "general.kurtosis.desc": "Lower = faster detection, slightly more CPU",
        "general.audioEngine": "Audio Engine: Pre-decoded PCM buffers (~2ms latency)",

        // General tab - Menu Bar
        "general.menuBar": "Menu Bar",
        "general.showCount": "Show slap count in menu bar",
        "general.milestoneNotif": "Milestone notifications",
        "general.milestoneNotif.desc": "Notify at 10, 50, 100, 500, 1000 slaps and new amplitude records",

        // General tab - MCP Server
        "general.mcpServer": "MCP Server",
        "general.mcpEnabled": "Enable local MCP server",
        "general.mcpDesc": "Exposes slap data on http://localhost:7749 for AI tools and scripts",

        // General tab - Hotkey
        "general.hotkey": "Global Hotkey",
        "general.hotkeyToggle": "Toggle listening",
        "general.hotkeyDefault": "Cmd + Shift + S",
        "general.hotkeyDesc": "Works from any app \u{2014} mutes/unmutes slap detection",
        "general.hotkeyRecording": "Press a key...",

        // Sounds tab
        "sounds.voicePack": "Voice Pack",
        "sounds.activePack": "Active Pack",
        "sounds.clipsLoaded": "Clips loaded",
        "sounds.testSound": "Test Sound",
        "sounds.customSounds": "Custom Sounds",
        "sounds.folderPath": "Folder path",
        "sounds.browse": "Browse...",
        "sounds.browseDesc": "Select a folder containing MP3 files",
        "sounds.included": "Voice Packs Included",

        // Sensors tab
        "sensors.accelerometer": "Accelerometer (BMI286)",
        "sensors.status": "Status",
        "sensors.active": "Active",
        "sensors.inactive": "Inactive",
        "sensors.reading": "Reading",
        "sensors.error": "Error",
        "sensors.accelDesc": "Uses IOKit HID to read the Bosch BMI286 IMU at ~%dHz",
        "sensors.lidSensor": "Lid Angle Sensor",
        "sensors.available": "Available",
        "sensors.yes": "Yes",
        "sensors.no": "No",
        "sensors.angle": "Angle",
        "sensors.velocity": "Velocity",
        "sensors.lidDesc": "Reads the lid hinge angle via IOKit HID feature reports at 30Hz",
        "sensors.algorithm": "Detection Algorithm",
        "sensors.algorithmDesc": "4 parallel detectors: STA/LTA, CUSUM, Kurtosis, Peak/MAD",
        "sensors.classificationDesc": "Classification: Major (4+ detectors), Medium (3+), Micro, Vibration",
        "sensors.permissionTitle": "Sensor Access",
        "sensors.permissionDesc": "If the accelerometer shows 'Inactive', try:\n1. Open System Settings \u{2192} Privacy & Security \u{2192} Input Monitoring\n2. Add SlapMyMac and grant access\n3. Restart the app",

        // Stats tab
        "stats.session": "Session",
        "stats.sessionSlaps": "Session slaps",
        "stats.slapsPerMin": "Slaps/minute",
        "stats.duration": "Duration",
        "stats.resetSession": "Reset Session",
        "stats.allTime": "All Time",
        "stats.totalRecorded": "Total recorded slaps",
        "stats.lifetimeCounter": "Lifetime counter",
        "stats.avgAmplitude": "Avg amplitude",
        "stats.maxAmplitude": "Max amplitude",
        "stats.majorImpacts": "Major impacts",
        "stats.mediumImpacts": "Medium impacts",
        "stats.favoriteMode": "Favorite mode",
        "stats.recentHistory": "Recent History",
        "stats.noSlaps": "No slaps recorded yet. Go slap your Mac!",
        "stats.exportCSV": "Export CSV...",
        "stats.exportFull": "Export All (CSV + Leaderboard)...",
        "stats.clearHistory": "Clear All History",

        // Leaderboard tab
        "leaderboard.topSlaps": "Top 10 Hardest Slaps",
        "leaderboard.noSlaps": "No slaps recorded yet. Get slapping!",
        "leaderboard.bestSessions": "Best Sessions",
        "leaderboard.noSessions": "Complete a session to see records here.",
        "leaderboard.slaps": "%d slaps",
        "leaderboard.achievements": "Achievements (%d/%d)",
        "leaderboard.copyClipboard": "Copy Leaderboard to Clipboard",

        // Profiles tab
        "profiles.title": "Sound Profiles",
        "profiles.desc": "Save and recall combinations of pack, sensitivity, and volume.",
        "profiles.noProfiles": "No profiles saved yet.",
        "profiles.save": "Save Current as Profile",
        "profiles.name": "Profile name",
        "profiles.load": "Load",
        "profiles.delete": "Delete",
        "profiles.active": "Active:",
        "profiles.pack": "Pack",
        "profiles.sensitivity": "Sensitivity",
        "profiles.volume": "Volume",

        // Roadmap tab
        "roadmap.title": "Roadmap",
        "roadmap.shipped": "Shipped",
        "roadmap.inProgress": "In Progress",
        "roadmap.planned": "Planned",
        "roadmap.v10.title": "Core Experience",
        "roadmap.v10.desc": "Slap detection, 3 voice packs (79 clips), menu bar app, lid angle sensor, sensitivity & cooldown controls",
        "roadmap.v11.title": "Custom Sound Packs",
        "roadmap.v11.desc": "Import your own MP3 folders. Record your voice, your pet, your boss \u{2014} anything goes.",
        "roadmap.v12.title": "Lid Open/Close/Slam Sounds",
        "roadmap.v12.desc": "Detects lid opening, closing, and slamming via the angle sensor. Each event plays a different sound.",
        "roadmap.v13.title": "MCP Server Integration",
        "roadmap.v13.desc": "Local HTTP server on port 7749. AI tools and scripts can read slap data, trigger sounds, and change modes.",
        "roadmap.v14.title": "Slap Stats & History",
        "roadmap.v14.desc": "Full slap history with timestamps, amplitudes, severity. Session stats, lifetime counter, per-minute rate.",
        "roadmap.v15.title": "Menu Bar Slap Counter",
        "roadmap.v15.desc": "Shows your session slap count right in the menu bar next to the hand icon.",
        "roadmap.v16.title": "Localization, Profiles & More",
        "roadmap.v16.desc": "French localization, sound profiles, settings export/import, mute timer, impact sparkline, achievement notifications, adaptive theme.",
        "roadmap.v20.title": "Community & Cloud",
        "roadmap.v20.desc": "Community voice pack sharing, online leaderboards, and auto-updates.",

        // About tab
        "about.lifetimeSlaps": "Lifetime slaps:",
        "about.basedOn": "Based on",
        "about.soundAttrib": "Sound Attributions",
        "about.soundCredits": "Slap pack: SoundBible (Public Domain) + Albert Wu (CC-BY 4.0)",
        "about.checkUpdates": "Check for Updates...",
        "about.exportSettings": "Export Settings...",
        "about.importSettings": "Import Settings...",
        "about.logs": "View Logs...",

        // Sound mode names
        "sound.pain": "Pain",
        "sound.sexy": "Sexy",
        "sound.halo": "Halo",
        "sound.whip": "Whip",
        "sound.cartoon": "Cartoon",
        "sound.kungfu": "Kung Fu",
        "sound.drum": "Drum",
        "sound.cat": "Cat",
        "sound.glass": "Glass",
        "sound.eightbit": "8-Bit",
        "sound.thunder": "Thunder",
        "sound.wwe": "WWE",
        "sound.metal": "Metal",
        "sound.slap": "Slap",
        "sound.mario": "Mario",
        "sound.lid": "Lid",
        "sound.custom": "Custom",

        // Sound mode descriptions
        "sound.pain.desc": "10 protest/pain reactions",
        "sound.sexy.desc": "60-level escalating intensity",
        "sound.halo.desc": "Halo game death sounds",
        "sound.whip.desc": "Whip cracks & lashes",
        "sound.cartoon.desc": "Bonk, boing, splat, bell",
        "sound.kungfu.desc": "Martial arts hits & kiai",
        "sound.drum.desc": "Snare, kick, rimshot, crash",
        "sound.cat.desc": "Surprised & angry meows",
        "sound.glass.desc": "Cracks to full shatter",
        "sound.eightbit.desc": "Retro game hit sounds",
        "sound.thunder.desc": "Thunder cracks & rumbles",
        "sound.wwe.desc": "Body slams & crowd oohs",
        "sound.metal.desc": "Clang, gong, anvil strikes",
        "sound.slap.desc": "Claques, gifles & fess\u{00E9}es",
        "sound.mario.desc": "Jump, coin, stomp, power-up",
        "sound.lid.desc": "Lid open/close/slam sounds",
        "sound.custom.desc": "Your own MP3 files",

        // Achievement titles
        "achievement.firstSlap": "First Contact",
        "achievement.slaps10": "Getting Started",
        "achievement.slaps50": "Warming Up",
        "achievement.slaps100": "Century Club",
        "achievement.slaps500": "Slap Enthusiast",
        "achievement.slaps1000": "Slap Master",
        "achievement.slaps5000": "Slap Legend",
        "achievement.amp01": "Light Touch",
        "achievement.amp03": "Solid Hit",
        "achievement.amp05": "Earthquake",
        "achievement.amp08": "Destruction",
        "achievement.allMajor": "Perfect Storm",
        "achievement.rate10": "Rapid Fire",
        "achievement.session30": "Marathon",
        "achievement.session100": "Endurance",

        // Achievement descriptions
        "achievement.firstSlap.desc": "Land your first slap",
        "achievement.slaps10.desc": "10 lifetime slaps",
        "achievement.slaps50.desc": "50 lifetime slaps",
        "achievement.slaps100.desc": "100 lifetime slaps",
        "achievement.slaps500.desc": "500 lifetime slaps",
        "achievement.slaps1000.desc": "1,000 lifetime slaps",
        "achievement.slaps5000.desc": "5,000 lifetime slaps",
        "achievement.amp01.desc": "Hit 0.1g amplitude",
        "achievement.amp03.desc": "Hit 0.3g amplitude",
        "achievement.amp05.desc": "Hit 0.5g amplitude",
        "achievement.amp08.desc": "Hit 0.8g amplitude",
        "achievement.allMajor.desc": "Trigger all 4 detectors",
        "achievement.rate10.desc": "10+ slaps per minute",
        "achievement.session30.desc": "30+ slaps in one session",
        "achievement.session100.desc": "100+ slaps in one session",

        // Notifications
        "notif.firstSlap": "First slap!",
        "notif.firstSlap.body": "Your Mac felt that.",
        "notif.milestone": "%d slaps!",
        "notif.milestone.body": "You've reached %d lifetime slaps.",
        "notif.record": "New record!",
        "notif.record.body": "%.3fg \u{2014} your hardest slap yet.",
        "notif.achievement": "Achievement unlocked!",
        "notif.achievement.body": "%@ \u{2014} %@",

        // Leaderboard share text
        "share.title": "SlapMyMac Leaderboard",
        "share.lifetime": "Lifetime slaps: %d",
        "share.hardest": "Hardest slap: %@",
        "share.achievements": "Achievements: %d/%d",
        "share.top3": "Top 3: %@",

        // Onboarding
        "onboarding.welcome.title": "Welcome to SlapMyMac",
        "onboarding.welcome.body": "Your MacBook can feel when you slap it. We use the built-in accelerometer to detect impacts and play sounds. Go ahead \u{2014} give it a try.",
        "onboarding.sounds.title": "Pick Your Sounds",
        "onboarding.sounds.body": "Choose from 15 voice packs: Pain, Sexy, Halo, Cartoon, Kung Fu, and more. You can also load your own MP3 folder.",
        "onboarding.sensitivity.title": "Tune Your Sensitivity",
        "onboarding.sensitivity.body": "Adjust how hard you need to slap. From \"earthquake detector\" (feels everything) to \"needs a running start\" (only big hits). Find your sweet spot in the menu bar.",
        "onboarding.menubar.title": "Lives in Your Menu Bar",
        "onboarding.menubar.body": "SlapMyMac runs quietly in your menu bar. Click the hand icon to see your slap count, change voice packs, and adjust settings. Enable \"Launch at login\" to always be ready.",
        "onboarding.next": "Next",
        "onboarding.start": "Start Slapping",
        "onboarding.skip": "Skip",

        // Settings export/import
        "settings.exported": "Settings exported successfully",
        "settings.imported": "Settings imported successfully",
        "settings.importError": "Failed to import settings",
        "settings.exportDesc": "Export all settings, profiles, and leaderboard data",
        "settings.importDesc": "Import settings from a previously exported file",

        // Logger
        "log.title": "Application Logs",
        "log.export": "Export Logs...",
        "log.clear": "Clear Logs",
        "log.empty": "No log entries yet.",

        // Errors / Permission guidance
        "error.customEmpty": "Custom folder is empty \u{2014} no MP3 files found",
        "error.sensorAccess": "Sensor access denied. Check System Settings \u{2192} Privacy & Security.",
    ]
}
