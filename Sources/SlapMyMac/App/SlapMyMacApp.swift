import SwiftUI

@main
struct SlapMyMacApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = false

    init() {
        // Start the Sparkle auto-updater
        _ = AppUpdater.shared

        // Force accent color at app level so Settings window
        // has it immediately on first open (not just after refocus)
        NSApplication.shared.appearance = NSApplication.shared.effectiveAppearance
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    // Show onboarding on first launch
                    if !appState.settings.hasCompletedOnboarding {
                        showOnboarding = true
                        openOnboardingWindow()
                    }
                }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: appState.slapFlash ? "burst.fill" :
                    (appState.isListening ? "hand.raised.fill" : "hand.raised.slash"))
                if appState.settings.showSlapCountInMenuBar && appState.slapCount > 0 {
                    Text("\(appState.slapCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(appState)
                .tint(Theme.accent)
                .onAppear {
                    // Force app activation so the Settings window gets focus immediately.
                    // Without this, LSUIElement menu bar apps open Settings behind / unfocused.
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }

    private func openOnboardingWindow() {
        let onboardingView = OnboardingView()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to SlapMyMac"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 440, height: 460))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
