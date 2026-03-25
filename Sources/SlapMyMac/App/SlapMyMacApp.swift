import SwiftUI

@main
struct SlapMyMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("SlapMyMac", systemImage: appState.isListening ? "hand.raised.fill" : "hand.raised.slash")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
