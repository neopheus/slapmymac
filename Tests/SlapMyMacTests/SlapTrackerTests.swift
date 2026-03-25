import XCTest
@testable import SlapMyMac

final class SlapTrackerTests: XCTestCase {
    func testRandomModeSelectsValidIndex() {
        let tracker = SlapTracker()
        let pack = SoundPack(mode: .pain, urls: (0..<10).map {
            URL(fileURLWithPath: "/tmp/sound\($0).mp3")
        })

        for _ in 0..<100 {
            let event = ImpactEvent(severity: .major, amplitude: 0.1, timestamp: 0, detectorCount: 4)
            let index = tracker.selectSound(for: event, from: pack)
            XCTAssertNotNil(index)
            XCTAssertTrue(index! >= 0 && index! < pack.count)
        }
    }

    func testEscalationModeIncreasesOverTime() {
        let tracker = SlapTracker(halfLife: 30.0, escalationScale: 5.0)
        let pack = SoundPack(mode: .sexy, urls: (0..<60).map {
            URL(fileURLWithPath: "/tmp/\(String(format: "%02d", $0)).mp3")
        })

        var indices: [Int] = []
        for i in 0..<10 {
            let event = ImpactEvent(
                severity: .major,
                amplitude: 0.1,
                timestamp: TimeInterval(i) * 0.5,  // Rapid slaps
                detectorCount: 4
            )
            if let index = tracker.selectSound(for: event, from: pack) {
                indices.append(index)
            }
        }

        // Indices should generally increase with rapid consecutive slaps
        XCTAssertTrue(indices.count >= 5, "Should have selected sounds")
        if indices.count >= 3 {
            XCTAssertTrue(indices.last! > indices.first!, "Escalation should increase index over rapid slaps")
        }
    }

    func testEmptyPackReturnsNil() {
        let tracker = SlapTracker()
        let pack = SoundPack(mode: .pain, urls: [])
        let event = ImpactEvent(severity: .major, amplitude: 0.1, timestamp: 0, detectorCount: 4)
        XCTAssertNil(tracker.selectSound(for: event, from: pack))
    }

    func testResetClearsScore() {
        let tracker = SlapTracker(halfLife: 30.0, escalationScale: 5.0)
        let pack = SoundPack(mode: .sexy, urls: (0..<60).map {
            URL(fileURLWithPath: "/tmp/\(String(format: "%02d", $0)).mp3")
        })

        // Build up score
        for i in 0..<5 {
            let event = ImpactEvent(severity: .major, amplitude: 0.1, timestamp: TimeInterval(i), detectorCount: 4)
            _ = tracker.selectSound(for: event, from: pack)
        }

        tracker.reset()

        // After reset, first selection should be low index
        let event = ImpactEvent(severity: .major, amplitude: 0.1, timestamp: 100, detectorCount: 4)
        let index = tracker.selectSound(for: event, from: pack)
        XCTAssertNotNil(index)
        XCTAssertTrue(index! < 10, "After reset, escalation should start from low index")
    }
}
