import AVFoundation
import Foundation

/// Pure sine wave synthesis mapped to lid angle.
/// Ported from samhenrigold/LidAngleSensor.
///
/// Angle controls pitch (110–440 Hz), velocity boosts volume, 5Hz vibrato.
final class ThereminAudioEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    private(set) var isRunning = false

    // Oscillator state (accessed from audio render thread — benign races OK)
    nonisolated(unsafe) private var phase: Double = 0
    nonisolated(unsafe) private var vibratoPhase: Double = 0
    nonisolated(unsafe) private var frequency: Double = 220
    nonisolated(unsafe) private var volume: Double = 0

    // Targets (set from main thread, read from audio thread)
    nonisolated(unsafe) private var targetFrequency: Double = 220
    nonisolated(unsafe) private var targetVolume: Double = 0

    // Parameters
    private let sampleRate: Double = 44100
    private let minFrequency: Double = 110.0   // A2
    private let maxFrequency: Double = 440.0   // A4
    private let maxAngle: Double = 135.0
    private let baseVolume: Double = 0.6
    private let velocityVolumeBoost: Double = 0.4
    private let velocityQuiet: Double = 80.0
    private let vibratoFreq: Double = 5.0
    private let vibratoDepth: Double = 0.03

    private var lastFeedTime: TimeInterval = 0

    init() {
        setupAudioGraph()
    }

    func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("[Theremin] Failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
        phase = 0
        vibratoPhase = 0
        volume = 0
        targetVolume = 0
    }

    /// Feed angle and velocity from the lid sensor.
    func feed(angle: Double, velocity: Double) {
        guard isRunning else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastFeedTime > 0 ? now - lastFeedTime : 1.0 / 30.0
        lastFeedTime = now

        // Frequency from angle (power curve for natural feel)
        let normalizedAngle = max(0, min(1, angle / maxAngle))
        let ratio = pow(normalizedAngle, 0.7)
        targetFrequency = minFrequency + ratio * (maxFrequency - minFrequency)

        // Volume: base + velocity boost (slow = louder)
        let speed = abs(velocity)
        if speed < 1.0 {
            targetVolume = 0  // Deadzone
        } else {
            let t = min(1, speed / velocityQuiet)
            let s = smoothstep(t)
            let boost = (1 - s) * velocityVolumeBoost
            targetVolume = min(1, baseVolume + boost)
        }

        // Smooth ramp
        let freqAlpha = min(1, dt / 0.030)
        let volAlpha = min(1, dt / 0.050)
        frequency = frequency + (targetFrequency - frequency) * freqAlpha
        volume = volume + (targetVolume - volume) * volAlpha
    }

    // MARK: - Private

    private func setupAudioGraph() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let node = AVAudioSourceNode { [unowned self] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buf = ablPointer[0]
            guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for frame in 0..<Int(frameCount) {
                // Vibrato modulation
                let vibrato = sin(self.vibratoPhase) * self.vibratoDepth
                let freq = self.frequency * (1 + vibrato)

                let increment = 2.0 * .pi * freq / self.sampleRate
                self.phase += increment
                if self.phase > 2.0 * .pi { self.phase -= 2.0 * .pi }

                self.vibratoPhase += 2.0 * .pi * self.vibratoFreq / self.sampleRate
                if self.vibratoPhase > 2.0 * .pi { self.vibratoPhase -= 2.0 * .pi }

                data[frame] = Float(sin(self.phase) * self.volume * 0.25)
            }

            return noErr
        }

        self.sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
}
