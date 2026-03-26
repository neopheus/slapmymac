import Foundation
import IOKit
import IOKit.hid

/// Accesses the Apple Silicon BMI286 IMU via IOKit HID.
/// Uses IOHIDManager for reliable device discovery and input report callbacks
/// on a dedicated background thread for high-frequency data.
final class AccelerometerService: @unchecked Sendable {
    private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var continuation: AsyncStream<AccelerometerSample>.Continuation?
    private var sampleCounter: Int = 0
    var decimationFactor: Int = Constants.defaultDecimationFactor

    private(set) var isRunning = false
    private(set) var errorMessage: String?

    deinit {
        stop()
    }

    /// Returns an AsyncStream of accelerometer samples (decimated to ~100Hz).
    func start() -> AsyncStream<AccelerometerSample> {
        let stream = AsyncStream<AccelerometerSample> { continuation in
            self.continuation = continuation
        }

        thread = Thread {
            self.runSensorLoop()
        }
        thread?.name = "SlapMyMac.Accelerometer"
        thread?.qualityOfService = .userInteractive
        thread?.start()

        return stream
    }

    func stop() {
        if let rl = runLoop {
            CFRunLoopStop(rl)
        }
        continuation?.finish()
        continuation = nil
        isRunning = false

        if let dev = device {
            IOHIDDeviceClose(dev, Self.noOptions)
            device = nil
        }
        if let mgr = manager {
            IOHIDManagerClose(mgr, Self.noOptions)
            manager = nil
        }
        if let buf = reportBuffer {
            buf.deallocate()
            reportBuffer = nil
        }
        thread = nil
        runLoop = nil
    }

    // MARK: - Sensor Loop (runs on dedicated thread)

    private func runSensorLoop() {
        // Step 1: Wake ALL SPU drivers first
        let driversWoken = wakeSPUDrivers()
        if !driversWoken {
            // Non-fatal: some systems may work without explicit wake
            print("[SlapMyMac] Warning: Could not wake SPU drivers")
        }

        // Step 2: Find and open accelerometer using IOHIDManager (then fallback)
        let accelDevice: IOHIDDevice
        if let primary = findAndOpenAccelerometer() {
            accelDevice = primary
        } else if let fallback = findAccelerometerViaServiceMatching() {
            accelDevice = fallback
        } else {
            errorMessage = "No accelerometer found. Apple Silicon laptop required."
            continuation?.finish()
            return
        }

        self.device = accelDevice
        let dev = accelDevice

        // Step 3: Allocate report buffer — use larger buffer to handle variable report sizes
        let bufSize = 64
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        buf.initialize(repeating: 0, count: bufSize)
        self.reportBuffer = buf

        // Step 4: Register input report callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(
            dev,
            buf,
            CFIndex(bufSize),
            { context, result, sender, type, reportID, report, reportLength in
                guard let ctx = context else { return }
                let service = Unmanaged<AccelerometerService>.fromOpaque(ctx).takeUnretainedValue()
                service.handleReport(report: report, length: Int(reportLength))
            },
            selfPtr
        )

        // Step 5: Schedule on this thread's run loop
        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        self.runLoop = CFRunLoopGetCurrent()
        self.isRunning = true

        print("[SlapMyMac] Accelerometer started, listening for impacts...")

        // Run the loop — blocks until stop() calls CFRunLoopStop
        CFRunLoopRun()

        // Cleanup
        IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(dev, Self.noOptions)
    }

    private func handleReport(report: UnsafeMutablePointer<UInt8>, length: Int) {
        // IMU reports are 22 bytes; ignore shorter reports
        guard length >= Constants.reportSize else { return }

        // Decimate: keep 1 in N samples (~800Hz → ~100Hz)
        sampleCounter += 1
        guard sampleCounter % decimationFactor == 0 else { return }

        // Parse Int32 LE at offsets 6, 10, 14 and convert to g-force
        let rawX = readInt32LE(from: report, at: Constants.xOffset)
        let rawY = readInt32LE(from: report, at: Constants.yOffset)
        let rawZ = readInt32LE(from: report, at: Constants.zOffset)

        let sample = AccelerometerSample(
            x: Double(rawX) / Constants.rawToGForce,
            y: Double(rawY) / Constants.rawToGForce,
            z: Double(rawZ) / Constants.rawToGForce,
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        continuation?.yield(sample)
    }

    private func readInt32LE(from buffer: UnsafeMutablePointer<UInt8>, at offset: Int) -> Int32 {
        var value: Int32 = 0
        withUnsafeMutableBytes(of: &value) { dest in
            dest.copyBytes(from: UnsafeBufferPointer(start: buffer.advanced(by: offset), count: 4))
        }
        return Int32(littleEndian: value)
    }

    // MARK: - IOHIDManager-based Device Discovery (primary approach)

    private func findAndOpenAccelerometer() -> IOHIDDevice? {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, Self.noOptions)
        self.manager = mgr

        // Match Apple SPU devices — vendor-specific accelerometer
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,        // Apple
            kIOHIDProductIDKey as String: 0x8104,       // SPU HID device
            "PrimaryUsagePage": Constants.spuUsagePage,  // 0xFF00
            "PrimaryUsage": Constants.spuAccelerometerUsage,  // 3
        ]

        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)
        IOHIDManagerOpen(mgr, Self.noOptions)

        guard let devices = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else {
            // Try broader matching — just Apple SPU, check usage manually
            return findAccelerometerBroadMatch(mgr)
        }

        for dev in devices {
            let result = IOHIDDeviceOpen(dev, Self.noOptions)
            if result == kIOReturnSuccess {
                print("[SlapMyMac] Found accelerometer via IOHIDManager (matched \(devices.count) device(s))")
                return dev
            }
        }

        // Fall back to broader matching
        return findAccelerometerBroadMatch(mgr)
    }

    /// Broader match: find ALL AppleSPUHIDDevice entries, check usage manually
    private func findAccelerometerBroadMatch(_ mgr: IOHIDManager) -> IOHIDDevice? {
        // Try matching just by vendor
        let broadMatching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
        ]

        IOHIDManagerSetDeviceMatching(mgr, broadMatching as CFDictionary)

        guard let devices = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else {
            print("[SlapMyMac] No Apple SPU HID devices found at all")
            return nil
        }

        print("[SlapMyMac] Found \(devices.count) Apple SPU device(s), checking for accelerometer...")

        for dev in devices {
            // Check usage page and usage
            let usagePage = IOHIDDeviceGetProperty(dev, "PrimaryUsagePage" as CFString)
            let usage = IOHIDDeviceGetProperty(dev, "PrimaryUsage" as CFString)

            var upVal: Int = 0
            var uVal: Int = 0

            if let up = usagePage as? Int { upVal = up }
            if let u = usage as? Int { uVal = u }

            print("[SlapMyMac]   Device: UsagePage=0x\(String(upVal, radix: 16)), Usage=\(uVal)")

            if upVal == Constants.spuUsagePage && uVal == Constants.spuAccelerometerUsage {
                let result = IOHIDDeviceOpen(dev, Self.noOptions)
                if result == kIOReturnSuccess {
                    print("[SlapMyMac] Found accelerometer via broad match!")
                    return dev
                } else {
                    print("[SlapMyMac]   Failed to open: \(result)")
                }
            }
        }

        // Last resort: try any vendor-specific device (0xFF00)
        for dev in devices {
            let usagePage = IOHIDDeviceGetProperty(dev, "PrimaryUsagePage" as CFString) as? Int ?? 0
            if usagePage == Constants.spuUsagePage {
                let result = IOHIDDeviceOpen(dev, Self.noOptions)
                if result == kIOReturnSuccess {
                    print("[SlapMyMac] Using first vendor-specific SPU device as accelerometer")
                    return dev
                }
            }
        }

        return nil
    }

    // MARK: - Fallback: Direct IOService matching

    private func findAccelerometerViaServiceMatching() -> IOHIDDevice? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return nil }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Check properties manually
            if let props = getServiceProperties(service) {
                let usagePage = props["PrimaryUsagePage"] as? Int ?? 0
                let usage = props["PrimaryUsage"] as? Int ?? 0

                print("[SlapMyMac] IOService: UsagePage=0x\(String(usagePage, radix: 16)), Usage=\(usage)")

                if usagePage == Constants.spuUsagePage && usage == Constants.spuAccelerometerUsage {
                    let dev = IOHIDDeviceCreate(kCFAllocatorDefault, service)
                    IOObjectRelease(service)

                    if let device = dev {
                        let openResult = IOHIDDeviceOpen(device, Self.noOptions)
                        if openResult == kIOReturnSuccess {
                            print("[SlapMyMac] Found accelerometer via IOService fallback!")
                            return device
                        }
                    }
                    continue
                }
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return nil
    }

    private func getServiceProperties(_ service: io_service_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return props
    }

    // MARK: - Wake SPU Drivers

    private func wakeSPUDrivers() -> Bool {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return false }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        var foundAny = false
        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Set properties to wake the driver
            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, 1000 as CFNumber)

            foundAny = true
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        if foundAny {
            // Give drivers a moment to wake up
            Thread.sleep(forTimeInterval: 0.1)
        }

        return foundAny
    }
}
