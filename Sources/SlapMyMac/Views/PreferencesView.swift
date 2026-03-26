import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewID = UUID()

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.general"), systemImage: "gearshape.fill") }

            SoundsTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.sounds"), systemImage: "speaker.wave.3.fill") }

            SensorsTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.sensors"), systemImage: "waveform.path.ecg") }

            StatsTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.stats"), systemImage: "chart.bar.fill") }

            LeaderboardTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.leaderboard"), systemImage: "trophy.fill") }

            ProfilesTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.profiles"), systemImage: "person.2.fill") }

            RoadmapTab()
                .tabItem { Label(L10n.tr("tab.roadmap"), systemImage: "map.fill") }

            AboutTab()
                .environmentObject(appState)
                .tabItem { Label(L10n.tr("tab.about"), systemImage: "info.circle.fill") }
        }
        .frame(width: 620, height: 520)
        .tint(Theme.accent)
        .accentColor(Theme.accent)
        .id(viewID)
        .onAppear {
            // Force re-render after window appearance context is resolved
            DispatchQueue.main.async { viewID = UUID() }
        }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section(L10n.tr("general.startup")) {
                Toggle(L10n.tr("general.launchAtLogin"), isOn: $appState.settings.launchAtLogin)
            }

            Section(L10n.tr("general.language")) {
                Picker(L10n.tr("general.language.label"), selection: Binding(
                    get: { UserDefaults.standard.string(forKey: "appLanguage") ?? "" },
                    set: { UserDefaults.standard.set($0, forKey: "appLanguage") }
                )) {
                    ForEach(L10n.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                Text(L10n.tr("general.language.restart"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("general.detection")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.sensitivity"))
                        Spacer()
                        Text(appState.settings.sensitivityLabel)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Slider(value: $appState.settings.sensitivity, in: 0.005...0.50, step: 0.005)
                    HStack {
                        Text(L10n.tr("general.sensitivity.earthquake"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(L10n.tr("general.sensitivity.running"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.sensitivity) {
                    appState.applySensitivitySettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.cooldown"))
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
                    Text(L10n.tr("general.cooldown.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.cooldownMs) {
                    appState.applySensitivitySettings()
                }
            }

            Section(L10n.tr("general.audio")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.masterVolume"))
                        Spacer()
                        Text("\(Int(appState.settings.masterVolume * 100))%")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.masterVolume, in: 0...1, step: 0.05)
                }
                .onChange(of: appState.settings.masterVolume) {
                    appState.applyMasterVolume()
                }

                Toggle(L10n.tr("general.volumeScaling"), isOn: $appState.settings.volumeScaling)
                Text(L10n.tr("general.volumeScaling.desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.tr("general.respectFocus"), isOn: $appState.settings.respectFocus)
                Text(L10n.tr("general.respectFocus.desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.tr("general.startupSound"), isOn: $appState.settings.startupSoundEnabled)
                Text(L10n.tr("general.startupSound.desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("general.lidSounds")) {
                Toggle(L10n.tr("general.lidContinuous"), isOn: $appState.settings.lidSoundsEnabled)
                    .onChange(of: appState.settings.lidSoundsEnabled) {
                        appState.updateLidAudioMode()
                    }

                Toggle(L10n.tr("general.lidEvents"), isOn: $appState.settings.lidEventSoundsEnabled)

                if appState.settings.lidEventSoundsEnabled {
                    LidSoundPicker(
                        label: L10n.tr("general.lidSound.open"),
                        path: $appState.settings.customLidOpenPath,
                        onChanged: { appState.reloadLidEventSounds() }
                    )
                    LidSoundPicker(
                        label: L10n.tr("general.lidSound.close"),
                        path: $appState.settings.customLidClosePath,
                        onChanged: { appState.reloadLidEventSounds() }
                    )
                    LidSoundPicker(
                        label: L10n.tr("general.lidSound.slam"),
                        path: $appState.settings.customLidSlamPath,
                        onChanged: { appState.reloadLidEventSounds() }
                    )
                }

                if appState.settings.lidSoundsEnabled {
                    Picker(L10n.tr("general.lidMode"), selection: $appState.settings.lidAudioMode) {
                        ForEach(LidAudioMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
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

            Section(L10n.tr("general.lidPerformance")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.pollRate"))
                        Spacer()
                        Text("\(Int(appState.settings.lidPollHz)) Hz")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.lidPollHz, in: 15...120, step: 5)
                    HStack {
                        Text(L10n.tr("general.pollRate.low"))
                            .font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text(L10n.tr("general.pollRate.high"))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.lidPollHz) {
                    appState.applyLidPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.angleSmoothing"))
                        Spacer()
                        Text("\(Int(appState.settings.angleSmoothingTau * 1000)) ms")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.angleSmoothingTau, in: 0.01...0.30, step: 0.01)
                    Text(L10n.tr("general.angleSmoothing.desc"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.angleSmoothingTau) {
                    appState.applyLidPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.eventCooldown"))
                        Spacer()
                        Text(String(format: "%.1fs", appState.settings.lidEventCooldown))
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, design: .monospaced))
                    }
                    Slider(value: $appState.settings.lidEventCooldown, in: 0.3...5.0, step: 0.1)
                    Text(L10n.tr("general.eventCooldown.desc"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.lidEventCooldown) {
                    appState.applyLidPerformanceSettings()
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill").foregroundStyle(.green)
                    Text(L10n.tr("general.lidEngine"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(L10n.tr("general.performance")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.sampleRate"))
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
                        in: 2...8, step: 1
                    )
                    HStack {
                        Text(L10n.tr("general.sampleRate.fast"))
                            .font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text(L10n.tr("general.sampleRate.light"))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .onChange(of: appState.settings.decimationFactor) {
                    appState.applyPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.suppression"))
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
                        in: 5...50, step: 1
                    )
                    Text(L10n.tr("general.suppression.desc"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.suppressionSamples) {
                    appState.applyPerformanceSettings()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("general.kurtosis"))
                        Spacer()
                        Text(appState.settings.kurtosisEvalInterval == 1 ? L10n.tr("general.kurtosis.every") : L10n.tr("general.kurtosis.everyN", appState.settings.kurtosisEvalInterval))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.kurtosisEvalInterval) },
                            set: { appState.settings.kurtosisEvalInterval = Int($0) }
                        ),
                        in: 1...10, step: 1
                    )
                    Text(L10n.tr("general.kurtosis.desc"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: appState.settings.kurtosisEvalInterval) {
                    appState.applyPerformanceSettings()
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill").foregroundStyle(.green)
                    Text(L10n.tr("general.audioEngine"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(L10n.tr("general.menuBar")) {
                Toggle(L10n.tr("general.showCount"), isOn: $appState.settings.showSlapCountInMenuBar)
                Toggle(L10n.tr("general.milestoneNotif"), isOn: $appState.settings.notificationsEnabled)
                Text(L10n.tr("general.milestoneNotif.desc"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("general.mcpServer")) {
                Toggle(L10n.tr("general.mcpEnabled"), isOn: $appState.settings.mcpServerEnabled)
                    .onChange(of: appState.settings.mcpServerEnabled) {
                        appState.toggleMCPServer()
                    }
                Text(L10n.tr("general.mcpDesc"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("general.hotkey")) {
                HotKeyRecorderRow()
                    .environmentObject(appState)
                Text(L10n.tr("general.hotkeyDesc"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Hot Key Recorder

private struct HotKeyRecorderRow: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(L10n.tr("general.hotkeyToggle"))
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                if isRecording {
                    Text(L10n.tr("general.hotkeyRecording"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text(appState.settings.hotKeyLabel)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore bare modifier keys (no actual key pressed)
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !modifiers.isEmpty else {
                stopRecording()
                return nil
            }

            // Require at least one modifier
            let carbonMods = KeyCodeMap.carbonModifiers(from: modifiers)
            guard carbonMods != 0 else {
                stopRecording()
                return nil
            }

            appState.settings.hotKeyCode = Int(event.keyCode)
            appState.settings.hotKeyModifiers = carbonMods
            appState.applyHotKey()
            stopRecording()
            return nil  // Swallow the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - Lid Sound Picker

private struct LidSoundPicker: View {
    let label: String
    @Binding var path: String
    let onChanged: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            if !path.isEmpty {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button {
                    path = ""
                    onChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text(L10n.tr("general.lidSound.default"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Button(L10n.tr("sounds.browse")) {
                chooseSoundFile()
            }
            .controlSize(.small)
        }
    }

    private func chooseSoundFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.mp3, .audio]
        panel.message = L10n.tr("general.lidSound.chooseDesc")
        if panel.runModal() == .OK, let url = panel.url {
            // Store bookmark for sandbox access
            if let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "lidSound_\(label)")
            }
            path = url.path
            onChanged()
        }
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section(L10n.tr("sounds.voicePack")) {
                Picker(L10n.tr("sounds.activePack"), selection: $appState.settings.soundMode) {
                    ForEach(SoundMode.allCases.filter { $0 != .lid }) { mode in
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
                    LabeledContent(L10n.tr("sounds.clipsLoaded")) {
                        Text("\(pack.count)")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Button(L10n.tr("sounds.testSound")) {
                    appState.playTestSound()
                }
            }

            if appState.settings.soundMode == .custom {
                Section(L10n.tr("sounds.customSounds")) {
                    HStack {
                        TextField(L10n.tr("sounds.folderPath"), text: $appState.settings.customSoundPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        Button(L10n.tr("sounds.browse")) {
                            chooseFolder()
                        }
                    }
                    Text(L10n.tr("sounds.browseDesc"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(L10n.tr("sounds.included")) {
                ForEach(SoundMode.allCases.filter { $0 != .custom && $0 != .lid }) { mode in
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
        panel.message = L10n.tr("sounds.browseDesc")
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

    private var clipCount: Int { SoundPack.bundled(mode).count }

    var body: some View {
        HStack {
            Image(systemName: mode.icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName).font(.headline)
                Text(mode.description)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(L10n.tr("voicepack.clips", clipCount))
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
            Section(L10n.tr("stats.session")) {
                LabeledContent(L10n.tr("stats.sessionSlaps")) {
                    Text("\(s.sessionSlaps)").font(.system(.body, design: .monospaced))
                }
                LabeledContent(L10n.tr("stats.slapsPerMin")) {
                    Text(String(format: "%.1f", s.slapsPerMinute)).font(.system(.body, design: .monospaced))
                }
                LabeledContent(L10n.tr("stats.duration")) {
                    Text(formatDuration(s.sessionDuration)).font(.system(.body, design: .monospaced))
                }
                Button(L10n.tr("stats.resetSession")) {
                    appState.history.resetSession()
                }
            }

            Section(L10n.tr("stats.allTime")) {
                LabeledContent(L10n.tr("stats.totalRecorded")) {
                    Text("\(s.totalSlaps)").font(.system(.body, design: .monospaced)).fontWeight(.bold)
                }
                LabeledContent(L10n.tr("stats.lifetimeCounter")) {
                    Text("\(appState.settings.lifetimeSlaps)")
                        .font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundStyle(.orange)
                }
                LabeledContent(L10n.tr("stats.avgAmplitude")) {
                    Text(String(format: "%.4fg", s.avgAmplitude)).font(.system(.body, design: .monospaced))
                }
                LabeledContent(L10n.tr("stats.maxAmplitude")) {
                    Text(String(format: "%.4fg", s.maxAmplitude)).font(.system(.body, design: .monospaced)).foregroundStyle(.red)
                }
                LabeledContent(L10n.tr("stats.majorImpacts")) {
                    Text("\(s.majorCount)").font(.system(.body, design: .monospaced))
                }
                LabeledContent(L10n.tr("stats.mediumImpacts")) {
                    Text("\(s.mediumCount)").font(.system(.body, design: .monospaced))
                }
                LabeledContent(L10n.tr("stats.favoriteMode")) {
                    Text(s.favoriteMode.capitalized)
                }
            }

            Section(L10n.tr("stats.recentHistory")) {
                if appState.history.recentRecords(10).isEmpty {
                    Text(L10n.tr("stats.noSlaps")).foregroundStyle(.secondary).font(.callout)
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
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button(L10n.tr("stats.exportCSV")) { exportCSV() }
                    Button(L10n.tr("stats.exportFull")) { exportFullCSV() }
                    Spacer()
                    Button(L10n.tr("stats.clearHistory"), role: .destructive) {
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
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    private func exportCSV() {
        let csv = appState.history.exportCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slap-history.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportFullCSV() {
        let csv = appState.history.exportFullCSV(leaderboard: appState.leaderboard, lifetimeSlaps: appState.settings.lifetimeSlaps)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slap-full-export.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
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
            Section(L10n.tr("sensors.accelerometer")) {
                LabeledContent(L10n.tr("sensors.status")) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isListening ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(appState.isListening ? L10n.tr("sensors.active") : L10n.tr("sensors.inactive"))
                    }
                }

                if appState.isListening {
                    LabeledContent(L10n.tr("sensors.reading")) {
                        Text(appState.lastSampleDebug)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let error = appState.errorMessage {
                    LabeledContent(L10n.tr("sensors.error")) {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }

                Text(L10n.tr("sensors.accelDesc", appState.settings.sampleRateHz))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("sensors.lidSensor")) {
                LabeledContent(L10n.tr("sensors.available")) {
                    Text(appState.lidAngle.isAvailable ? L10n.tr("sensors.yes") : L10n.tr("sensors.no"))
                }
                if appState.lidAngle.isAvailable {
                    LabeledContent(L10n.tr("sensors.angle")) {
                        Text("\(Int(appState.lidAngle.angle))°").font(.system(.body, design: .monospaced))
                    }
                    LabeledContent(L10n.tr("sensors.velocity")) {
                        Text(String(format: "%.1f °/s", appState.lidAngle.velocity)).font(.system(.body, design: .monospaced))
                    }
                }
                Text(L10n.tr("sensors.lidDesc"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("sensors.algorithm")) {
                Text(L10n.tr("sensors.algorithmDesc")).font(.caption)
                Text(L10n.tr("sensors.classificationDesc"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("sensors.permissionTitle")) {
                Text(L10n.tr("sensors.permissionDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Leaderboard Tab

private struct LeaderboardTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section(L10n.tr("leaderboard.topSlaps")) {
                if appState.leaderboard.topSlaps.isEmpty {
                    Text(L10n.tr("leaderboard.noSlaps")).foregroundStyle(.secondary).font(.callout)
                } else {
                    ForEach(Array(appState.leaderboard.topSlaps.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            Text("#\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(index == 0 ? .yellow : index < 3 ? .orange : .secondary)
                                .frame(width: 28, alignment: .trailing)
                            if index == 0 {
                                Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                            }
                            Text(String(format: "%.4fg", entry.amplitude))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(index == 0 ? .bold : .regular)
                            Text(entry.severity.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(entry.severity == "major" ? .red : .orange)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(entry.severity == "major" ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                            Spacer()
                            Text(entry.timestamp, style: .date).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section(L10n.tr("leaderboard.bestSessions")) {
                if appState.leaderboard.topSessions.isEmpty {
                    Text(L10n.tr("leaderboard.noSessions")).foregroundStyle(.secondary).font(.callout)
                } else {
                    ForEach(Array(appState.leaderboard.topSessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(index == 0 ? .yellow : .secondary)
                                .frame(width: 28, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("leaderboard.slaps", session.slapCount))
                                    .font(.system(.body, design: .monospaced)).fontWeight(.semibold)
                                HStack(spacing: 8) {
                                    Text(String(format: "%.1f/min", session.slapsPerMinute))
                                    Text("·")
                                    Text(String(format: "max %.3fg", session.maxAmplitude))
                                    Text("·")
                                    Text(formatDuration(session.durationSeconds))
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(session.date, style: .date).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section(L10n.tr("leaderboard.achievements", appState.leaderboard.unlockedAchievements.count, Leaderboard.allAchievements.count)) {
                let cols = [GridItem(.adaptive(minimum: 140))]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(appState.leaderboard.achievements) { achievement in
                        HStack(spacing: 6) {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(achievement.isUnlocked ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(achievement.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(achievement.isUnlocked ? .primary : .tertiary)
                                Text(achievement.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(achievement.isUnlocked ? .secondary : .quaternary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(achievement.isUnlocked ? Color.orange.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Section {
                Button(L10n.tr("leaderboard.copyClipboard")) {
                    let text = appState.leaderboard.shareText(lifetimeSlaps: appState.settings.lifetimeSlaps)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}

// MARK: - Profiles Tab (NEW)

private struct ProfilesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var newProfileName = ""
    @State private var showingSaveField = false

    var body: some View {
        Form {
            Section(L10n.tr("profiles.title")) {
                Text(L10n.tr("profiles.desc"))
                    .font(.caption).foregroundStyle(.secondary)

                if appState.profileManager.profiles.isEmpty {
                    Text(L10n.tr("profiles.noProfiles")).foregroundStyle(.secondary).font(.callout)
                } else {
                    ForEach(appState.profileManager.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.headline)
                                HStack(spacing: 8) {
                                    Text("\(L10n.tr("profiles.pack")): \(profile.soundMode)")
                                    Text("·")
                                    Text("\(L10n.tr("profiles.sensitivity")): \(String(format: "%.3f", profile.sensitivity))")
                                    Text("·")
                                    Text("\(L10n.tr("profiles.volume")): \(Int(profile.masterVolume * 100))%")
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(L10n.tr("profiles.load")) {
                                appState.loadProfile(profile)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button(L10n.tr("profiles.delete"), role: .destructive) {
                                appState.profileManager.delete(id: profile.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section {
                if showingSaveField {
                    HStack {
                        TextField(L10n.tr("profiles.name"), text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                        Button("OK") {
                            if !newProfileName.isEmpty {
                                appState.saveCurrentAsProfile(name: newProfileName)
                                newProfileName = ""
                                showingSaveField = false
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button(L10n.tr("profiles.save")) {
                        showingSaveField = true
                    }
                }

                HStack(spacing: 8) {
                    Text(L10n.tr("profiles.active"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(appState.settings.soundMode.displayName) · \(String(format: "%.3fg", appState.settings.sensitivity)) · \(Int(appState.settings.masterVolume * 100))%")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
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
            Text(L10n.tr("roadmap.title"))
                .font(.title2).fontWeight(.bold)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)

            List {
                RoadmapItem(version: "v1.0", titleKey: "roadmap.v10.title", descKey: "roadmap.v10.desc", status: .shipped)
                RoadmapItem(version: "v1.1", titleKey: "roadmap.v11.title", descKey: "roadmap.v11.desc", status: .shipped)
                RoadmapItem(version: "v1.2", titleKey: "roadmap.v12.title", descKey: "roadmap.v12.desc", status: .shipped)
                RoadmapItem(version: "v1.3", titleKey: "roadmap.v13.title", descKey: "roadmap.v13.desc", status: .shipped)
                RoadmapItem(version: "v1.4", titleKey: "roadmap.v14.title", descKey: "roadmap.v14.desc", status: .shipped)
                RoadmapItem(version: "v1.5", titleKey: "roadmap.v15.title", descKey: "roadmap.v15.desc", status: .shipped)
                RoadmapItem(version: "v1.6", titleKey: "roadmap.v16.title", descKey: "roadmap.v16.desc", status: .shipped)
                RoadmapItem(version: "v2.0", titleKey: "roadmap.v20.title", descKey: "roadmap.v20.desc", status: .planned)
            }
            .listStyle(.plain)
        }
    }
}

private enum RoadmapStatus {
    case shipped, inProgress, planned

    var label: String {
        switch self {
        case .shipped: return L10n.tr("roadmap.shipped")
        case .inProgress: return L10n.tr("roadmap.inProgress")
        case .planned: return L10n.tr("roadmap.planned")
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
    let titleKey: String
    let descKey: String
    let status: RoadmapStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(version)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(status == .shipped ? Color.green : Color.secondary.opacity(0.3))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(L10n.tr(titleKey)).font(.headline)
                    Spacer()
                    Text(status.label).font(.caption).foregroundStyle(status.color)
                }
                Text(L10n.tr(descKey))
                    .font(.caption).foregroundStyle(.secondary)
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
                .font(.system(size: 48)).foregroundStyle(.orange)

            Text(L10n.tr("app.name"))
                .font(.system(size: 24, weight: .black, design: .rounded))

            Text(L10n.tr("app.tagline"))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(L10n.tr("about.lifetimeSlaps")).foregroundStyle(.secondary)
                Text("\(appState.settings.lifetimeSlaps)")
                    .font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundStyle(.orange)
            }

            Divider().frame(width: 200)

            VStack(spacing: 4) {
                Text(L10n.tr("about.basedOn")).font(.caption).foregroundStyle(.tertiary)
                HStack(spacing: 16) {
                    Link("spank by taigrr", destination: URL(string: "https://github.com/taigrr/spank")!)
                        .font(.caption)
                    Link("LidAngleSensor by samhenrigold", destination: URL(string: "https://github.com/samhenrigold/LidAngleSensor")!)
                        .font(.caption)
                }
            }

            Divider().frame(width: 200)

            VStack(spacing: 4) {
                Text(L10n.tr("about.soundAttrib")).font(.caption).foregroundStyle(.tertiary)
                Text(L10n.tr("about.soundCredits"))
                    .font(.caption2).foregroundStyle(.quaternary)
            }

            Button(L10n.tr("about.checkUpdates")) {
                AppUpdater.shared.checkForUpdates()
            }
            .buttonStyle(.bordered).controlSize(.small)

            HStack(spacing: 12) {
                Button(L10n.tr("about.exportSettings")) { exportSettings() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button(L10n.tr("about.importSettings")) { importSettings() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button(L10n.tr("about.logs")) { showLogs() }
                    .buttonStyle(.bordered).controlSize(.small)
            }

            Text(L10n.tr("app.version"))
                .font(.caption2).foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func exportSettings() {
        guard let data = SettingsExporter.export(settings: appState.settings, profiles: appState.profileManager.profiles) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slapmymac-settings.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            _ = SettingsExporter.importData(data, into: appState.settings, profiles: appState.profileManager)
            appState.loadSoundPack()
            appState.applySensitivitySettings()
            appState.applyMasterVolume()
        }
    }

    private func showLogs() {
        let logs = AppLogger.shared.readLogs()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slapmymac.log"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? logs.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
