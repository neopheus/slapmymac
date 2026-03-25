import Foundation

/// A single recorded slap event for history tracking.
struct SlapRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let amplitude: Double
    let severity: String
    let detectorCount: Int
    let soundMode: String

    init(event: ImpactEvent, mode: SoundMode) {
        self.id = UUID()
        self.timestamp = Date()
        self.amplitude = event.amplitude
        self.severity = event.severity.rawValue
        self.detectorCount = event.detectorCount
        self.soundMode = mode.rawValue
    }
}

/// Session stats computed from history.
struct SlapStats {
    let totalSlaps: Int
    let sessionSlaps: Int
    let avgAmplitude: Double
    let maxAmplitude: Double
    let majorCount: Int
    let mediumCount: Int
    let slapsPerMinute: Double
    let sessionDuration: TimeInterval
    let favoriteMode: String
}

/// Tracks slap history in memory and persists to disk.
@MainActor
final class SlapHistory: ObservableObject {
    @Published var records: [SlapRecord] = []
    @Published var sessionStart = Date()

    private let maxRecords = 500
    private let storageKey = "slapHistory"

    init() {
        load()
    }

    func record(_ event: ImpactEvent, mode: SoundMode) {
        let record = SlapRecord(event: event, mode: mode)
        records.append(record)

        // Trim old records
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }

        save()
    }

    var stats: SlapStats {
        let sessionRecords = records.filter { $0.timestamp >= sessionStart }
        let duration = Date().timeIntervalSince(sessionStart)
        let amplitudes = records.map(\.amplitude)

        // Count by severity
        let majorCount = records.filter { $0.severity == "major" }.count
        let mediumCount = records.filter { $0.severity == "medium" }.count

        // Find favorite mode
        var modeCounts: [String: Int] = [:]
        for r in records { modeCounts[r.soundMode, default: 0] += 1 }
        let favoriteMode = modeCounts.max(by: { $0.value < $1.value })?.key ?? "pain"

        return SlapStats(
            totalSlaps: records.count,
            sessionSlaps: sessionRecords.count,
            avgAmplitude: amplitudes.isEmpty ? 0 : amplitudes.reduce(0, +) / Double(amplitudes.count),
            maxAmplitude: amplitudes.max() ?? 0,
            majorCount: majorCount,
            mediumCount: mediumCount,
            slapsPerMinute: duration > 60 ? Double(sessionRecords.count) / (duration / 60) : Double(sessionRecords.count),
            sessionDuration: duration,
            favoriteMode: favoriteMode
        )
    }

    /// Last N records for display.
    func recentRecords(_ count: Int = 20) -> [SlapRecord] {
        Array(records.suffix(count).reversed())
    }

    func clearHistory() {
        records.removeAll()
        save()
    }

    func resetSession() {
        sessionStart = Date()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SlapRecord].self, from: data) else {
            return
        }
        records = decoded
    }
}
