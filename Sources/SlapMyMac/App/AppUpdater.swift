import Foundation
import Sparkle

/// Singleton wrapper for the Sparkle auto-updater.
/// Requires SUFeedURL to be set in Info.plist to function.
/// Without it, Sparkle starts silently and checkForUpdates shows a "no appcast" error.
final class AppUpdater {
    static let shared = AppUpdater()

    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
