import Foundation

struct SettingsExporter {
    struct ExportData: Codable {
        let version: Int
        let exportDate: Date
        let settings: SettingsSnapshot
        let profiles: [SoundProfile]
        let topSlaps: Data?      // Encoded LeaderboardEntry array
        let topSessions: Data?   // Encoded SessionRecord array
        let achievements: [String]
    }

    struct SettingsSnapshot: Codable {
        let soundMode: String
        let sensitivity: Double
        let cooldownMs: Int
        let volumeScaling: Bool
        let masterVolume: Double
        let respectFocus: Bool
        let lidEventSoundsEnabled: Bool
        let notificationsEnabled: Bool
        let decimationFactor: Int
        let suppressionSamples: Int
        let kurtosisEvalInterval: Int
        let lidSoundsEnabled: Bool
        let lidAudioMode: String
        let lidPollHz: Double
        let angleSmoothingTau: Double
        let velocitySmoothingTau: Double
        let lidEventCooldown: Double
        let mcpServerEnabled: Bool
        let showSlapCountInMenuBar: Bool
        let startupSoundEnabled: Bool
        let appLanguage: String
    }

    static func export(settings: UserSettings, profiles: [SoundProfile]) -> Data? {
        let snapshot = SettingsSnapshot(
            soundMode: settings.soundMode.rawValue,
            sensitivity: settings.sensitivity,
            cooldownMs: settings.cooldownMs,
            volumeScaling: settings.volumeScaling,
            masterVolume: settings.masterVolume,
            respectFocus: settings.respectFocus,
            lidEventSoundsEnabled: settings.lidEventSoundsEnabled,
            notificationsEnabled: settings.notificationsEnabled,
            decimationFactor: settings.decimationFactor,
            suppressionSamples: settings.suppressionSamples,
            kurtosisEvalInterval: settings.kurtosisEvalInterval,
            lidSoundsEnabled: settings.lidSoundsEnabled,
            lidAudioMode: settings.lidAudioMode.rawValue,
            lidPollHz: settings.lidPollHz,
            angleSmoothingTau: settings.angleSmoothingTau,
            velocitySmoothingTau: settings.velocitySmoothingTau,
            lidEventCooldown: settings.lidEventCooldown,
            mcpServerEnabled: settings.mcpServerEnabled,
            showSlapCountInMenuBar: settings.showSlapCountInMenuBar,
            startupSoundEnabled: settings.startupSoundEnabled,
            appLanguage: UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        )

        let exportData = ExportData(
            version: 1,
            exportDate: Date(),
            settings: snapshot,
            profiles: profiles,
            topSlaps: UserDefaults.standard.data(forKey: "leaderboard_topSlaps"),
            topSessions: UserDefaults.standard.data(forKey: "leaderboard_topSessions"),
            achievements: UserDefaults.standard.array(forKey: "leaderboard_achievements") as? [String] ?? []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportData)
    }

    @MainActor static func importData(_ data: Data, into settings: UserSettings, profiles: ProfileManager) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let exportData = try? decoder.decode(ExportData.self, from: data) else { return false }

        let s = exportData.settings

        // Apply settings
        if let mode = SoundMode(rawValue: s.soundMode) {
            settings.soundMode = mode
        }
        settings.sensitivity = s.sensitivity
        settings.cooldownMs = s.cooldownMs
        settings.volumeScaling = s.volumeScaling
        settings.masterVolume = s.masterVolume
        settings.respectFocus = s.respectFocus
        settings.lidEventSoundsEnabled = s.lidEventSoundsEnabled
        settings.notificationsEnabled = s.notificationsEnabled
        settings.decimationFactor = s.decimationFactor
        settings.suppressionSamples = s.suppressionSamples
        settings.kurtosisEvalInterval = s.kurtosisEvalInterval
        settings.lidSoundsEnabled = s.lidSoundsEnabled
        if let mode = LidAudioMode(rawValue: s.lidAudioMode) {
            settings.lidAudioMode = mode
        }
        settings.lidPollHz = s.lidPollHz
        settings.angleSmoothingTau = s.angleSmoothingTau
        settings.velocitySmoothingTau = s.velocitySmoothingTau
        settings.lidEventCooldown = s.lidEventCooldown
        settings.mcpServerEnabled = s.mcpServerEnabled
        settings.showSlapCountInMenuBar = s.showSlapCountInMenuBar
        settings.startupSoundEnabled = s.startupSoundEnabled
        UserDefaults.standard.set(s.appLanguage, forKey: "appLanguage")

        // Import profiles
        for profile in exportData.profiles {
            profiles.save(profile: profile)
        }

        // Import leaderboard data
        if let data = exportData.topSlaps {
            UserDefaults.standard.set(data, forKey: "leaderboard_topSlaps")
        }
        if let data = exportData.topSessions {
            UserDefaults.standard.set(data, forKey: "leaderboard_topSessions")
        }
        if !exportData.achievements.isEmpty {
            UserDefaults.standard.set(exportData.achievements, forKey: "leaderboard_achievements")
        }

        return true
    }
}
