import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isListening = false
    @Published var slapCount: Int = 0
    @Published var lastImpact: ImpactEvent?
    @Published var currentPack: SoundPack?
    @Published var errorMessage: String?
    @Published var lastSampleDebug: String = "—"
    @Published var lastLidEvent: LidEvent?

    var settings = UserSettings()
    let lidAngle = LidAngleSensor()
    let history = SlapHistory()

    private let accelerometer = AccelerometerService()
    private let detector = ImpactDetector()
    private let slapTracker = SlapTracker()
    private let soundManager = SoundManager()
    private let lidEventDetector = LidEventDetector()
    private let lidSoundManager = LidSoundManager()
    private let mcpServer = MCPServer()
    private var sensorTask: Task<Void, Never>?
    private var lidPollTimer: Timer?
    private var sampleCount: Int = 0
    private var mcpRefreshCounter: Int = 0

    init() {
        loadSoundPack()
        setupMCPServer()

        // Auto-start after init
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            startListening()
            lidAngle.start()
            startLidEventPolling()
            updateMCPSnapshot()
            mcpServer.start()
        }
    }

    // MARK: - Accelerometer Control

    func startListening() {
        guard !isListening else { return }

        detector.updateSensitivity(settings.sensitivity)
        detector.updateCooldown(settings.cooldownMs)

        let stream = accelerometer.start()
        isListening = true
        errorMessage = nil

        sensorTask = Task { [weak self] in
            for await sample in stream {
                guard let self = self else { break }
                self.processSample(sample)
            }
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
        if isListening { stopListening() } else { startListening() }
    }

    // MARK: - Lid Audio + Event Polling

    private func startLidEventPolling() {
        guard lidAngle.isAvailable else { return }

        // Start the lid audio engine
        updateLidAudioMode()

        // Poll at 30Hz for smooth audio modulation
        lidPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pollLid()
            }
        }
    }

    private func pollLid() {
        let angle = lidAngle.angle
        let velocity = lidAngle.velocity

        // Feed continuous audio (creak/theremin)
        if settings.lidSoundsEnabled {
            lidSoundManager.feed(angle: angle, velocity: velocity)
        }

        // Detect discrete lid events (open/close/slam) for UI display
        if let event = lidEventDetector.process(angle: angle, velocity: velocity) {
            lastLidEvent = event
        }

        // Refresh MCP snapshot every ~10th poll (~3Hz) — thread-safe for server reads
        mcpRefreshCounter += 1
        if mcpRefreshCounter % 10 == 0 {
            updateMCPSnapshot()
        }
    }

    func updateLidAudioMode() {
        if settings.lidSoundsEnabled {
            lidSoundManager.setMode(settings.lidAudioMode)
        } else {
            lidSoundManager.stop()
        }
    }

    // MARK: - Sound Pack Management

    func loadSoundPack() {
        let mode = settings.soundMode
        if mode == .custom, let url = settings.customSoundURL {
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

    /// Trigger a sound for external MCP callers.
    func triggerExternalSound(mode: String) {
        if let soundMode = SoundMode(rawValue: mode) {
            let pack = SoundPack.bundled(soundMode)
            guard !pack.isEmpty else { return }
            let url = pack.urls[Int.random(in: 0..<pack.count)]
            soundManager.play(url: url)
        } else {
            playTestSound()
        }
    }

    // MARK: - MCP Server Setup

    /// Thread-safe snapshot storage, accessible from any thread.
    private static let mcpStore = MCPSnapshotStore()

    /// Call periodically from main thread to refresh snapshot.
    private func updateMCPSnapshot() {
        let snapshot: [String: Any] = [
            "listening": isListening,
            "slapCount": slapCount,
            "lifetimeSlaps": settings.lifetimeSlaps,
            "soundMode": settings.soundMode.rawValue,
            "sensitivity": settings.sensitivity,
            "lidAngle": lidAngle.isAvailable ? lidAngle.angle : -1,
            "lastImpact": lastImpact.map { [
                "severity": $0.severity.rawValue,
                "amplitude": $0.amplitude,
                "detectorCount": $0.detectorCount
            ] as [String: Any] } ?? [:] as [String: Any]
        ]

        let s = history.stats
        let stats: [String: Any] = [
            "totalSlaps": s.totalSlaps,
            "sessionSlaps": s.sessionSlaps,
            "avgAmplitude": s.avgAmplitude,
            "maxAmplitude": s.maxAmplitude,
            "majorCount": s.majorCount,
            "mediumCount": s.mediumCount,
            "slapsPerMinute": s.slapsPerMinute,
            "sessionDurationSeconds": s.sessionDuration,
            "favoriteMode": s.favoriteMode,
        ]

        let hist = history.recentRecords(50).map { record in
            [
                "id": record.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: record.timestamp),
                "amplitude": record.amplitude,
                "severity": record.severity,
                "detectorCount": record.detectorCount,
                "soundMode": record.soundMode,
            ] as [String: Any]
        }

        Self.mcpStore.update(snapshot: snapshot, stats: stats, history: hist)
    }

    private func setupMCPServer() {
        let store = Self.mcpStore
        mcpServer.getStatus = {
            store.snapshot
        }

        mcpServer.getStats = {
            store.stats
        }

        mcpServer.getHistory = {
            store.history
        }

        mcpServer.triggerSound = { [weak self] mode in
            DispatchQueue.main.async {
                self?.triggerExternalSound(mode: mode)
            }
        }

        mcpServer.setMode = { [weak self] mode in
            DispatchQueue.main.async {
                if let soundMode = SoundMode(rawValue: mode) {
                    self?.settings.soundMode = soundMode
                    self?.loadSoundPack()
                }
            }
        }
    }

    // MARK: - Sample Processing

    private func processSample(_ sample: AccelerometerSample) {
        sampleCount += 1

        if sampleCount % 50 == 0 {
            lastSampleDebug = String(format: "x:%.2f y:%.2f z:%.2f (mag:%.3f)",
                                     sample.x, sample.y, sample.z, sample.magnitude)
        }

        guard let event = detector.process(sample) else { return }
        guard event.severity == .major || event.severity == .medium else { return }

        lastImpact = event
        slapCount += 1
        settings.lifetimeSlaps += 1

        // Record in history
        history.record(event, mode: settings.soundMode)

        // Play sound
        guard let pack = currentPack,
              let index = slapTracker.selectSound(for: event, from: pack) else { return }

        let url = pack.urls[index]
        let amplitude = settings.volumeScaling ? event.amplitude : nil
        soundManager.play(url: url, amplitude: amplitude)
    }
}
