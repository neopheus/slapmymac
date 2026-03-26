import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }

            SoundsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Sounds", systemImage: "speaker.wave.3.fill")
                }

            SensorsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Sensors", systemImage: "waveform.path.ecg")
                }

            StatsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            RoadmapTab()
                .tabItem {
                    Label("Roadmap", systemImage: "map.fill")
                }

            AboutTab()
                .environmentObject(appState)
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $appState.settings.launchAtLogin)
            }

            Section("Detection") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(appState.settings.sensitivityLabel)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Slider(value: $appState.settings.sensitivity, in: 0.005...0.50, step: 0.005)
                    HStack {
                        Text("Earthquake detector")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Needs a running start")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.sensitivity) {
                    appState.applySensitivitySettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cooldown")
                        Spacer()
                        Text(String(format: "%.1fs", Double(appState.settings.cooldownMs) / 1000.0))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.cooldownMs) },
                            set: { appState.settings.cooldownMs = Int($0) }
                        ),
                        in: 100...3000,
                        step: 100
                    )
                    Text("Minimum delay between sound effects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.cooldownMs) {
                    appState.applySensitivitySettings()
                }
            }

            Section("Audio") {
                Toggle("Scale volume by impact force", isOn: $appState.settings.volumeScaling)
                Text("Harder slaps play louder sounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Lid Sounds") {
                Toggle("Enable lid sounds", isOn: $appState.settings.lidSoundsEnabled)
                    .onChange(of: appState.settings.lidSoundsEnabled) {
                        appState.updateLidAudioMode()
                    }

                if appState.settings.lidSoundsEnabled {
                    Picker("Mode", selection: $appState.settings.lidAudioMode) {
                        ForEach(LidAudioMode.allCases) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                            }.tag(mode)
                        }
                    }
                    .onChange(of: appState.settings.lidAudioMode) {
                        appState.updateLidAudioMode()
                    }

                    Text(appState.settings.lidAudioMode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lid Performance") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Poll Rate")
                        Spacer()
                        Text("\(Int(appState.settings.lidPollHz)) Hz")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.lidPollHz, in: 15...120, step: 5)
                    HStack {
                        Text("15 Hz (light)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("120 Hz (fastest)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.lidPollHz) {
                    appState.applyLidPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Angle Smoothing")
                        Spacer()
                        Text("\(Int(appState.settings.angleSmoothingTau * 1000)) ms")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.angleSmoothingTau, in: 0.01...0.30, step: 0.01)
                    Text("Time constant — lower = faster response, noisier signal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.angleSmoothingTau) {
                    appState.applyLidPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Event Cooldown")
                        Spacer()
                        Text(String(format: "%.1fs", appState.settings.lidEventCooldown))
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.lidEventCooldown, in: 0.3...5.0, step: 0.1)
                    Text("Minimum delay between lid open/close/slam events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.lidEventCooldown) {
                    appState.applyLidPerformanceSettings()
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundStyle(.green)
                    Text("Lid audio: AVAudioEngine with ~6ms hardware buffer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Performance") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sample Rate")
                        Spacer()
                        Text(appState.settings.sampleRateLabel)
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.decimationFactor) },
                            set: { appState.settings.decimationFactor = Int($0) }
                        ),
                        in: 2...8,
                        step: 1
                    )
                    HStack {
                        Text("400 Hz (fastest)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("100 Hz (lightest)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.decimationFactor) {
                    appState.applyPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Post-Impact Suppression")
                        Spacer()
                        Text("\(appState.settings.suppressionMs) ms")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.suppressionSamples) },
                            set: { appState.settings.suppressionSamples = Int($0) }
                        ),
                        in: 5...50,
                        step: 1
                    )
                    Text("Blocks re-triggers from aftershock vibrations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.suppressionSamples) {
                    appState.applyPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Kurtosis Evaluation")
                        Spacer()
                        Text(appState.settings.kurtosisEvalInterval == 1 ? "Every sample" : "Every \(appState.settings.kurtosisEvalInterval) samples")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.kurtosisEvalInterval) },
                            set: { appState.settings.kurtosisEvalInterval = Int($0) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    Text("Lower = faster detection, slightly more CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.kurtosisEvalInterval) {
                    appState.applyPerformanceSettings()
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundStyle(.green)
                    Text("Audio Engine: Pre-decoded PCM buffers (~2ms latency)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Menu Bar") {
                Toggle("Show slap count in menu bar", isOn: $appState.settings.showSlapCountInMenuBar)
            }

            Section("MCP Server") {
                Toggle("Enable local MCP server", isOn: $appState.settings.mcpServerEnabled)
                    .onChange(of: appState.settings.mcpServerEnabled) {
                        appState.toggleMCPServer()
                    }
                Text("Exposes slap data on http://localhost:7749 for AI tools and scripts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Toggle listening")
                    Spacer()
                    Text("Cmd + Shift + S")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("Works from any app — mutes/unmutes slap detection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Voice Pack") {
                Picker("Active Pack", selection: $appState.settings.soundMode) {
                    ForEach(SoundMode.allCases) { mode in
                        HStack {
                            Text(mode.displayName)
                            Spacer()
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .onChange(of: appState.settings.soundMode) {
                    appState.loadSoundPack()
                }

                if let pack = appState.currentPack {
                    LabeledContent("Clips loaded") {
                        Text("\(pack.count)")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Button("Test Sound") {
                    appState.playTestSound()
                }
            }

            if appState.settings.soundMode == .custom {
                Section("Custom Sounds") {
                    HStack {
                        TextField("Folder path", text: $appState.settings.customSoundPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        Button("Browse...") {
                            chooseFolder()
                        }
                    }
                    Text("Select a folder containing MP3 files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Voice Packs Included") {
                ForEach(SoundMode.allCases.filter { $0 != .custom }) { mode in
                    VoicePackInfoRow(mode: mode)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing MP3 files"

        if panel.runModal() == .OK, let url = panel.url {
            if let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "customSoundBookmark")
            }
            appState.settings.customSoundPath = url.path
            appState.loadSoundPack()
        }
    }
}

private struct VoicePackInfoRow: View {
    let mode: SoundMode

    private var clipCount: Int {
        SoundPack.bundled(mode).count
    }

    var body: some View {
        HStack {
            Image(systemName: mode.icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.headline)
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(clipCount) clips")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Stats Tab

private struct StatsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let s = appState.history.stats

        Form {
            Section("Session") {
                LabeledContent("Session slaps") {
                    Text("\(s.sessionSlaps)")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Slaps/minute") {
                    Text(String(format: "%.1f", s.slapsPerMinute))
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Duration") {
                    Text(formatDuration(s.sessionDuration))
                        .font(.system(.body, design: .monospaced))
                }

                Button("Reset Session") {
                    appState.history.resetSession()
                }
            }

            Section("All Time") {
                LabeledContent("Total recorded slaps") {
                    Text("\(s.totalSlaps)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }
                LabeledContent("Lifetime counter") {
                    Text("\(appState.settings.lifetimeSlaps)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
                LabeledContent("Avg amplitude") {
                    Text(String(format: "%.4fg", s.avgAmplitude))
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Max amplitude") {
                    Text(String(format: "%.4fg", s.maxAmplitude))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.red)
                }
                LabeledContent("Major impacts") {
                    Text("\(s.majorCount)")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Medium impacts") {
                    Text("\(s.mediumCount)")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Favorite mode") {
                    Text(s.favoriteMode.capitalized)
                }
            }

            Section("Recent History") {
                if appState.history.recentRecords(10).isEmpty {
                    Text("No slaps recorded yet. Go slap your Mac!")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(appState.history.recentRecords(10)) { record in
                        HStack {
                            Text(record.severity.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(record.severity == "major" ? .red : .orange)
                                .frame(width: 50, alignment: .leading)
                            Text(String(format: "%.3fg", record.amplitude))
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text(record.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Export CSV...") {
                        exportCSV()
                    }

                    Spacer()

                    Button("Clear All History", role: .destructive) {
                        appState.history.clearHistory()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    private func exportCSV() {
        let csv = appState.history.exportCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slap-history.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.message = "Export slap history as CSV"

        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Sensors Tab

private struct SensorsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Accelerometer (BMI286)") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isListening ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(appState.isListening ? "Active" : "Inactive")
                    }
                }

                if appState.isListening {
                    LabeledContent("Reading") {
                        Text(appState.lastSampleDebug)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let error = appState.errorMessage {
                    LabeledContent("Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text("Uses IOKit HID to read the Bosch BMI286 IMU at ~\(appState.settings.sampleRateHz)Hz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Lid Angle Sensor") {
                LabeledContent("Available") {
                    Text(appState.lidAngle.isAvailable ? "Yes" : "No")
                }

                if appState.lidAngle.isAvailable {
                    LabeledContent("Angle") {
                        Text("\(Int(appState.lidAngle.angle))°")
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("Velocity") {
                        Text(String(format: "%.1f °/s", appState.lidAngle.velocity))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Text("Reads the lid hinge angle via IOKit HID feature reports at 30Hz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Detection Algorithm") {
                Text("4 parallel detectors: STA/LTA, CUSUM, Kurtosis, Peak/MAD")
                    .font(.caption)
                Text("Classification: Major (4+ detectors), Medium (3+), Micro, Vibration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Roadmap Tab

private struct RoadmapTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Roadmap")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

            List {
                RoadmapItem(
                    version: "v1.0",
                    title: "Core Experience",
                    description: "Slap detection, 3 voice packs (79 clips), menu bar app, lid angle sensor, sensitivity & cooldown controls",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v1.1",
                    title: "Custom Sound Packs",
                    description: "Import your own MP3 folders. Record your voice, your pet, your boss — anything goes.",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v1.2",
                    title: "Lid Open/Close/Slam Sounds",
                    description: "Detects lid opening, closing, and slamming via the angle sensor. Each event plays a different sound.",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v1.3",
                    title: "MCP Server Integration",
                    description: "Local HTTP server on port 7749. AI tools and scripts can read slap data, trigger sounds, and change modes.",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v1.4",
                    title: "Slap Stats & History",
                    description: "Full slap history with timestamps, amplitudes, severity. Session stats, lifetime counter, per-minute rate.",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v1.5",
                    title: "Menu Bar Slap Counter",
                    description: "Shows your session slap count right in the menu bar next to the hand icon.",
                    status: .shipped
                )

                RoadmapItem(
                    version: "v2.0",
                    title: "More Voice Packs & Leaderboards",
                    description: "Community voice pack sharing, slap leaderboards, and force graph visualizations.",
                    status: .planned
                )
            }
            .listStyle(.plain)
        }
    }
}

private enum RoadmapStatus {
    case shipped, inProgress, planned

    var label: String {
        switch self {
        case .shipped: return "Shipped"
        case .inProgress: return "In Progress"
        case .planned: return "Planned"
        }
    }

    var color: Color {
        switch self {
        case .shipped: return .green
        case .inProgress: return .orange
        case .planned: return .secondary
        }
    }
}

private struct RoadmapItem: View {
    let version: String
    let title: String
    let description: String
    let status: RoadmapStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Version badge
            Text(version)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(status == .shipped ? Color.green : Color.secondary.opacity(0.3))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(status.label)
                        .font(.caption)
                        .foregroundStyle(status.color)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("SlapMyMac")
                .font(.system(size: 24, weight: .black, design: .rounded))

            Text("Slap your Mac, it yells back.")
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Lifetime slaps:")
                    .foregroundStyle(.secondary)
                Text("\(appState.settings.lifetimeSlaps)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("Based on")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 16) {
                    Link("spank by taigrr", destination: URL(string: "https://github.com/taigrr/spank")!)
                        .font(.caption)
                    Link("LidAngleSensor by samhenrigold", destination: URL(string: "https://github.com/samhenrigold/LidAngleSensor")!)
                        .font(.caption)
                }
            }

            Text("v1.0 — macOS 14+ — Apple Silicon")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
