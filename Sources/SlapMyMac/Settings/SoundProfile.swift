import Foundation

struct SoundProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var soundMode: String  // SoundMode.rawValue
    var sensitivity: Double
    var cooldownMs: Int
    var masterVolume: Double
    var volumeScaling: Bool
    let createdAt: Date

    init(name: String, soundMode: String, sensitivity: Double, cooldownMs: Int, masterVolume: Double, volumeScaling: Bool) {
        self.id = UUID()
        self.name = name
        self.soundMode = soundMode
        self.sensitivity = sensitivity
        self.cooldownMs = cooldownMs
        self.masterVolume = masterVolume
        self.volumeScaling = volumeScaling
        self.createdAt = Date()
    }
}

@MainActor
final class ProfileManager: ObservableObject {
    @Published var profiles: [SoundProfile] = []

    private let storageKey = "soundProfiles"

    init() {
        load()
    }

    func save(profile: SoundProfile) {
        profiles.append(profile)
        persist()
    }

    func delete(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        persist()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SoundProfile].self, from: data) else { return }
        profiles = decoded
    }
}
