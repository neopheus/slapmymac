import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status
            HStack {
                Circle()
                    .fill(appState.isListening ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.isListening ? "Listening" : "Paused")
                    .font(.headline)
                Spacer()
                Text("\(appState.slapCount) slaps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Toggle listening
            Button(appState.isListening ? "Pause" : "Resume") {
                appState.toggleListening()
            }
            .keyboardShortcut("p")

            Divider()

            // Sound mode picker
            Text("Sound Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(SoundMode.allCases) { mode in
                Button {
                    appState.settings.soundMode = mode
                    appState.loadSoundPack()
                } label: {
                    HStack {
                        if appState.settings.soundMode == mode {
                            Image(systemName: "checkmark")
                        }
                        Text(mode.displayName)
                        Spacer()
                        Text(mode.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Sensitivity
            Text("Sensitivity: \(String(format: "%.2f", appState.settings.sensitivity))g")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Divider()

            // Preferences
            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit SlapMyMac") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
        .frame(width: 280)
    }
}
