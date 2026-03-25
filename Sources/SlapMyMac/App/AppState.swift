import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isListening = false
    @Published var slapCount: Int = 0
    @Published var lastImpact: ImpactEvent?
    @Published var currentPack: SoundPack?
    @Published var errorMessage: String?

    var settings = UserSettings()

    private let accelerometer = AccelerometerService()
    private let detector = ImpactDetector()
    private let slapTracker = SlapTracker()
    private let soundManager = SoundManager()
    private var sensorTask: Task<Void, Never>?

    init() {
        loadSoundPack()
        // Auto-start listening after a brief delay for initialization
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }

        // Update detector with current settings
        detector.updateSensitivity(settings.sensitivity)
        detector.updateCooldown(settings.cooldownMs)

        let stream = accelerometer.start()
        isListening = true

        sensorTask = Task { [weak self] in
            for await sample in stream {
                guard let self = self else { break }
                self.processSample(sample)
            }
            // Stream ended — check for errors
            if let error = self?.accelerometer.errorMessage {
                await MainActor.run {
                    self?.errorMessage = error
                    self?.isListening = false
                }
            }
        }
    }

    func stopListening() {
        sensorTask?.cancel()
        sensorTask = nil
        accelerometer.stop()
        detector.reset()
        isListening = false
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func loadSoundPack() {
        let mode = settings.soundMode
        if mode == .custom, let url = settings.customSoundURL {
            // Resolve security-scoped bookmark if available
            if let bookmarkData = UserDefaults.standard.data(forKey: "customSoundBookmark") {
                var isStale = false
                if let resolvedURL = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    _ = resolvedURL.startAccessingSecurityScopedResource()
                    currentPack = SoundPack.custom(from: resolvedURL)
                    soundManager.preload(currentPack!)
                    return
                }
            }
            currentPack = SoundPack.custom(from: url)
        } else {
            currentPack = SoundPack.bundled(mode)
        }

        if let pack = currentPack {
            soundManager.preload(pack)
        }

        slapTracker.reset()
    }

    func playTestSound() {
        guard let pack = currentPack, !pack.isEmpty else { return }
        let index = Int.random(in: 0..<pack.count)
        soundManager.play(url: pack.urls[index])
    }

    // MARK: - Private

    private func processSample(_ sample: AccelerometerSample) {
        // Run detection (this is fast, OK on main actor for now)
        guard let event = detector.process(sample) else { return }

        // Only react to meaningful impacts
        guard event.severity == .major || event.severity == .medium else { return }

        lastImpact = event
        slapCount += 1

        // Select and play sound
        guard let pack = currentPack,
              let index = slapTracker.selectSound(for: event, from: pack) else { return }

        let url = pack.urls[index]
        let amplitude = settings.volumeScaling ? event.amplitude : nil
        soundManager.play(url: url, amplitude: amplitude)
    }
}
