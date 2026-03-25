import SwiftUI

final class UserSettings: ObservableObject {
    @AppStorage("soundMode") var soundMode: SoundMode = .pain
    @AppStorage("sensitivity") var sensitivity: Double = Constants.defaultSensitivity
    @AppStorage("cooldownMs") var cooldownMs: Int = Constants.defaultCooldownMs
    @AppStorage("volumeScaling") var volumeScaling: Bool = true
    @AppStorage("customSoundPath") var customSoundPath: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }
    @AppStorage("lifetimeSlaps") var lifetimeSlaps: Int = 0
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("lidSoundsEnabled") var lidSoundsEnabled: Bool = true
    @AppStorage("lidAudioMode") var lidAudioMode: LidAudioMode = .creak
    @AppStorage("mcpServerEnabled") var mcpServerEnabled: Bool = true
    @AppStorage("showSlapCountInMenuBar") var showSlapCountInMenuBar: Bool = true

    var customSoundURL: URL? {
        guard !customSoundPath.isEmpty else { return nil }
        return URL(fileURLWithPath: customSoundPath)
    }

    /// Human-readable sensitivity label
    var sensitivityLabel: String {
        switch sensitivity {
        case ..<0.02: return "Earthquake detector"
        case ..<0.05: return "Feather touch"
        case ..<0.10: return "Light tap"
        case ..<0.20: return "Normal slap"
        case ..<0.35: return "Strong hit"
        default:      return "Needs a running start"
        }
    }
}
