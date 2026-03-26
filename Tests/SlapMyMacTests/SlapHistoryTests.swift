import XCTest
@testable import SlapMyMac

final class SlapHistoryTests: XCTestCase {

    // MARK: - SlapRecord

    func testSlapRecordCreation() {
        let event = ImpactEvent(severity: .major, amplitude: 0.5, timestamp: 100, detectorCount: 3)
        let record = SlapRecord(event: event, mode: .pain)

        XCTAssertEqual(record.amplitude, 0.5)
        XCTAssertEqual(record.severity, "major")
        XCTAssertEqual(record.detectorCount, 3)
        XCTAssertEqual(record.soundMode, "pain")
        XCTAssertFalse(record.id.uuidString.isEmpty)
    }

    func testSlapRecordCodableRoundTrip() throws {
        let event = ImpactEvent(severity: .medium, amplitude: 0.3, timestamp: 50, detectorCount: 2)
        let record = SlapRecord(event: event, mode: .sexy)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SlapRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.amplitude, record.amplitude)
        XCTAssertEqual(decoded.severity, record.severity)
        XCTAssertEqual(decoded.detectorCount, record.detectorCount)
        XCTAssertEqual(decoded.soundMode, record.soundMode)
    }

    // MARK: - SlapHistory (MainActor)

    @MainActor
    func testRecordAddsToHistory() {
        let history = SlapHistory()
        history.clearHistory()

        let event = ImpactEvent(severity: .major, amplitude: 0.4, timestamp: 0, detectorCount: 4)
        history.record(event, mode: .halo)

        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.soundMode, "halo")
    }

    @MainActor
    func testStatsComputation() {
        let history = SlapHistory()
        history.clearHistory()
        history.resetSession()

        let events: [(ImpactSeverity, Double)] = [
            (.major, 0.5),
            (.major, 0.8),
            (.medium, 0.2),
        ]

        for (severity, amplitude) in events {
            let event = ImpactEvent(severity: severity, amplitude: amplitude, timestamp: 0, detectorCount: 3)
            history.record(event, mode: .pain)
        }

        let stats = history.stats
        XCTAssertEqual(stats.totalSlaps, 3)
        XCTAssertEqual(stats.majorCount, 2)
        XCTAssertEqual(stats.mediumCount, 1)
        XCTAssertEqual(stats.maxAmplitude, 0.8, accuracy: 0.001)
        XCTAssertEqual(stats.avgAmplitude, 0.5, accuracy: 0.001)
        XCTAssertEqual(stats.favoriteMode, "pain")
    }

    @MainActor
    func testRecentRecordsReturnsLastN() {
        let history = SlapHistory()
        history.clearHistory()

        for i in 0..<10 {
            let event = ImpactEvent(severity: .major, amplitude: Double(i) * 0.1, timestamp: 0, detectorCount: 1)
            history.record(event, mode: .pain)
        }

        let recent = history.recentRecords(3)
        XCTAssertEqual(recent.count, 3)
        // recentRecords returns last N reversed (most recent first)
        XCTAssertEqual(recent.first?.amplitude ?? 0, 0.9, accuracy: 0.001)
    }

    @MainActor
    func testClearHistoryRemovesAll() {
        let history = SlapHistory()

        let event = ImpactEvent(severity: .major, amplitude: 0.5, timestamp: 0, detectorCount: 2)
        history.record(event, mode: .pain)

        history.clearHistory()
        XCTAssertTrue(history.records.isEmpty)
    }
}
