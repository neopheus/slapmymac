import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            SoundsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Sounds", systemImage: "speaker.wave.3")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $appState.settings.launchAtLogin)

            Divider()

            VStack(alignment: .leading) {
                Text("Sensitivity: \(String(format: "%.3f", appState.settings.sensitivity))g")
                Slider(value: $appState.settings.sensitivity, in: 0.005...0.50, step: 0.005)
                Text("Lower = more sensitive to light taps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
                Text("Cooldown: \(appState.settings.cooldownMs)ms")
                Slider(
                    value: Binding(
                        get: { Double(appState.settings.cooldownMs) },
                        set: { appState.settings.cooldownMs = Int($0) }
                    ),
                    in: 100...2000,
                    step: 50
                )
                Text("Minimum time between sound effects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Scale volume by impact force", isOn: $appState.settings.volumeScaling)
        }
        .padding()
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Picker("Sound Mode", selection: $appState.settings.soundMode) {
                ForEach(SoundMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: appState.settings.soundMode) {
                appState.loadSoundPack()
            }

            if appState.settings.soundMode == .custom {
                HStack {
                    TextField("Custom sounds folder", text: $appState.settings.customSoundPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button("Browse...") {
                        chooseFolder()
                    }
                }
            }

            if let pack = appState.currentPack {
                Text("\(pack.count) sounds loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Test Sound") {
                appState.playTestSound()
            }
        }
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing MP3 files"

        if panel.runModal() == .OK, let url = panel.url {
            // Store bookmark for persistent access
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

// MARK: - About Tab

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("SlapMyMac")
                .font(.title)
                .fontWeight(.bold)

            Text("Slap your Mac, it yells back.")
                .foregroundStyle(.secondary)

            Text("Based on spank by taigrr")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("github.com/taigrr/spank", destination: URL(string: "https://github.com/taigrr/spank")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
