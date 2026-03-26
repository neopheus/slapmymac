import Foundation

/// A personal best record entry.
struct LeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let amplitude: Double
    let severity: String
    let detectorCount: Int
    let soundMode: String

    init(record: SlapRecord) {
        self.id = record.id
        self.timestamp = record.timestamp
        self.amplitude = record.amplitude
        self.severity = record.severity
        self.detectorCount = record.detectorCount
        self.soundMode = record.soundMode
    }
}

/// A completed session snapshot.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let slapCount: Int
    let maxAmplitude: Double
    let avgAmplitude: Double
    let durationSeconds: TimeInterval
    let slapsPerMinute: Double
    let majorCount: Int
}

/// Achievement badge definition.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let threshold: Int  // Value needed to unlock

    var isUnlocked: Bool = false
    var unlockedDate: Date?
}

/// Persistent personal leaderboard — top slaps, sessions, achievements.
@MainActor
final class Leaderboard: ObservableObject {
    @Published var topSlaps: [LeaderboardEntry] = []
    @Published var topSessions: [SessionRecord] = []
    @Published var unlockedAchievements: Set<String> = []

    private let maxTopSlaps = 10
    private let maxTopSessions = 10
    private let topSlapsKey = "leaderboard_topSlaps"
    private let topSessionsKey = "leaderboard_topSessions"
    private let achievementsKey = "leaderboard_achievements"

    var onAchievementUnlocked: ((Achievement) -> Void)?

    init() {
        load()
    }

    // MARK: - Top Slaps

    /// Submit a slap record. Returns true if it made the top 10.
    @discardableResult
    func submitSlap(_ record: SlapRecord) -> Bool {
        let entry = LeaderboardEntry(record: record)

        // Check if it qualifies for top 10
        if topSlaps.count < maxTopSlaps || entry.amplitude > (topSlaps.last?.amplitude ?? 0) {
            topSlaps.append(entry)
            topSlaps.sort { $0.amplitude > $1.amplitude }
            if topSlaps.count > maxTopSlaps {
                topSlaps.removeLast()
            }
            save()
            return true
        }
        return false
    }

    /// Minimum amplitude to make the leaderboard (0 if not full yet).
    var topSlapsThreshold: Double {
        topSlaps.count < maxTopSlaps ? 0 : (topSlaps.last?.amplitude ?? 0)
    }

    // MARK: - Session Records

    func submitSession(slapCount: Int, maxAmplitude: Double, avgAmplitude: Double,
                       duration: TimeInterval, slapsPerMinute: Double, majorCount: Int) {
        guard slapCount > 0 else { return }

        let session = SessionRecord(
            id: UUID(),
            date: Date(),
            slapCount: slapCount,
            maxAmplitude: maxAmplitude,
            avgAmplitude: avgAmplitude,
            durationSeconds: duration,
            slapsPerMinute: slapsPerMinute,
            majorCount: majorCount
        )

        topSessions.append(session)
        topSessions.sort { $0.slapCount > $1.slapCount }
        if topSessions.count > maxTopSessions {
            topSessions.removeLast()
        }
        save()
    }

    // MARK: - Achievements

    static var allAchievements: [Achievement] {
        [
            Achievement(id: "first_slap", title: L10n.tr("achievement.firstSlap"), description: L10n.tr("achievement.firstSlap.desc"), icon: "hand.wave.fill", threshold: 1),
            Achievement(id: "slaps_10", title: L10n.tr("achievement.slaps10"), description: L10n.tr("achievement.slaps10.desc"), icon: "flame.fill", threshold: 10),
            Achievement(id: "slaps_50", title: L10n.tr("achievement.slaps50"), description: L10n.tr("achievement.slaps50.desc"), icon: "flame.fill", threshold: 50),
            Achievement(id: "slaps_100", title: L10n.tr("achievement.slaps100"), description: L10n.tr("achievement.slaps100.desc"), icon: "star.fill", threshold: 100),
            Achievement(id: "slaps_500", title: L10n.tr("achievement.slaps500"), description: L10n.tr("achievement.slaps500.desc"), icon: "star.circle.fill", threshold: 500),
            Achievement(id: "slaps_1000", title: L10n.tr("achievement.slaps1000"), description: L10n.tr("achievement.slaps1000.desc"), icon: "crown.fill", threshold: 1000),
            Achievement(id: "slaps_5000", title: L10n.tr("achievement.slaps5000"), description: L10n.tr("achievement.slaps5000.desc"), icon: "trophy.fill", threshold: 5000),
            Achievement(id: "amp_01", title: L10n.tr("achievement.amp01"), description: L10n.tr("achievement.amp01.desc"), icon: "bolt.fill", threshold: 0),
            Achievement(id: "amp_03", title: L10n.tr("achievement.amp03"), description: L10n.tr("achievement.amp03.desc"), icon: "bolt.circle.fill", threshold: 0),
            Achievement(id: "amp_05", title: L10n.tr("achievement.amp05"), description: L10n.tr("achievement.amp05.desc"), icon: "waveform.path.ecg", threshold: 0),
            Achievement(id: "amp_08", title: L10n.tr("achievement.amp08"), description: L10n.tr("achievement.amp08.desc"), icon: "bolt.shield.fill", threshold: 0),
            Achievement(id: "all_major", title: L10n.tr("achievement.allMajor"), description: L10n.tr("achievement.allMajor.desc"), icon: "sparkles", threshold: 4),
            Achievement(id: "rate_10", title: L10n.tr("achievement.rate10"), description: L10n.tr("achievement.rate10.desc"), icon: "hare.fill", threshold: 10),
            Achievement(id: "session_30", title: L10n.tr("achievement.session30"), description: L10n.tr("achievement.session30.desc"), icon: "figure.run", threshold: 30),
            Achievement(id: "session_100", title: L10n.tr("achievement.session100"), description: L10n.tr("achievement.session100.desc"), icon: "medal.fill", threshold: 100),
        ]
    }

    /// Check and unlock achievements based on current state.
    func checkAchievements(lifetimeSlaps: Int, event: ImpactEvent?, sessionSlaps: Int, slapsPerMinute: Double) {
        var changed = false
        var newlyUnlocked: [String] = []

        // Lifetime milestones
        let slapMilestones: [(String, Int)] = [
            ("first_slap", 1), ("slaps_10", 10), ("slaps_50", 50),
            ("slaps_100", 100), ("slaps_500", 500), ("slaps_1000", 1000), ("slaps_5000", 5000)
        ]
        for (id, threshold) in slapMilestones {
            if lifetimeSlaps >= threshold && !unlockedAchievements.contains(id) {
                unlockedAchievements.insert(id)
                newlyUnlocked.append(id)
                changed = true
            }
        }

        // Amplitude milestones
        if let amp = event?.amplitude {
            let ampMilestones: [(String, Double)] = [
                ("amp_01", 0.1), ("amp_03", 0.3), ("amp_05", 0.5), ("amp_08", 0.8)
            ]
            for (id, threshold) in ampMilestones {
                if amp >= threshold && !unlockedAchievements.contains(id) {
                    unlockedAchievements.insert(id)
                    newlyUnlocked.append(id)
                    changed = true
                }
            }

            // All 4 detectors
            if let count = event?.detectorCount, count >= 4 && !unlockedAchievements.contains("all_major") {
                unlockedAchievements.insert("all_major")
                newlyUnlocked.append("all_major")
                changed = true
            }
        }

        // Rate
        if slapsPerMinute >= 10 && !unlockedAchievements.contains("rate_10") {
            unlockedAchievements.insert("rate_10")
            newlyUnlocked.append("rate_10")
            changed = true
        }

        // Session
        let sessionMilestones: [(String, Int)] = [("session_30", 30), ("session_100", 100)]
        for (id, threshold) in sessionMilestones {
            if sessionSlaps >= threshold && !unlockedAchievements.contains(id) {
                unlockedAchievements.insert(id)
                newlyUnlocked.append(id)
                changed = true
            }
        }

        if changed {
            save()
            if let callback = onAchievementUnlocked {
                let allDefs = Self.allAchievements
                for id in newlyUnlocked {
                    if let def = allDefs.first(where: { $0.id == id }) {
                        callback(def)
                    }
                }
            }
        }
    }

    /// Get all achievements with their unlock status.
    var achievements: [Achievement] {
        Self.allAchievements.map { a in
            var achievement = a
            achievement.isUnlocked = unlockedAchievements.contains(a.id)
            return achievement
        }
    }

    /// Generate a shareable text summary.
    func shareText(lifetimeSlaps: Int) -> String {
        let best = topSlaps.first
        let bestAmp = best.map { String(format: "%.3fg", $0.amplitude) } ?? "—"
        let unlocked = unlockedAchievements.count
        let total = Self.allAchievements.count
        return """
        🖐 \(L10n.tr("share.title"))
        \(L10n.tr("share.lifetime", lifetimeSlaps))
        \(L10n.tr("share.hardest", bestAmp))
        \(L10n.tr("share.achievements", unlocked, total))
        \(L10n.tr("share.top3", topSlaps.prefix(3).map { String(format: "%.3fg", $0.amplitude) }.joined(separator: " · ")))
        """
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(topSlaps) {
            UserDefaults.standard.set(data, forKey: topSlapsKey)
        }
        if let data = try? JSONEncoder().encode(topSessions) {
            UserDefaults.standard.set(data, forKey: topSessionsKey)
        }
        UserDefaults.standard.set(Array(unlockedAchievements), forKey: achievementsKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: topSlapsKey),
           let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
            topSlaps = decoded
        }
        if let data = UserDefaults.standard.data(forKey: topSessionsKey),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            topSessions = decoded
        }
        if let arr = UserDefaults.standard.array(forKey: achievementsKey) as? [String] {
            unlockedAchievements = Set(arr)
        }
    }
}
