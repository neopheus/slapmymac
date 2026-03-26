import AVFoundation
import Foundation

/// Manages audio playback using AVAudioEngine with pre-decoded PCM buffers
/// for near-zero latency playback (~1-2ms vs ~30-60ms with AVAudioPlayer).
final class SoundManager {
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private let maxConcurrentPlayers = 4
    private var preloadedBuffers: [URL: AVAudioPCMBuffer] = [:]
    private var engineStarted = false

    init() {
        setupEngine()
    }

    private func setupEngine() {
        for _ in 0..<maxConcurrentPlayers {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            playerNodes.append(node)
        }
    }

    /// Preload all sounds from a pack: decode MP3 → PCM buffers in memory.
    /// Also configures the audio engine graph with the pack's audio format.
    func preload(_ pack: SoundPack) {
        stopAll()

        if engineStarted {
            engine.stop()
            engineStarted = false
        }

        preloadedBuffers.removeAll()
        guard !pack.urls.isEmpty else { return }

        // Load first file to determine format
        guard let firstFile = try? AVAudioFile(forReading: pack.urls[0]) else { return }
        let format = firstFile.processingFormat

        // Connect all player nodes with this format
        for node in playerNodes {
            engine.disconnectNodeOutput(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }

        // Reduce hardware buffer for lower latency (~5.8ms at 44.1kHz)
        engine.outputNode.auAudioUnit.maximumFramesToRender = 256

        // Start engine before loading buffers
        do {
            try engine.start()
            engineStarted = true
        } catch {
            print("[SlapMyMac] Audio engine start failed: \(error)")
            return
        }

        // Decode all MP3s → PCM buffers
        for url in pack.urls {
            if let buffer = decodeToPCM(url: url, expectedFormat: format) {
                preloadedBuffers[url] = buffer
            }
        }
    }

    /// Play a sound at the given URL with optional volume scaling based on impact amplitude.
    func play(url: URL, amplitude: Double? = nil) {
        guard let buffer = preloadedBuffers[url] else { return }
        guard let node = availableNode() else { return }

        node.volume = amplitude.map { scaledVolume(for: $0) } ?? 1.0
        node.scheduleBuffer(buffer)
        node.play()
    }

    func stopAll() {
        for node in playerNodes {
            node.stop()
        }
    }

    // MARK: - Private

    private func availableNode() -> AVAudioPlayerNode? {
        // Prefer a node that's not currently playing
        for node in playerNodes where !node.isPlaying {
            return node
        }
        // All busy — recycle the first one
        playerNodes[0].stop()
        return playerNodes[0]
    }

    private func decodeToPCM(url: URL, expectedFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }

        // If format matches, read directly
        if file.processingFormat == expectedFormat {
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: expectedFormat, frameCapacity: frameCount) else { return nil }
            do {
                try file.read(into: buffer)
                return buffer
            } catch {
                return nil
            }
        }

        // Format mismatch — convert via AVAudioConverter
        guard let converter = AVAudioConverter(from: file.processingFormat, to: expectedFormat) else { return nil }
        let ratio = expectedFormat.sampleRate / file.processingFormat.sampleRate
        let targetFrameCount = AVAudioFrameCount(Double(file.length) * ratio) + 256
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: expectedFormat, frameCapacity: targetFrameCount) else { return nil }

        // Read source fully first
        let sourceFrameCount = AVAudioFrameCount(file.length)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: sourceFrameCount) else { return nil }
        do {
            try file.read(into: sourceBuffer)
        } catch {
            return nil
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: targetBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        return error == nil ? targetBuffer : nil
    }

    /// Maps impact amplitude to volume using a logarithmic curve.
    private func scaledVolume(for amplitude: Double) -> Float {
        let floor = Constants.amplitudeFloor
        let ceiling = Constants.amplitudeCeiling

        var t = (amplitude - floor) / (ceiling - floor)
        t = max(0, min(1, t))

        // Logarithmic curve for more natural feel
        t = log(1.0 + t * 99.0) / log(100.0)

        return Constants.volumeMin + Float(t) * (Constants.volumeMax - Constants.volumeMin)
    }
}
