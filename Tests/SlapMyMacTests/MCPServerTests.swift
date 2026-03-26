import XCTest
@testable import SlapMyMac

final class MCPServerTests: XCTestCase {
    var server: MCPServer!

    override func setUp() {
        server = MCPServer()
        server.getStatus = { ["listening": true, "slapCount": 5] }
        server.getStats = { ["totalSlaps": 5, "avgAmplitude": 0.3] }
        server.getHistory = { [["id": "test-1", "amplitude": 0.4]] }
    }

    override func tearDown() {
        server.stop()
        server = nil
    }

    func testServerStartsAndStops() {
        server.start()
        // Give it a moment to bind
        Thread.sleep(forTimeInterval: 0.1)
        server.stop()
        // No crash = pass
    }

    func testStatusEndpoint() throws {
        server.start()
        Thread.sleep(forTimeInterval: 0.1)

        let (status, body) = try sendHTTPRequest("GET", path: "/status")
        XCTAssertEqual(status, 200)
        let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
        XCTAssertEqual(json?["slapCount"] as? Int, 5)
        XCTAssertEqual(json?["listening"] as? Bool, true)
    }

    func testStatsEndpoint() throws {
        server.start()
        Thread.sleep(forTimeInterval: 0.1)

        let (status, body) = try sendHTTPRequest("GET", path: "/stats")
        XCTAssertEqual(status, 200)
        let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
        XCTAssertEqual(json?["totalSlaps"] as? Int, 5)
    }

    func testHistoryEndpoint() throws {
        server.start()
        Thread.sleep(forTimeInterval: 0.1)

        let (status, body) = try sendHTTPRequest("GET", path: "/history")
        XCTAssertEqual(status, 200)
        let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: Any]]
        XCTAssertEqual(json?.count, 1)
        XCTAssertEqual(json?.first?["id"] as? String, "test-1")
    }

    func testTriggerEndpoint() throws {
        var triggeredMode: String?
        server.triggerSound = { mode in triggeredMode = mode }

        server.start()
        Thread.sleep(forTimeInterval: 0.1)

        let (status, _) = try sendHTTPRequest("POST", path: "/trigger", body: "{\"mode\":\"pain\"}")
        XCTAssertEqual(status, 200)

        // Give async dispatch time to execute
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(triggeredMode, "pain")
    }

    func testUnknownEndpointReturnsHelp() throws {
        server.start()
        Thread.sleep(forTimeInterval: 0.1)

        let (status, body) = try sendHTTPRequest("GET", path: "/nonexistent")
        XCTAssertEqual(status, 200)
        let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
        XCTAssertNotNil(json?["name"], "Unknown endpoint should return help with server name")
        XCTAssertNotNil(json?["endpoints"], "Unknown endpoint should list available endpoints")
    }

    // MARK: - Helper

    private func sendHTTPRequest(_ method: String, path: String, body: String? = nil) throws -> (Int, String) {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { throw NSError(domain: "test", code: 1) }
        defer {
            shutdown(sock, SHUT_RDWR)
            close(sock)
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(7749).bigEndian
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult >= 0 else { throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "connect failed: \(errno)"]) }

        var request = "\(method) \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n"
        if let body = body {
            request += "Content-Length: \(body.utf8.count)\r\n\r\n\(body)"
        } else {
            request += "\r\n"
        }

        let requestBytes = Array(request.utf8)
        requestBytes.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = Darwin.write(sock, base, ptr.count)
            }
        }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = Darwin.read(sock, &buffer, buffer.count)
        guard bytesRead > 0 else { throw NSError(domain: "test", code: 3) }

        let response = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
        let lines = response.components(separatedBy: "\r\n")
        let statusCode = Int(lines.first?.split(separator: " ").dropFirst().first ?? "0") ?? 0
        let responseBody = response.components(separatedBy: "\r\n\r\n").last ?? ""

        return (statusCode, responseBody)
    }
}
