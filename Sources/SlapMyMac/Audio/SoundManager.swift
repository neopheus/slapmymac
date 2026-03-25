import AVFoundation
import Foundation

/// Manages audio playback with preloading and volume scaling.
final class SoundManager {
    private var players: [AVAudioPlayer] = []
    private let maxConcurrentPlayers = 4
    private var preloadedPlayers: [URL: AVAudioPlayer] = [:]

    /// Preload all sounds from a pack for low-latency playback.
    func preload(_ pack: SoundPack) {
        preloadedPlayers.removeAll()
        for url in pack.urls {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                preloadedPlayers[url] = player
            }
        }
    }

    /// Play a sound at the given URL with optional volume scaling based on impact amplitude.
    func play(url: URL, amplitude: Double? = nil) {
        // Clean up finished players
        players.removeAll { !$0.isPlaying }

        // Limit concurrent playback
        guard players.count < maxConcurrentPlayers else { return }

        guard let player = createPlayer(for: url) else { return }

        if let amp = amplitude {
            player.volume = scaledVolume(for: amp)
        }

        player.play()
        players.append(player)
    }

    func stopAll() {
        for player in players {
            player.stop()
        }
        players.removeAll()
    }

    // MARK: - Private

    private func createPlayer(for url: URL) -> AVAudioPlayer? {
        // Try to use a preloaded copy (create a new instance to allow overlapping)
        if preloadedPlayers[url] != nil {
            // Create a fresh player from the same URL for concurrent playback
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                return player
            }
        }

        // Fallback: create new player
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    /// Maps impact amplitude to volume using a logarithmic curve.
    /// From spank: maps [0.05g, 0.8g] → [0.125, 1.0] with log curve.
    private func scaledVolume(for amplitude: Double) -> Float {
        let floor = Constants.amplitudeFloor
        let ceiling = Constants.amplitudeCeiling

        // Normalize to [0, 1]
        var t = (amplitude - floor) / (ceiling - floor)
        t = max(0, min(1, t))

        // Logarithmic curve for more natural feel
        t = log(1.0 + t * 99.0) / log(100.0)

        // Map to volume range
        return Constants.volumeMin + Float(t) * (Constants.volumeMax - Constants.volumeMin)
    }
}
