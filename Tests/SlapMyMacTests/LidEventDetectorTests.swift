import XCTest
@testable import SlapMyMac

final class LidEventDetectorTests: XCTestCase {
    var detector: LidEventDetector!

    override func setUp() {
        detector = LidEventDetector()
    }

    func testFirstCallInitializesAndReturnsNil() {
        let event = detector.process(angle: 90, velocity: 0)
        XCTAssertNil(event, "First call should initialize state, not produce an event")
    }

    func testClosingLidFromOpenDetectsClosed() {
        // Initialize with open lid
        _ = detector.process(angle: 90, velocity: 0)

        // Close the lid gently (below closeAngleThreshold=15, velocity below slam=80)
        let event = detector.process(angle: 10, velocity: 20)
        XCTAssertEqual(event, .closed)
    }

    func testSlamDetectedWithHighVelocity() {
        // Initialize with open lid
        _ = detector.process(angle: 90, velocity: 0)

        // Slam the lid shut (below closeAngleThreshold=15, velocity above slamThreshold=80)
        let event = detector.process(angle: 5, velocity: 100)
        XCTAssertEqual(event, .slammed)
    }

    func testOpeningLidFromClosedDetectsOpened() {
        // Initialize closed
        _ = detector.process(angle: 10, velocity: 0)

        // Open the lid (above openAngleThreshold=30)
        let event = detector.process(angle: 90, velocity: 10)
        XCTAssertEqual(event, .opened)
    }

    func testCooldownPreventsRapidEvents() {
        // Initialize open
        _ = detector.process(angle: 90, velocity: 0)

        // Close lid
        let event1 = detector.process(angle: 10, velocity: 20)
        XCTAssertEqual(event1, .closed)

        // Try to immediately open — should be blocked by 2s cooldown
        let event2 = detector.process(angle: 90, velocity: 10)
        XCTAssertNil(event2, "Event within cooldown should be suppressed")
    }

    func testNoEventInMiddleRange() {
        // Initialize open
        _ = detector.process(angle: 90, velocity: 0)

        // Stay in middle range (between close=15 and open=30 thresholds)
        let event = detector.process(angle: 20, velocity: 5)
        XCTAssertNil(event, "Angle in middle range should not trigger open/close")
    }

    func testResetClearsState() {
        // Initialize
        _ = detector.process(angle: 90, velocity: 0)

        detector.reset()

        // After reset, next call should re-initialize (return nil)
        let event = detector.process(angle: 10, velocity: 100)
        XCTAssertNil(event, "After reset, first call should re-initialize")
    }
}
