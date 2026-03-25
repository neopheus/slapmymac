import Foundation

enum SoundMode: String, CaseIterable, Identifiable, Codable {
    case pain
    case sexy
    case halo
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pain: return "Pain"
        case .sexy: return "Sexy"
        case .halo: return "Halo"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .pain: return "10 protest/pain reactions"
        case .sexy: return "60-level escalating intensity"
        case .halo: return "Halo game death sounds"
        case .custom: return "Your own MP3 files"
        }
    }

    /// Whether this mode uses escalation (score-based) rather than random selection.
    var isEscalating: Bool {
        self == .sexy
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

        let folderName = mode.displayName
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
