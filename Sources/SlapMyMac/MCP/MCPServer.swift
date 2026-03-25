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
    private var listener: Any?  // NWListener when Network framework is used
    private let port: UInt16 = 7749
    private var isRunning = false

    // Callbacks to get/set app state
    var getStatus: (() -> [String: Any])?
    var getStats: (() -> [String: Any])?
    var getHistory: (() -> [[String: Any]])?
    var triggerSound: ((String) -> Void)?
    var setMode: ((String) -> Void)?

    func start() {
        guard !isRunning else { return }

        // Use a simple socket-based HTTP server via GCD
        let serverQueue = DispatchQueue(label: "SlapMyMac.MCPServer")

        let socket = socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            print("[MCP] Failed to create socket")
            return
        }

        var yes: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian  // localhost only

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            print("[MCP] Failed to bind to port \(port)")
            close(socket)
            return
        }

        listen(socket, 5)
        isRunning = true
        print("[MCP] Server listening on http://localhost:\(port)")

        serverQueue.async { [weak self] in
            while self?.isRunning == true {
                var clientAddr = sockaddr_in()
                var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                        accept(socket, sockPtr, &clientLen)
                    }
                }
                guard clientSocket >= 0 else { continue }

                serverQueue.async { [weak self] in
                    self?.handleConnection(clientSocket)
                }
            }
            close(socket)
        }
    }

    func stop() {
        isRunning = false
    }

    // MARK: - Request Handling

    private func handleConnection(_ sock: Int32) {
        defer {
            shutdown(sock, SHUT_RDWR)
            close(sock)
        }

        // Set 1s read timeout so keep-alive connections don't block forever
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(sock, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let request = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
        let lines = request.split(separator: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }

        let method = String(parts[0])
        let path = String(parts[1])

        // Extract body for POST
        var body = ""
        if let bodyStart = request.range(of: "\r\n\r\n") {
            body = String(request[bodyStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let (status, responseBody) = routeRequest(method: method, path: path, body: body)
        let bodyData = responseBody.data(using: .utf8) ?? Data()
        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(bodyData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(responseBody)"

        response.withCString { ptr in
            _ = write(sock, ptr, strlen(ptr))
        }
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
}
