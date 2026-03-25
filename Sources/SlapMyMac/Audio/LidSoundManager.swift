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

/// Manages lid audio engines (creak + theremin).
/// Call `feed(angle:velocity:)` continuously from the lid sensor poll.
final class LidSoundManager {
    private let creakEngine = CreakAudioEngine()
    private let thereminEngine = ThereminAudioEngine()
    private var currentMode: LidAudioMode = .creak

    func setMode(_ mode: LidAudioMode) {
        // Stop current
        if currentMode != mode {
            stopCurrent()
        }
        currentMode = mode
        startCurrent()
    }

    func start() {
        startCurrent()
    }

    func stop() {
        stopCurrent()
    }

    /// Feed sensor data. Called at ~10-30Hz from the lid poll timer.
    func feed(angle: Double, velocity: Double) {
        switch currentMode {
        case .creak:
            creakEngine.feed(velocity: velocity)
        case .theremin:
            thereminEngine.feed(angle: angle, velocity: velocity)
        case .off:
            break
        }
    }

    private func startCurrent() {
        switch currentMode {
        case .creak:
            if !creakEngine.isRunning { creakEngine.start() }
        case .theremin:
            if !thereminEngine.isRunning { thereminEngine.start() }
        case .off:
            break
        }
    }

    private func stopCurrent() {
        creakEngine.stop()
        thereminEngine.stop()
    }
}
