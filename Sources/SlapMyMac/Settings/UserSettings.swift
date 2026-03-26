import SwiftUI

final class UserSettings: ObservableObject {
    @AppStorage("soundMode") var soundMode: SoundMode = .pain
    @AppStorage("sensitivity") var sensitivity: Double = Constants.defaultSensitivity
    @AppStorage("cooldownMs") var cooldownMs: Int = Constants.defaultCooldownMs
    @AppStorage("volumeScaling") var volumeScaling: Bool = true
    @AppStorage("masterVolume") var masterVolume: Double = 0.8
    @AppStorage("respectFocus") var respectFocus: Bool = true
    @AppStorage("lidEventSoundsEnabled") var lidEventSoundsEnabled: Bool = true
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("decimationFactor") var decimationFactor: Int = Constants.defaultDecimationFactor
    @AppStorage("suppressionSamples") var suppressionSamples: Int = Constants.defaultSuppressionSamples
    @AppStorage("kurtosisEvalInterval") var kurtosisEvalInterval: Int = Constants.defaultKurtosisEvalInterval
    @AppStorage("customSoundPath") var customSoundPath: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }
    @AppStorage("lifetimeSlaps") var lifetimeSlaps: Int = 0
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("lidSoundsEnabled") var lidSoundsEnabled: Bool = true
    @AppStorage("lidAudioMode") var lidAudioMode: LidAudioMode = .creak
    @AppStorage("lidPollHz") var lidPollHz: Double = Constants.defaultLidPollHz
    @AppStorage("angleSmoothingTau") var angleSmoothingTau: Double = Constants.defaultAngleSmoothingTau
    @AppStorage("velocitySmoothingTau") var velocitySmoothingTau: Double = Constants.defaultVelocitySmoothingTau
    @AppStorage("lidEventCooldown") var lidEventCooldown: Double = Constants.defaultLidEventCooldown
    @AppStorage("mcpServerEnabled") var mcpServerEnabled: Bool = true
    @AppStorage("showSlapCountInMenuBar") var showSlapCountInMenuBar: Bool = true
    @AppStorage("startupSoundEnabled") var startupSoundEnabled: Bool = false
    @AppStorage("customLidOpenPath") var customLidOpenPath: String = ""
    @AppStorage("customLidClosePath") var customLidClosePath: String = ""
    @AppStorage("customLidSlamPath") var customLidSlamPath: String = ""
    @AppStorage("hotKeyCode") var hotKeyCode: Int = 1  // Default: 'S' key
    @AppStorage("hotKeyModifiers") var hotKeyModifiers: Int = 0x0100 | 0x0200  // cmdKey | shiftKey

    /// Human-readable hotkey string
    var hotKeyLabel: String {
        var parts: [String] = []
        if hotKeyModifiers & 0x0100 != 0 { parts.append("⌘") }
        if hotKeyModifiers & 0x0200 != 0 { parts.append("⇧") }
        if hotKeyModifiers & 0x0800 != 0 { parts.append("⌥") }
        if hotKeyModifiers & 0x1000 != 0 { parts.append("⌃") }
        parts.append(KeyCodeMap.keyName(for: UInt16(hotKeyCode)))
        return parts.joined(separator: "")
    }

    var customSoundURL: URL? {
        guard !customSoundPath.isEmpty else { return nil }
        return URL(fileURLWithPath: customSoundPath)
    }

    /// Effective sample rate based on decimation factor
    var sampleRateHz: Int {
        800 / max(1, decimationFactor)
    }

    var sampleRateLabel: String {
        "\(sampleRateHz) Hz"
    }

    /// Suppression duration in ms (based on current sample rate)
    var suppressionMs: Int {
        let rate = Double(sampleRateHz)
        return Int(Double(suppressionSamples) / rate * 1000)
    }

    /// Human-readable sensitivity label
    var sensitivityLabel: String {
        switch sensitivity {
        case ..<0.02: return L10n.tr("general.sensitivity.earthquake")
        case ..<0.05: return L10n.tr("general.sensitivity.feather")
        case ..<0.10: return L10n.tr("general.sensitivity.light")
        case ..<0.20: return L10n.tr("general.sensitivity.normal")
        case ..<0.35: return L10n.tr("general.sensitivity.strong")
        default:      return L10n.tr("general.sensitivity.running")
        }
    }
}
