import SwiftUI
import Combine
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var isListening = false
    @Published var slapCount: Int = 0
    @Published var lastImpact: ImpactEvent?
    @Published var currentPack: SoundPack?
    @Published var errorMessage: String?
    @Published var lastSampleDebug: String = "—"
    @Published var lastLidEvent: LidEvent?
    @Published var slapFlash = false
    @Published var isMuted = false
    @Published var muteRemaining: String = ""
    @Published var recentAmplitudes: [Double] = []

    var settings = UserSettings()
    let lidAngle = LidAngleSensor()
    let history = SlapHistory()
    let leaderboard = Leaderboard()

    private let accelerometer = AccelerometerService()
    private let detector = ImpactDetector()
    private let slapTracker = SlapTracker()
    private let soundManager = SoundManager()
    private let lidEventDetector = LidEventDetector()
    private let lidSoundManager = LidSoundManager()
    private let lidEventSoundManager = SoundManager()
    private let mcpServer = MCPServer()
    private var sensorTask: Task<Void, Never>?
    private var lidPollTimer: Timer?
    private var sampleCount: Int = 0
    private var mcpRefreshCounter: Int = 0
    // Adaptive lid polling — slow down when lid is stationary
    private var lidIdlePolls: Int = 0
    private let lidIdleThreshold: Int = 15  // After 15 idle polls (~0.5s at 30Hz), drop to slow rate
    private let lidSlowInterval: TimeInterval = 0.2  // 5Hz when idle
    private var isLidSlowPolling = false
    private let globalHotKey = GlobalHotKey()
    private var muteTimer: Timer?
    private var muteEndDate: Date?
    let profileManager = ProfileManager()
    private let logger = AppLogger.shared

    init() {
        soundManager.masterVolume = Float(settings.masterVolume)
        loadSoundPack()
        preloadLidEventSounds()
        setupMCPServer()

        // Auto-start after init
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            startListening()
            lidAngle.start()  // Opens HID device only, no internal timer
            startLidPolling()
            updateMCPSnapshot()
            if settings.mcpServerEnabled {
                mcpServer.start()
            }
            setupGlobalHotKey()
            requestNotificationPermission()
            logger.log("App started")
            logger.trimIfNeeded()

            // Setup achievement notification callback
            leaderboard.onAchievementUnlocked = { [weak self] achievement in
                self?.sendAchievementNotification(achievement)
            }
            maxRecordedAmplitude = history.stats.maxAmplitude
        }
    }

    // MARK: - Accelerometer Control

    func startListening() {
        guard !isListening else { return }

        detector.updateSensitivity(settings.sensitivity)
        detector.updateCooldown(settings.cooldownMs)
        detector.updateSuppressionSamples(settings.suppressionSamples)
        detector.updateKurtosisEvalInterval(settings.kurtosisEvalInterval)
        accelerometer.decimationFactor = settings.decimationFactor

        let stream = accelerometer.start()
        isListening = true
        errorMessage = nil
        if settings.startupSoundEnabled {
            soundManager.playSystemSound()
        }
        logger.log("Listening started")

        // Process samples on a detached background task to keep main thread free.
        // Only hop to @MainActor when an actual impact is detected.
        let det = detector
        sensorTask = Task.detached(priority: .userInitiated) { [weak self] in
            var count = 0
            for await sample in stream {
                guard let self = self else { break }
                if Task.isCancelled { break }

                count += 1

                // Run detector on background thread (pure computation, no UI)
                let event = det.process(sample)

                // Debug string update — infrequent, on main
                if count % 100 == 0 {
                    let dbg = String(format: "x:%.2f y:%.2f z:%.2f (mag:%.3f)",
                                     sample.x, sample.y, sample.z, sample.magnitude)
                    await MainActor.run { [weak self] in
                        self?.lastSampleDebug = dbg
                    }
                }

                // Only hop to main when we have an actual impact worth reporting
                if let event = event,
                   event.severity == .major || event.severity == .medium {
                    await MainActor.run { [weak self] in
                        self?.handleDetectedImpact(event)
                    }
                }
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
        // Submit session to leaderboard before stopping
        let s = history.stats
        leaderboard.submitSession(
            slapCount: s.sessionSlaps,
            maxAmplitude: s.maxAmplitude,
            avgAmplitude: s.avgAmplitude,
            duration: s.sessionDuration,
            slapsPerMinute: s.slapsPerMinute,
            majorCount: s.majorCount
        )

        sensorTask?.cancel()
        sensorTask = nil
        accelerometer.stop()
        detector.reset()
        isListening = false
        if settings.startupSoundEnabled {
            soundManager.playSystemSound()
        }
        logger.log("Listening stopped")
    }

    func toggleListening() {
        if isListening { stopListening() } else { startListening() }
    }

    /// Apply updated performance settings. Restarts the sensor pipeline to pick up new decimation factor.
    func applyPerformanceSettings() {
        detector.updateSuppressionSamples(settings.suppressionSamples)
        detector.updateKurtosisEvalInterval(settings.kurtosisEvalInterval)
        detector.updateCooldown(settings.cooldownMs)

        // Decimation factor requires sensor restart
        if isListening {
            stopListening()
            startListening()
        }
    }

    func applyMasterVolume() {
        soundManager.masterVolume = Float(settings.masterVolume)
    }

    /// Apply sensitivity and cooldown changes to the detector in real-time.
    func applySensitivitySettings() {
        detector.updateSensitivity(settings.sensitivity)
        detector.updateCooldown(settings.cooldownMs)
    }

    /// Start or stop the MCP server based on settings.
    func toggleMCPServer() {
        if settings.mcpServerEnabled {
            mcpServer.start()
        } else {
            mcpServer.stop()
        }
    }

    // MARK: - Mute Timer

    func startMuteTimer(minutes: Int) {
        cancelMuteTimer()
        isMuted = true
        muteEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        logger.log("Mute timer started: \(minutes) minutes")

        muteTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let endDate = self.muteEndDate else { return }
                let remaining = endDate.timeIntervalSinceNow
                if remaining <= 0 {
                    self.cancelMuteTimer()
                } else {
                    let mins = Int(remaining) / 60
                    let secs = Int(remaining) % 60
                    self.muteRemaining = String(format: "%d:%02d", mins, secs)
                }
            }
        }
    }

    func cancelMuteTimer() {
        muteTimer?.invalidate()
        muteTimer = nil
        muteEndDate = nil
        isMuted = false
        muteRemaining = ""
    }

    // MARK: - Sound Profiles

    func loadProfile(_ profile: SoundProfile) {
        if let mode = SoundMode(rawValue: profile.soundMode) {
            settings.soundMode = mode
        }
        settings.sensitivity = profile.sensitivity
        settings.cooldownMs = profile.cooldownMs
        settings.masterVolume = profile.masterVolume
        settings.volumeScaling = profile.volumeScaling

        loadSoundPack()
        applySensitivitySettings()
        applyMasterVolume()
        logger.log("Loaded profile: \(profile.name)")
    }

    func saveCurrentAsProfile(name: String) {
        let profile = SoundProfile(
            name: name,
            soundMode: settings.soundMode.rawValue,
            sensitivity: settings.sensitivity,
            cooldownMs: settings.cooldownMs,
            masterVolume: settings.masterVolume,
            volumeScaling: settings.volumeScaling
        )
        profileManager.save(profile: profile)
        logger.log("Saved profile: \(name)")
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotKey() {
        globalHotKey.register { [weak self] in
            DispatchQueue.main.async {
                self?.toggleListening()
            }
        }
    }

    // MARK: - Lid Polling (single adaptive timer — no duplicate with LidAngleSensor)

    private func startLidPolling() {
        guard lidAngle.isAvailable else { return }

        // Apply lid performance settings
        lidAngle.angleSmoothingTau = settings.angleSmoothingTau
        lidAngle.velocitySmoothingTau = settings.velocitySmoothingTau
        lidEventDetector.updateEventCooldown(settings.lidEventCooldown)

        // Start the lid audio engine
        updateLidAudioMode()

        // Start at normal rate — will adapt to slow rate when lid is stationary
        scheduleLidTimer(interval: 1.0 / max(1, settings.lidPollHz))
        isLidSlowPolling = false
    }

    private func scheduleLidTimer(interval: TimeInterval) {
        lidPollTimer?.invalidate()
        lidPollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pollLid()
            }
        }
    }

    private func pollLid() {
        // Single poll — reads IOKit + updates smoothing in one call
        let velocity = lidAngle.pollOnce()
        let angle = lidAngle.angle

        // Feed continuous audio (creak/theremin)
        if settings.lidSoundsEnabled {
            lidSoundManager.feed(angle: angle, velocity: velocity)
        }

        // Detect discrete lid events (open/close/slam)
        if let event = lidEventDetector.process(angle: angle, velocity: velocity) {
            lastLidEvent = event
            playLidEventSound(event)
        }

        // Adaptive polling: slow down when lid is stationary
        if velocity < 0.1 {
            lidIdlePolls += 1
            if lidIdlePolls >= lidIdleThreshold && !isLidSlowPolling {
                isLidSlowPolling = true
                scheduleLidTimer(interval: lidSlowInterval)
            }
        } else {
            if isLidSlowPolling {
                isLidSlowPolling = false
                scheduleLidTimer(interval: 1.0 / max(1, settings.lidPollHz))
            }
            lidIdlePolls = 0
        }

        // Refresh MCP snapshot every ~30th poll (~1Hz at 30Hz) — skip if no clients
        mcpRefreshCounter += 1
        if mcpRefreshCounter % 30 == 0 && (mcpServer.hasClients || settings.mcpServerEnabled) {
            updateMCPSnapshot()
        }
    }

    /// Apply updated lid performance settings. Restarts polling timer if rate changed.
    func applyLidPerformanceSettings() {
        lidAngle.angleSmoothingTau = settings.angleSmoothingTau
        lidAngle.velocitySmoothingTau = settings.velocitySmoothingTau
        lidEventDetector.updateEventCooldown(settings.lidEventCooldown)

        // Reset to normal poll rate
        isLidSlowPolling = false
        lidIdlePolls = 0
        scheduleLidTimer(interval: 1.0 / max(1, settings.lidPollHz))
    }

    private func preloadLidEventSounds() {
        // Lid event sounds are stored in Resources/Sounds/Lid/ (00=open, 01=close, 02=slam)
        let lidPack = SoundPack.bundled(.lid)
        if !lidPack.isEmpty {
            lidEventSoundManager.masterVolume = Float(settings.masterVolume)
            lidEventSoundManager.preload(lidPack)
        }
    }

    private func playLidEventSound(_ event: LidEvent) {
        guard settings.lidEventSoundsEnabled else { return }
        if settings.respectFocus && isFocusModeActive { return }

        let lidPack = SoundPack.bundled(.lid)
        guard !lidPack.isEmpty else { return }

        let index: Int
        switch event {
        case .opened: index = 0
        case .closed: index = 1
        case .slammed: index = 2
        case .creaking: return // Continuous audio handles this
        }

        guard index < lidPack.urls.count else { return }
        lidEventSoundManager.play(url: lidPack.urls[index])
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
                    if currentPack?.isEmpty == true {
                        errorMessage = "Custom folder is empty — no MP3 files found"
                    } else {
                        errorMessage = nil
                    }
                    soundManager.preload(currentPack!)
                    slapTracker.reset()
                    return
                }
            }
            currentPack = SoundPack.custom(from: url)
        } else {
            currentPack = SoundPack.bundled(mode)
        }

        if let pack = currentPack {
            if pack.isEmpty && mode == .custom {
                errorMessage = "Custom folder is empty — no MP3 files found"
            } else {
                errorMessage = nil
            }
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
    /// Cached date formatter — creating ISO8601DateFormatter is expensive.
    private let isoFormatter = ISO8601DateFormatter()

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
                "timestamp": isoFormatter.string(from: record.timestamp),
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

    // MARK: - Focus Mode

    /// Check if macOS Focus/DND is active by reading the DND preferences plist.
    private var isFocusModeActive: Bool {
        let dndPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: dndPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let store = json["data"] as? [[String: Any]] else {
            return false
        }
        // If there are active assertions, Focus is on
        return !store.isEmpty
    }

    // MARK: - Notifications

    private var maxRecordedAmplitude: Double = 0

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkMilestones(event: ImpactEvent) {
        guard settings.notificationsEnabled else { return }

        let lifetime = settings.lifetimeSlaps
        let milestones = [1, 10, 50, 100, 500, 1000, 5000, 10000]

        if milestones.contains(lifetime) {
            sendNotification(
                title: lifetime == 1 ? L10n.tr("notif.firstSlap") : L10n.tr("notif.milestone", lifetime),
                body: lifetime == 1 ? L10n.tr("notif.firstSlap.body") : L10n.tr("notif.milestone.body", lifetime)
            )
        }

        // New amplitude record
        if event.amplitude > maxRecordedAmplitude && maxRecordedAmplitude > 0 {
            maxRecordedAmplitude = event.amplitude
            sendNotification(
                title: L10n.tr("notif.record"),
                body: String(format: L10n.tr("notif.record.body"), event.amplitude)
            )
        } else if event.amplitude > maxRecordedAmplitude {
            maxRecordedAmplitude = event.amplitude
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendAchievementNotification(_ achievement: Achievement) {
        guard settings.notificationsEnabled else { return }
        sendNotification(
            title: L10n.tr("notif.achievement"),
            body: L10n.tr("notif.achievement.body", achievement.title, achievement.description)
        )
        logger.log("Achievement unlocked: \(achievement.id)")
    }

    // MARK: - Impact Handling (called on @MainActor only when a slap is detected)

    private func handleDetectedImpact(_ event: ImpactEvent) {
        lastImpact = event
        slapCount += 1
        settings.lifetimeSlaps += 1

        // Visual feedback — flash the menu bar icon
        slapFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            slapFlash = false
        }

        // Record in history
        history.record(event, mode: settings.soundMode)

        // Broadcast to SSE clients
        let eventJSON = "{\"type\":\"slap\",\"amplitude\":\(event.amplitude),\"severity\":\"\(event.severity.rawValue)\",\"detectors\":\(event.detectorCount)}"
        mcpServer.broadcast(event: "slap", data: eventJSON)

        // Check milestones
        checkMilestones(event: event)

        // Leaderboard
        let record = history.records.last!
        leaderboard.submitSlap(record)
        let s = history.stats
        leaderboard.checkAchievements(
            lifetimeSlaps: settings.lifetimeSlaps,
            event: event,
            sessionSlaps: s.sessionSlaps,
            slapsPerMinute: s.slapsPerMinute
        )

        // Track amplitude for sparkline (last 20 impacts)
        recentAmplitudes.append(event.amplitude)
        if recentAmplitudes.count > 20 {
            recentAmplitudes.removeFirst()
        }

        // Skip sound if muted or Focus mode active
        if isMuted { return }
        if settings.respectFocus && isFocusModeActive { return }

        // Play sound
        guard let pack = currentPack,
              let index = slapTracker.selectSound(for: event, from: pack) else { return }

        let url = pack.urls[index]
        let amplitude = settings.volumeScaling ? event.amplitude : nil
        soundManager.play(url: url, amplitude: amplitude)
    }
}
