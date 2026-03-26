import Foundation
import IOKit
import IOKit.hid
import QuartzCore

/// Reads the MacBook lid angle sensor via IOKit HID feature reports.
/// Ported from https://github.com/samhenrigold/LidAngleSensor
///
/// This class does NOT own a timer. The caller (AppState) drives polling
/// by calling `pollOnce()` at the desired frequency, avoiding duplicate timers.
@MainActor
final class LidAngleSensor: ObservableObject {
    private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    // Published state — only updated when values actually change
    @Published var angle: Double = 0
    @Published var velocity: Double = 0
    @Published var isAvailable: Bool = false
    @Published var isRunning: Bool = false

    // Private state
    private var hidDevice: IOHIDDevice?
    private var hidReport = [UInt8](repeating: 0, count: 8)
    private var isDeviceOpen = false

    // Smoothing state
    private var smoothedAngle: Double = 0
    private var lastAngle: Double = 0
    private var lastTime: TimeInterval = 0
    private var smoothedVelocity: Double = 0
    private var lastMovementTime: TimeInterval = 0
    private var consecutiveMovementFrames: Int = 0

    // Configurable parameters
    var angleSmoothingTau: Double = Constants.defaultAngleSmoothingTau
    var velocitySmoothingTau: Double = Constants.defaultVelocitySmoothingTau

    init() {
        probe()
    }

    deinit {
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

    /// Open the HID device for reading. Call once before pollOnce().
    func start() {
        guard isAvailable, !isDeviceOpen, let device = hidDevice else { return }

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

        isRunning = true
        print("[LidAngle] Sensor opened, ready for polling")
    }

    func stop() {
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
            isDeviceOpen = false
        }
        isRunning = false
    }

    // MARK: - Polling (driven by caller)

    /// Read the sensor once and update smoothed angle/velocity.
    /// Returns the current smoothed velocity (useful for adaptive polling).
    @discardableResult
    func pollOnce() -> Double {
        guard isDeviceOpen, let rawAngle = readRawAngle() else { return 0 }
        updateSmoothedValues(rawAngle: rawAngle)
        return smoothedVelocity
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

        // Only publish when values actually changed (avoids redundant SwiftUI redraws)
        if abs(smoothedAngle - angle) > 0.1 {
            angle = smoothedAngle
        }
        if abs(smoothedVelocity - velocity) > 0.5 {
            velocity = smoothedVelocity
        }
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
