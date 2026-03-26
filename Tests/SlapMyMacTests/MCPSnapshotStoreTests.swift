import XCTest
@testable import SlapMyMac

final class MCPSnapshotStoreTests: XCTestCase {

    func testInitialStateIsEmpty() {
        let store = MCPSnapshotStore()
        XCTAssertTrue(store.snapshot.isEmpty)
        XCTAssertTrue(store.stats.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
    }

    func testUpdateAndRead() {
        let store = MCPSnapshotStore()

        let snapshot: [String: Any] = ["listening": true, "slapCount": 42]
        let stats: [String: Any] = ["totalSlaps": 42, "avgAmplitude": 0.3]
        let history: [[String: Any]] = [["id": "abc", "amplitude": 0.5]]

        store.update(snapshot: snapshot, stats: stats, history: history)

        XCTAssertEqual(store.snapshot["slapCount"] as? Int, 42)
        XCTAssertEqual(store.snapshot["listening"] as? Bool, true)
        XCTAssertEqual(store.stats["totalSlaps"] as? Int, 42)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.history.first?["id"] as? String, "abc")
    }

    func testUpdateReplacesOldData() {
        let store = MCPSnapshotStore()

        store.update(
            snapshot: ["slapCount": 1],
            stats: ["totalSlaps": 1],
            history: []
        )

        store.update(
            snapshot: ["slapCount": 99],
            stats: ["totalSlaps": 99],
            history: [["id": "new"]]
        )

        XCTAssertEqual(store.snapshot["slapCount"] as? Int, 99)
        XCTAssertEqual(store.stats["totalSlaps"] as? Int, 99)
        XCTAssertEqual(store.history.count, 1)
    }

    func testConcurrentReadWriteDoesNotCrash() {
        let store = MCPSnapshotStore()
        let iterations = 1000
        let expectation = expectation(description: "Concurrent access completes")
        expectation.expectedFulfillmentCount = 2

        // Writer thread
        DispatchQueue.global().async {
            for i in 0..<iterations {
                store.update(
                    snapshot: ["count": i],
                    stats: ["total": i],
                    history: [["index": i]]
                )
            }
            expectation.fulfill()
        }

        // Reader thread
        DispatchQueue.global().async {
            for _ in 0..<iterations {
                _ = store.snapshot
                _ = store.stats
                _ = store.history
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        // Final state should be consistent
        let finalCount = store.snapshot["count"] as? Int ?? -1
        XCTAssertEqual(finalCount, iterations - 1)
    }
}
