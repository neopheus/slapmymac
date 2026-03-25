import Foundation
import IOKit
import IOKit.hid

/// Accesses the Apple Silicon BMI286 IMU via IOKit HID.
/// Runs a CFRunLoop on a dedicated background thread to receive sensor callbacks.
final class AccelerometerService: @unchecked Sendable {
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var continuation: AsyncStream<AccelerometerSample>.Continuation?
    private var sampleCounter: Int = 0
    private let decimationFactor = Constants.decimationFactor

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

        if let buf = reportBuffer {
            buf.deallocate()
            reportBuffer = nil
        }
        device = nil
        thread = nil
        runLoop = nil
    }

    // MARK: - Private

    private func runSensorLoop() {
        // Step 1: Wake SPU drivers
        guard wakeSPUDrivers() else {
            errorMessage = "Failed to wake SPU drivers. Apple Silicon laptop required."
            continuation?.finish()
            return
        }

        // Step 2: Find accelerometer device
        guard let accelDevice = findAccelerometerDevice() else {
            errorMessage = "No accelerometer found. Apple Silicon laptop required."
            continuation?.finish()
            return
        }

        // Step 3: Open device
        let openResult = IOHIDDeviceOpen(accelDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            errorMessage = "Cannot open accelerometer (error \(openResult)). Try running with sudo."
            continuation?.finish()
            return
        }

        self.device = accelDevice

        // Step 4: Allocate report buffer and register callback
        let bufSize = Constants.reportSize
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        buf.initialize(repeating: 0, count: bufSize)
        self.reportBuffer = buf

        // We need to pass self to the C callback. Use Unmanaged to get a pointer.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(
            accelDevice,
            buf,
            CFIndex(bufSize),
            { context, result, sender, type, reportID, report, reportLength in
                guard let ctx = context else { return }
                let service = Unmanaged<AccelerometerService>.fromOpaque(ctx).takeUnretainedValue()
                service.handleReport(report: report, length: Int(reportLength))
            },
            selfPtr
        )

        // Step 5: Schedule on this thread's run loop and run
        IOHIDDeviceScheduleWithRunLoop(accelDevice, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        self.runLoop = CFRunLoopGetCurrent()
        self.isRunning = true

        CFRunLoopRun()

        // Cleanup when run loop stops
        IOHIDDeviceUnscheduleFromRunLoop(accelDevice, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(accelDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func handleReport(report: UnsafeMutablePointer<UInt8>, length: Int) {
        guard length >= Constants.reportSize else { return }

        // Decimate: keep 1 in N samples
        sampleCounter += 1
        guard sampleCounter % decimationFactor == 0 else { return }

        // Parse Int32 LE at offsets 6, 10, 14
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

    // MARK: - IOKit Device Discovery

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
            let reportingState: CFNumber = 1 as CFNumber
            let powerState: CFNumber = 1 as CFNumber
            let reportInterval: CFNumber = 1000 as CFNumber

            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, reportingState)
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, powerState)
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, reportInterval)

            foundAny = true
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return foundAny
    }

    private func findAccelerometerDevice() -> IOHIDDevice? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") as NSMutableDictionary? else {
            return nil
        }
        matching["PrimaryUsagePage"] = Constants.spuUsagePage
        matching["PrimaryUsage"] = Constants.spuAccelerometerUsage

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching as CFDictionary, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        return IOHIDDeviceCreate(kCFAllocatorDefault, service)
    }
}
