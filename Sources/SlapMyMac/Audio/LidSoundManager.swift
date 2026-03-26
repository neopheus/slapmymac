import Foundation

/// Audio mode for lid sounds.
enum LidAudioMode: String, CaseIterable, Identifiable, Codable {
    case creak = "Creak"
    case theremin = "Theremin"
    case off = "Off"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .creak: return "Progressive wood creak sound"
        case .theremin: return "Sine wave mapped to lid angle"
        case .off: return "No lid sounds"
        }
    }
}

/// Manages lid audio engines (creak + theremin) with lazy start/stop.
///
/// Engines are NOT started when mode is set — they only start when velocity > 0
/// (actual lid movement) and stop completely after a period of silence.
/// This avoids the ~10-15% CPU drain of an idle AVAudioEngine hardware I/O process.
final class LidSoundManager {
    private let creakEngine = CreakAudioEngine()
    private let thereminEngine = ThereminAudioEngine()
    private var currentMode: LidAudioMode = .off

    // Lazy engine lifecycle — track whether the active engine is actually running
    private(set) var isEngineActive = false
    private var silentPollCount: Int = 0
    /// After this many zero-velocity polls, stop the engine entirely.
    /// At 30Hz poll rate: 30 polls = ~1 second of silence before engine shutdown.
    private let silentPollsBeforeStop: Int = 30

    func setMode(_ mode: LidAudioMode) {
        if currentMode != mode {
            stopEngine()
        }
        currentMode = mode
        // Do NOT start the engine here — wait for actual lid movement in feed()
    }

    func start() {
        // No-op: engines start lazily in feed()
    }

    func stop() {
        stopEngine()
    }

    /// Feed sensor data. Called at ~5-30Hz from the lid poll timer.
    /// Manages engine lifecycle: starts on movement, stops after silence.
    func feed(angle: Double, velocity: Double) {
        guard currentMode != .off else { return }

        let hasMovement = velocity > 0.1

        if hasMovement {
            silentPollCount = 0

            // Lazy start: only start the engine when we actually need sound
            if !isEngineActive {
                startEngine()
            }

            // Feed the active engine
            switch currentMode {
            case .creak:
                creakEngine.feed(velocity: velocity)
            case .theremin:
                thereminEngine.feed(angle: angle, velocity: velocity)
            case .off:
                break
            }
        } else {
            // No movement — feed zero velocity so audio fades out smoothly
            if isEngineActive {
                switch currentMode {
                case .creak:
                    creakEngine.feed(velocity: 0)
                case .theremin:
                    thereminEngine.feed(angle: angle, velocity: 0)
                case .off:
                    break
                }

                // Count silent polls and stop engine after threshold
                silentPollCount += 1
                if silentPollCount >= silentPollsBeforeStop {
                    stopEngine()
                }
            }
        }
    }

    private func startEngine() {
        guard !isEngineActive else { return }
        switch currentMode {
        case .creak:
            creakEngine.start()
        case .theremin:
            thereminEngine.start()
        case .off:
            break
        }
        isEngineActive = true
    }

    private func stopEngine() {
        creakEngine.stop()
        thereminEngine.stop()
        isEngineActive = false
        silentPollCount = 0
    }
}
