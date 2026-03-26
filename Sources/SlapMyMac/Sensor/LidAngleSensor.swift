import Foundation
import IOKit
import IOKit.hid
import QuartzCore

/// Reads the MacBook lid angle sensor via IOKit HID feature reports.
/// Ported from https://github.com/samhenrigold/LidAngleSensor
@MainActor
final class LidAngleSensor: ObservableObject {
    private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    // Published state
    @Published var angle: Double = 0
    @Published var velocity: Double = 0
    @Published var isAvailable: Bool = false
    @Published var isRunning: Bool = false

    // Private state
    private var hidDevice: IOHIDDevice?
    private var hidReport = [UInt8](repeating: 0, count: 8)
    private var timer: Timer?
    private var isDeviceOpen = false

    // Smoothing state
    private var smoothedAngle: Double = 0
    private var lastAngle: Double = 0
    private var lastTime: TimeInterval = 0
    private var smoothedVelocity: Double = 0
    private var lastMovementTime: TimeInterval = 0
    private var consecutiveMovementFrames: Int = 0

    // Configurable parameters (set before start)
    var pollHz: Double = Constants.defaultLidPollHz
    var angleSmoothingTau: Double = Constants.defaultAngleSmoothingTau
    var velocitySmoothingTau: Double = Constants.defaultVelocitySmoothingTau

    // Fixed parameters
    private let velocityDecay: Double = 0.5
    private let movementTimeout: TimeInterval = 0.05

    init() {
        probe()
    }

    deinit {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    /// Check if the lid angle sensor is available on this Mac.
    func probe() {
        // Strategy 1: Standard Sensor page (0x0020) + Orientation usage (0x008A / 138)
        if let device = findHIDDevice(usagePage: 0x0020, usage: 0x008A) {
            self.hidDevice = device
            self.isAvailable = true
            return
        }

        // Strategy 2: Check if vendor-specific SPU device exists with product ID 0x8104
        if let device = findHIDDevice(usagePage: 0x0020, usage: 138) {
            self.hidDevice = device
            self.isAvailable = true
            return
        }

        self.isAvailable = false
    }

    func start() {
        guard isAvailable, timer == nil, let device = hidDevice else { return }

        let openResult = IOHIDDeviceOpen(device, Self.noOptions)
        guard openResult == kIOReturnSuccess else {
            print("[LidAngle] Failed to open device: \(openResult)")
            return
        }
        isDeviceOpen = true

        // Initialize smoothing state
        if let initialAngle = readRawAngle() {
            smoothedAngle = initialAngle
            lastAngle = initialAngle
            lastTime = CACurrentMediaTime()
            angle = initialAngle
        }

        let interval = 1.0 / max(1, pollHz)
        timer = .scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.poll() }
        }
        isRunning = true
        print("[LidAngle] Sensor started, polling at \(Int(pollHz)) Hz")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
            isDeviceOpen = false
        }
        isRunning = false
    }

    /// Restart the sensor with current settings (call after changing pollHz or smoothing params).
    func restart() {
        guard isAvailable else { return }
        let wasRunning = isRunning
        if wasRunning { stop() }
        if wasRunning { start() }
    }

    // MARK: - Polling

    private func poll() {
        guard let rawAngle = readRawAngle() else { return }
        updateSmoothedValues(rawAngle: rawAngle)
    }

    private func readRawAngle() -> Double? {
        guard let device = hidDevice else { return nil }

        var length = CFIndex(hidReport.count)
        let result = IOHIDDeviceGetReport(
            device,
            kIOHIDReportTypeFeature,
            1,  // Report ID
            &hidReport,
            &length
        )

        guard result == kIOReturnSuccess, length >= 3 else { return nil }

        // Parse 16-bit angle from bytes 1-2 (little-endian), mask to 9 bits
        let rawValue = UInt16(hidReport[2]) << 8 | UInt16(hidReport[1])
        let masked = rawValue & 0x1FF  // 9-bit value (0-511)
        return Double(masked)
    }

    private func updateSmoothedValues(rawAngle: Double) {
        let now = CACurrentMediaTime()
        let dt = now - lastTime
        guard dt > 0 else { return }

        // Time-constant-based EMA (dt-independent, consistent regardless of poll rate)
        let angleAlpha = 1.0 - exp(-dt / max(0.001, angleSmoothingTau))
        smoothedAngle = angleAlpha * rawAngle + (1.0 - angleAlpha) * smoothedAngle

        // Calculate velocity — with noise gate to reject sensor jitter
        let delta = smoothedAngle - lastAngle
        // The sensor is 9-bit (integer degrees). A delta < 1.0° is noise.
        let instantVelocity = abs(delta) < 1.0 ? 0.0 : abs(delta / dt)

        let velAlpha = 1.0 - exp(-dt / max(0.001, velocitySmoothingTau))

        if instantVelocity > 0 {
            // Require consecutive movement frames to avoid single-spike activation
            consecutiveMovementFrames += 1
            if consecutiveMovementFrames >= 2 {
                smoothedVelocity = velAlpha * instantVelocity + (1.0 - velAlpha) * smoothedVelocity
                lastMovementTime = now
            }
        } else {
            consecutiveMovementFrames = 0
            // Gradual decay — lets the creak audio fade out smoothly
            smoothedVelocity *= 0.5
        }

        // After 200ms of no movement, decay faster and cut below threshold
        if now - lastMovementTime > 0.20 {
            smoothedVelocity *= 0.3
        }
        // Velocity must exceed 2°/s to be published — below is sensor noise
        if smoothedVelocity < 2.0 {
            smoothedVelocity = 0
        }

        lastAngle = smoothedAngle
        lastTime = now

        // Publish
        angle = smoothedAngle
        velocity = smoothedVelocity
    }

    // MARK: - Device Discovery

    private func findHIDDevice(usagePage: Int, usage: Int) -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, Self.noOptions)
        defer { IOHIDManagerClose(manager, Self.noOptions) }

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,      // Apple
            kIOHIDProductIDKey as String: 0x8104,     // SPU device
            "PrimaryUsagePage": usagePage,
            "PrimaryUsage": usage,
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerOpen(manager, Self.noOptions)

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }

        for device in devices {
            // Test: can we read a feature report from this device?
            let openResult = IOHIDDeviceOpen(device, Self.noOptions)
            guard openResult == kIOReturnSuccess else { continue }

            var testReport = [UInt8](repeating: 0, count: 8)
            var testLength = CFIndex(testReport.count)
            let readResult = IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                1,
                &testReport,
                &testLength
            )

            IOHIDDeviceClose(device, Self.noOptions)

            if readResult == kIOReturnSuccess, testLength >= 3 {
                return device
            }
        }

        return nil
    }
}
