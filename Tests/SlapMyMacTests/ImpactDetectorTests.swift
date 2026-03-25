import XCTest
@testable import SlapMyMac

final class ImpactDetectorTests: XCTestCase {
    var detector: ImpactDetector!

    override func setUp() {
        detector = ImpactDetector(sensitivity: 0.05, cooldownMs: 100)
    }

    func testQuietSamplesProduceNoEvent() {
        // Simulate stationary accelerometer (just gravity on Z)
        for i in 0..<500 {
            let sample = AccelerometerSample(
                x: 0.001 * Double.random(in: -1...1),
                y: 0.001 * Double.random(in: -1...1),
                z: 1.0 + 0.001 * Double.random(in: -1...1),
                timestamp: TimeInterval(i) / 100.0
            )
            let event = detector.process(sample)
            // After warmup, quiet samples shouldn't trigger
            if i > 300 {
                XCTAssertNil(event, "Quiet sample at index \(i) should not trigger an event")
            }
        }
    }

    func testLargeSpikeTriggersEvent() {
        // Warm up with quiet samples
        for i in 0..<300 {
            let sample = AccelerometerSample(
                x: 0.0, y: 0.0, z: 1.0,
                timestamp: TimeInterval(i) / 100.0
            )
            _ = detector.process(sample)
        }

        // Inject a large spike (simulating a slap)
        let slapSample = AccelerometerSample(
            x: 2.0, y: 1.5, z: 3.0,
            timestamp: 3.01
        )
        let event = detector.process(slapSample)

        // The spike should eventually trigger an event
        // (may take a couple samples for all detectors to fire)
        if event == nil {
            // Try one more follow-up sample
            let followUp = AccelerometerSample(
                x: 1.0, y: 0.5, z: 1.5,
                timestamp: 3.02
            )
            let event2 = detector.process(followUp)
            XCTAssertNotNil(event2, "A large spike should trigger an impact event")
        }
    }

    func testCooldownPreventsRapidEvents() {
        detector = ImpactDetector(sensitivity: 0.001, cooldownMs: 500)

        // Warm up
        for i in 0..<300 {
            let sample = AccelerometerSample(x: 0, y: 0, z: 1.0, timestamp: TimeInterval(i) / 100.0)
            _ = detector.process(sample)
        }

        // First spike
        let spike1 = AccelerometerSample(x: 3.0, y: 3.0, z: 3.0, timestamp: 3.0)
        let event1 = detector.process(spike1)

        // Second spike within cooldown (200ms later)
        let spike2 = AccelerometerSample(x: 3.0, y: 3.0, z: 3.0, timestamp: 3.2)
        let event2 = detector.process(spike2)

        // At most one event should fire due to cooldown
        if event1 != nil {
            XCTAssertNil(event2, "Second spike within cooldown should not trigger")
        }
    }

    func testResetClearsState() {
        // Process some samples
        for i in 0..<100 {
            let sample = AccelerometerSample(x: 0, y: 0, z: 1.0, timestamp: TimeInterval(i) / 100.0)
            _ = detector.process(sample)
        }

        detector.reset()

        // After reset, first sample should not trigger (buffers empty)
        let sample = AccelerometerSample(x: 0, y: 0, z: 1.0, timestamp: 0)
        let event = detector.process(sample)
        XCTAssertNil(event)
    }
}
