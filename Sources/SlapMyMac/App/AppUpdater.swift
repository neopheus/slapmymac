import AppKit
import Foundation
import Sparkle

/// Singleton wrapper for the Sparkle auto-updater.
/// Only starts Sparkle when the app is properly code-signed (Developer ID).
/// Falls back to opening GitHub Releases for ad-hoc signed builds.
final class AppUpdater {
    static let shared = AppUpdater()

    private var updaterController: SPUStandardUpdaterController?

    /// Whether Sparkle is available (app is properly signed with Developer ID)
    var isSparkleAvailable: Bool { updaterController != nil }

    private init() {
        // Only start Sparkle if the app has a real code signature (not ad-hoc)
        if Self.hasValidCodeSignature() {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            print("[SlapMyMac] Ad-hoc signature detected — Sparkle disabled, using GitHub Releases fallback")
        }
    }

    func checkForUpdates() {
        if let controller = updaterController {
            controller.updater.checkForUpdates()
        } else {
            // Fallback: open GitHub releases page
            if let url = URL(string: "https://github.com/neopheus/slapmymac/releases") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? true
    }

    /// Check if the app has a valid Developer ID signature (not ad-hoc "-")
    private static func hasValidCodeSignature() -> Bool {
        guard let bundlePath = Bundle.main.executablePath else { return false }

        let task = Process()
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["-dv", bundlePath]
        let pipe = Pipe()
        task.standardError = pipe  // codesign outputs to stderr
        task.standardOutput = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Ad-hoc signatures show "Authority=(unavailable)" or no Authority field
        // Real signatures show "Authority=Developer ID Application: ..."
        return output.contains("Authority=Developer ID") || output.contains("Authority=Apple Development")
    }
}
