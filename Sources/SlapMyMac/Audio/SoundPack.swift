import Foundation

enum SoundMode: String, CaseIterable, Identifiable, Codable {
    case pain
    case sexy
    case halo
    case whip
    case cartoon
    case kungfu
    case drum
    case cat
    case glass
    case eightbit
    case thunder
    case wwe
    case metal
    case slap
    case mario
    case lid   // Internal: lid event sounds (not shown in picker)
    case custom

    var id: String { rawValue }

    var displayName: String {
        L10n.tr("sound.\(rawValue)")
    }

    var description: String {
        L10n.tr("sound.\(rawValue).desc")
    }

    /// System icon name for the mode.
    var icon: String {
        switch self {
        case .pain: return "face.dashed"
        case .sexy: return "heart.fill"
        case .halo: return "gamecontroller.fill"
        case .whip: return "wind"
        case .cartoon: return "sparkles"
        case .kungfu: return "figure.martial.arts"
        case .drum: return "drum.fill"
        case .cat: return "cat.fill"
        case .glass: return "light.cylindrical.ceiling"
        case .eightbit: return "arcade.stick"
        case .thunder: return "cloud.bolt.fill"
        case .wwe: return "figure.wrestling"
        case .metal: return "hammer.fill"
        case .slap: return "hand.raised.fill"
        case .mario: return "star.fill"
        case .lid: return "laptopcomputer"
        case .custom: return "folder.fill"
        }
    }

    /// Whether this mode uses escalation (score-based) rather than random selection.
    var isEscalating: Bool {
        switch self {
        case .sexy, .cat, .glass: return true
        default: return false
        }
    }

    /// Folder name inside Resources/Sounds/ (English, never localized).
    var folderName: String {
        switch self {
        case .pain: return "Pain"
        case .sexy: return "Sexy"
        case .halo: return "Halo"
        case .whip: return "Whip"
        case .cartoon: return "Cartoon"
        case .kungfu: return "KungFu"
        case .drum: return "Drum"
        case .cat: return "Cat"
        case .glass: return "Glass"
        case .eightbit: return "8Bit"
        case .thunder: return "Thunder"
        case .wwe: return "WWE"
        case .metal: return "Metal"
        case .slap: return "Slap"
        case .mario: return "Mario"
        case .lid: return "Lid"
        case .custom: return "Custom"
        }
    }
}

struct SoundPack {
    let mode: SoundMode
    let urls: [URL]

    var count: Int { urls.count }
    var isEmpty: Bool { urls.isEmpty }

    /// Load bundled sounds for the given mode.
    static func bundled(_ mode: SoundMode) -> SoundPack {
        guard mode != .custom else {
            return SoundPack(mode: .custom, urls: [])
        }

        let folderName = mode.folderName
        guard let resourceURL = Bundle.main.url(forResource: "Sounds/\(folderName)", withExtension: nil) else {
            // Try alternate resource path for SPM bundle
            if let altURL = Bundle.main.resourceURL?.appendingPathComponent("Sounds/\(folderName)") {
                return SoundPack(mode: mode, urls: loadMP3s(from: altURL))
            }
            return SoundPack(mode: mode, urls: [])
        }

        return SoundPack(mode: mode, urls: loadMP3s(from: resourceURL))
    }

    /// Load custom sounds from a user-specified directory.
    static func custom(from directory: URL) -> SoundPack {
        SoundPack(mode: .custom, urls: loadMP3s(from: directory))
    }

    private static func loadMP3s(from directory: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
