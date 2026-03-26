import AVFoundation
import Foundation

/// Plays CREAK_LOOP.wav with velocity-modulated volume and pitch.
/// Ported from samhenrigold/LidAngleSensor.
///
/// Slow lid movement → loud, deep creak
/// Fast lid movement → quiet or silent
/// No movement → silence (deadzone)
final class CreakAudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?

    private(set) var isRunning = false

    // Current smoothed values
    private var currentGain: Float = 0
    private var currentRate: Float = 1.0
    private var lastFeedTime: TimeInterval = 0

    // Parameters (from LidAngleSensor)
    private let velocityFull: Double = 10.0     // Full volume threshold
    private let velocityQuiet: Double = 100.0   // Min volume threshold
    private let deadzone: Double = 3.0          // Ignore below 3°/s — rejects sensor noise
    private let minRate: Float = 0.80           // Lowest pitch
    private let maxRate: Float = 1.10           // Highest pitch
    private let gainRampMs: Double = 50.0       // Volume smoothing tau
    private let rateRampMs: Double = 80.0       // Pitch smoothing tau

    init() {
        loadAudioFile()
        setupAudioGraph()
    }

    func start() {
        guard !isRunning, audioBuffer != nil else { return }

        do {
            try engine.start()
            // Schedule the buffer to loop infinitely
            playerNode.scheduleBuffer(audioBuffer!, at: nil, options: .loops)
            playerNode.play()
            playerNode.volume = 0  // Start silent
            isRunning = true
        } catch {
            print("[Creak] Failed to start engine: \(error)")
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isRunning = false
        currentGain = 0
        currentRate = 1.0
    }

    /// Feed velocity data from the lid sensor. Call at ~30Hz.
    func feed(velocity: Double) {
        guard isRunning else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastFeedTime > 0 ? now - lastFeedTime : 1.0 / 30.0
        lastFeedTime = now

        let speed = abs(velocity)

        // Target gain: inverted — slow = loud, fast = quiet
        let targetGain: Float
        if speed < deadzone {
            targetGain = 0
        } else {
            let t = (speed - velocityFull) / (velocityQuiet - velocityFull)
            let clamped = max(0, min(1, t))
            let s = smoothstep(clamped)
            targetGain = Float(1.0 - s)
        }

        // Target rate: faster movement = higher pitch
        let normalized = min(1, speed / velocityQuiet)
        let targetRate = minRate + Float(normalized) * (maxRate - minRate)

        // Smooth fade-out when stopped, smooth ramp when moving.
        // Use 30ms tau for fade-out — fast enough to feel responsive,
        // slow enough to avoid audible pops/clicks.
        if targetGain == 0 {
            currentGain = ramp(currentGain, toward: 0, dt: dt, tauMs: 30.0)
            if currentGain < 0.005 { currentGain = 0 }
        } else {
            currentGain = ramp(currentGain, toward: targetGain, dt: dt, tauMs: gainRampMs)
        }
        currentRate = ramp(currentRate, toward: targetRate, dt: dt, tauMs: rateRampMs)

        // Apply
        playerNode.volume = currentGain
        varispeed.rate = currentRate
    }

    // MARK: - Private

    private func loadAudioFile() {
        // Try bundle resource paths
        let possiblePaths = [
            Bundle.main.url(forResource: "CREAK_LOOP", withExtension: "wav"),
            Bundle.main.url(forResource: "Sounds/CREAK_LOOP", withExtension: "wav"),
            Bundle.main.resourceURL?.appendingPathComponent("Sounds/CREAK_LOOP.wav"),
            Bundle.main.resourceURL?.appendingPathComponent("SlapMyMac_SlapMyMac.bundle/Sounds/CREAK_LOOP.wav"),
        ]

        for urlOpt in possiblePaths {
            guard let url = urlOpt, FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let file = try AVAudioFile(forReading: url)
                let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                              frameCapacity: AVAudioFrameCount(file.length))!
                try file.read(into: buffer)
                self.audioFile = file
                self.audioBuffer = buffer
                print("[Creak] Loaded CREAK_LOOP.wav (\(file.length) frames)")
                return
            } catch {
                print("[Creak] Failed to load \(url.path): \(error)")
            }
        }

        print("[Creak] CREAK_LOOP.wav not found in bundle")
    }

    private func setupAudioGraph() {
        engine.attach(playerNode)
        engine.attach(varispeed)

        let format = audioFile?.processingFormat ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        engine.connect(playerNode, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)

        // Reduce hardware buffer for lower latency (~5.8ms at 44.1kHz)
        engine.outputNode.auAudioUnit.maximumFramesToRender = 256
    }

    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    private func ramp(_ value: Float, toward target: Float, dt: Double, tauMs: Double) -> Float {
        let alpha = min(1, Float(dt / (tauMs / 1000.0)))
        return value + (target - value) * alpha
    }
}
