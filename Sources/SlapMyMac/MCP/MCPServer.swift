import Foundation

/// Lightweight local HTTP server that exposes SlapMyMac state and controls.
/// Enables MCP-style integration: AI tools, scripts, and webhooks can trigger slaps
/// or read slap data. Listens on localhost:7749.
///
/// Endpoints:
///   GET  /status     → current state (listening, slapCount, lastImpact, lidAngle)
///   GET  /stats      → slap statistics
///   GET  /history    → recent slap records (JSON)
///   POST /trigger    → trigger a sound manually (body: {"mode": "pain"})
///   POST /mode       → change sound mode (body: {"mode": "sexy"})
///
/// This enables the "MCP server integration" roadmap item:
/// scripts and AI agents can make your Mac react to external events.
final class MCPServer {
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let port: UInt16 = 7749
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "SlapMyMac.MCPServer", attributes: .concurrent)

    // Callbacks to get/set app state
    var getStatus: (() -> [String: Any])?
    var getStats: (() -> [String: Any])?
    var getHistory: (() -> [[String: Any]])?
    var triggerSound: ((String) -> Void)?
    var setMode: ((String) -> Void)?

    private var sseClients: [Int32] = []
    private let sseLock = NSLock()

    /// Whether any SSE clients are connected (thread-safe).
    var hasClients: Bool {
        sseLock.lock()
        let result = !sseClients.isEmpty
        sseLock.unlock()
        return result
    }

    func start() {
        guard !isRunning else { return }

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            print("[MCP] Failed to create socket")
            return
        }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            print("[MCP] Failed to bind to port \(port): \(String(cString: strerror(errno)))")
            close(sock)
            return
        }

        listen(sock, 128)
        self.serverSocket = sock
        isRunning = true
        print("[MCP] Server listening on http://localhost:\(port)")

        // Use GCD dispatch source for non-blocking accept
        let source = DispatchSource.makeReadSource(fileDescriptor: sock, queue: serverQueue)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }

            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSock = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(sock, sockPtr, &clientLen)
                }
            }
            guard clientSock >= 0 else { return }

            self.serverQueue.async {
                self.handleConnection(clientSock)
            }
        }
        source.setCancelHandler {
            close(sock)
        }
        self.acceptSource = source
        source.resume()
    }

    func stop() {
        isRunning = false
        acceptSource?.cancel()
        acceptSource = nil
        serverSocket = -1

        // Close SSE clients
        sseLock.lock()
        for sock in sseClients {
            Darwin.close(sock)
        }
        sseClients.removeAll()
        sseLock.unlock()
    }

    // MARK: - Request Handling

    private func handleConnection(_ sock: Int32) {
        // Set timeouts
        var tv = timeval(tv_sec: 0, tv_usec: 500_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(sock, &buffer, buffer.count)

        if bytesRead <= 0 {
            Darwin.close(sock)
            return
        }

        let request = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""

        // Parse first line
        let lines = request.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")

        let method = parts.count >= 1 ? String(parts[0]) : "GET"
        let path = parts.count >= 2 ? String(parts[1]) : "/"

        // Extract body for POST
        var body = ""
        if let range = request.range(of: "\r\n\r\n") {
            body = String(request[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Route and build response
        let (status, responseBody) = routeRequest(method: method, path: path, body: body)

        // Write response as raw bytes
        let httpResponse = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.utf8.count)\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n\(responseBody)"

        // SSE: keep connection open for event streaming
        if status == "SSE" {
            let sseHeader = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
            let headerBytes = Array(sseHeader.utf8)
            headerBytes.withUnsafeBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    _ = Darwin.write(sock, base, ptr.count)
                }
            }
            sseLock.lock()
            sseClients.append(sock)
            sseLock.unlock()
            return  // Don't close the socket
        }

        let responseBytes = Array(httpResponse.utf8)
        responseBytes.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = Darwin.write(sock, base, ptr.count)
            }
        }

        Darwin.shutdown(sock, SHUT_RDWR)
        Darwin.close(sock)
    }

    private func routeRequest(method: String, path: String, body: String) -> (String, String) {
        switch (method, path) {
        case ("GET", "/status"):
            let status = getStatus?() ?? ["error": "not available"]
            return ("200 OK", jsonString(status))

        case ("GET", "/stats"):
            let stats = getStats?() ?? ["error": "not available"]
            return ("200 OK", jsonString(stats))

        case ("GET", "/history"):
            let history = getHistory?() ?? []
            return ("200 OK", jsonArrayString(history))

        case ("POST", "/trigger"):
            let mode = parseJSON(body)?["mode"] as? String ?? "pain"
            triggerSound?(mode)
            return ("200 OK", "{\"ok\":true,\"triggered\":\"\(mode)\"}")

        case ("POST", "/mode"):
            let mode = parseJSON(body)?["mode"] as? String ?? "pain"
            setMode?(mode)
            return ("200 OK", "{\"ok\":true,\"mode\":\"\(mode)\"}")

        case ("GET", "/events"):
            // SSE endpoint — keep connection alive
            return ("SSE", "")

        case ("OPTIONS", _):
            return ("200 OK", "")

        default:
            let help: [String: Any] = [
                "name": "SlapMyMac MCP Server",
                "version": "1.0",
                "endpoints": [
                    "GET /status": "Current app state",
                    "GET /stats": "Slap statistics",
                    "GET /history": "Recent slap records",
                    "POST /trigger": "Trigger a sound {\"mode\":\"pain\"}",
                    "POST /mode": "Change sound mode {\"mode\":\"sexy\"}",
                    "GET /events": "Server-Sent Events stream (real-time)",
                ]
            ]
            return ("200 OK", jsonString(help))
        }
    }

    // MARK: - JSON Helpers

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func jsonString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func jsonArrayString(_ array: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    /// Broadcast an event to all connected SSE clients.
    func broadcast(event: String, data: String) {
        let message = "event: \(event)\ndata: \(data)\n\n"
        let bytes = Array(message.utf8)

        sseLock.lock()
        var disconnected: [Int] = []

        for (index, sock) in sseClients.enumerated() {
            let written = bytes.withUnsafeBufferPointer { ptr -> Int in
                guard let base = ptr.baseAddress else { return -1 }
                return Darwin.write(sock, base, ptr.count)
            }
            if written <= 0 {
                Darwin.close(sock)
                disconnected.append(index)
            }
        }

        for index in disconnected.reversed() {
            sseClients.remove(at: index)
        }
        sseLock.unlock()
    }
}
