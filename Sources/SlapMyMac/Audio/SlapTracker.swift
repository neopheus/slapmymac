import Foundation

/// Tracks slap intensity with exponential decay for escalation modes.
/// In random modes (pain, halo, custom), selects a random file.
/// In escalation mode (sexy), selects based on accumulated score.
final class SlapTracker {
    private var score: Double = 0
    private var lastEventTime: TimeInterval = 0
    private let halfLife: TimeInterval
    private let escalationScale: Double

    init(halfLife: TimeInterval = Constants.decayHalfLife,
         escalationScale: Double = Constants.escalationScale) {
        self.halfLife = halfLife
        self.escalationScale = escalationScale
    }

    /// Register an impact and get the index of the sound file to play.
    func selectSound(for event: ImpactEvent, from pack: SoundPack) -> Int? {
        guard !pack.isEmpty else { return nil }

        if pack.mode.isEscalating {
            return selectEscalating(event: event, count: pack.count)
        } else {
            return selectRandom(count: pack.count)
        }
    }

    private func selectEscalating(event: ImpactEvent, count: Int) -> Int {
        // Apply exponential decay since last event
        let now = event.timestamp
        if lastEventTime > 0 {
            let elapsed = now - lastEventTime
            score *= pow(0.5, elapsed / halfLife)
        }
        lastEventTime = now

        // Add 1.0 for each impact
        score += 1.0

        // Map score to file index: exponential ramp-up
        let n = Double(count)
        let index = n * (1.0 - exp(-(score - 1.0) / escalationScale))
        return min(Int(index), count - 1)
    }

    private func selectRandom(count: Int) -> Int {
        Int.random(in: 0..<count)
    }

    func reset() {
        score = 0
        lastEventTime = 0
    }
}
