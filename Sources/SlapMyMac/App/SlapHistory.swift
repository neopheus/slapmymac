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

    /// Export all records as CSV.
    func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        var csv = "timestamp,amplitude,severity,detectorCount,soundMode\n"
        for r in records {
            csv += "\(formatter.string(from: r.timestamp)),\(r.amplitude),\(r.severity),\(r.detectorCount),\(r.soundMode)\n"
        }
        return csv
    }

    /// Export history + leaderboard data as a comprehensive CSV.
    func exportFullCSV(leaderboard: Leaderboard, lifetimeSlaps: Int) -> String {
        var csv = exportCSV()

        // Add leaderboard section
        csv += "\n# Top Slaps\n"
        csv += "rank,amplitude,severity,detectorCount,date\n"
        for (i, entry) in leaderboard.topSlaps.enumerated() {
            let formatter = ISO8601DateFormatter()
            csv += "\(i+1),\(entry.amplitude),\(entry.severity),\(entry.detectorCount),\(formatter.string(from: entry.timestamp))\n"
        }

        // Add achievements section
        csv += "\n# Achievements\n"
        csv += "id,title,unlocked\n"
        for achievement in Leaderboard.allAchievements {
            let unlocked = leaderboard.unlockedAchievements.contains(achievement.id)
            csv += "\(achievement.id),\(achievement.title),\(unlocked)\n"
        }

        csv += "\n# Summary\n"
        csv += "lifetime_slaps,\(lifetimeSlaps)\n"
        csv += "achievements_unlocked,\(leaderboard.unlockedAchievements.count)/\(Leaderboard.allAchievements.count)\n"

        return csv
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
