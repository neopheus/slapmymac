import Foundation

/// Thread-safe storage for MCP server snapshots.
/// Written from the main thread, read from the MCP server thread.
/// Synchronization is handled via a serial DispatchQueue.
final class MCPSnapshotStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "SlapMyMac.MCPSnapshot")
    private var _snapshot: [String: Any] = [:]
    private var _stats: [String: Any] = [:]
    private var _history: [[String: Any]] = []

    var snapshot: [String: Any] {
        queue.sync { _snapshot }
    }

    var stats: [String: Any] {
        queue.sync { _stats }
    }

    var history: [[String: Any]] {
        queue.sync { _history }
    }

    func update(snapshot: [String: Any], stats: [String: Any], history: [[String: Any]]) {
        queue.sync {
            self._snapshot = snapshot
            self._stats = stats
            self._history = history
        }
    }
}
