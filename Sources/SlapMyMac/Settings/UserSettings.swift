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

    var customSoundURL: URL? {
        guard !customSoundPath.isEmpty else { return nil }
        return URL(fileURLWithPath: customSoundPath)
    }
}

// Extend SoundMode for @AppStorage conformance
extension SoundMode: RawRepresentable {
    // Already RawRepresentable via String enum
}
