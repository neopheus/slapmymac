import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let logFile: URL
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    private let queue = DispatchQueue(label: "SlapMyMac.Logger")

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SlapMyMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logFile = dir.appendingPathComponent("slapmymac.log")
    }

    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"

        queue.async { [logFile] in
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let handle = try? FileHandle(forWritingTo: logFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
        }

        // Also print to console for debug builds
        #if DEBUG
        print(line.trimmingCharacters(in: .newlines))
        #endif
    }

    func readLogs() -> String {
        (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
    }

    func clearLogs() {
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
    }

    func logFileURL() -> URL {
        logFile
    }

    /// Trim log file if it exceeds 1MB
    func trimIfNeeded() {
        queue.async { [logFile] in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
                  let size = attrs[.size] as? Int,
                  size > 1_048_576 else { return }

            // Keep last 500KB
            guard let data = try? Data(contentsOf: logFile) else { return }
            let keepFrom = data.count - 512_000
            if keepFrom > 0 {
                let trimmed = data.suffix(from: keepFrom)
                try? trimmed.write(to: logFile)
            }
        }
    }

    enum LogLevel: String {
        case info
        case warn
        case error
        case debug
    }
}
