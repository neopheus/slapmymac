import Foundation

enum LidEvent: String, Sendable {
    case opened      // Lid opened (angle increased significantly)
    case closed      // Lid closed gently
    case slammed     // Lid closed with high velocity
    case creaking    // Lid moving slowly (continuous)
}

/// Detects lid open/close/slam events from angle and velocity data.
final class LidEventDetector {
    private var lastAngle: Double = 0
    private var lastEventTime: TimeInterval = 0
    private var wasOpen: Bool = true         // Assume lid starts open
    private var initialized = false

    // Thresholds
    private let openAngleThreshold: Double = 30    // Degrees — above = "open"
    private let closeAngleThreshold: Double = 15   // Degrees — below = "closed"
    private let slamVelocityThreshold: Double = 80 // Degrees/sec — above = slam
    private let creakVelocityRange: ClosedRange<Double> = 5...30
    private var eventCooldown: TimeInterval

    init(eventCooldown: TimeInterval = Constants.defaultLidEventCooldown) {
        self.eventCooldown = eventCooldown
    }

    func updateEventCooldown(_ value: TimeInterval) {
        eventCooldown = max(0.1, value)
    }

    /// Process angle + velocity, return a LidEvent if detected.
    func process(angle: Double, velocity: Double) -> LidEvent? {
        let now = ProcessInfo.processInfo.systemUptime

        guard initialized else {
            lastAngle = angle
            wasOpen = angle > openAngleThreshold
            initialized = true
            return nil
        }

        defer { lastAngle = angle }

        // Cooldown
        guard now - lastEventTime >= eventCooldown else { return nil }

        let isOpen = angle > openAngleThreshold
        let isClosed = angle < closeAngleThreshold

        // Detect transitions
        if !wasOpen && isOpen {
            // Was closed, now open → lid opened
            wasOpen = true
            lastEventTime = now
            return .opened
        }

        if wasOpen && isClosed {
            // Was open, now closed
            wasOpen = false
            lastEventTime = now
            if velocity > slamVelocityThreshold {
                return .slammed
            } else {
                return .closed
            }
        }

        // Creaking detection (lid moving slowly while open)
        if isOpen && creakVelocityRange.contains(velocity) {
            // Don't fire too often (2.5× the event cooldown)
            if now - lastEventTime >= eventCooldown * 2.5 {
                lastEventTime = now
                return .creaking
            }
        }

        return nil
    }

    func reset() {
        initialized = false
        lastAngle = 0
        lastEventTime = 0
        wasOpen = true
    }
}
