import Foundation

class AuditLogger {
    static let shared = AuditLogger()

    private let logFilePath: String
    private let maxLogSize: Int
    private let queue = DispatchQueue(label: "com.axiomhive.audit", attributes: .concurrent)

    private init() {
        self.logFilePath = BARKConfig.shared.audit.logPath
        self.maxLogSize = BARKConfig.shared.audit.maxLogSize
    }

    func log(action: String, directiveId: UUID? = nil, details: [String: Any]) {
        let entry = BARKAuditEntry(
            timestamp: Date(),
            operatorId: BARKConfig.shared.operatorId,
            action: action,
            directiveId: directiveId,
            details: details,
            signature: nil // Would sign in real implementation
        )

        queue.async(flags: .barrier) {
            self.appendToLog(entry)
            self.rotateLogIfNeeded()
            self.syncToRemoteIfEnabled(entry)
        }
    }

    func getAuditEntries(since date: Date? = nil, limit: Int = 100) -> [BARKAuditEntry] {
        guard let data = try? Data(contentsOf: getLogFileURL()),
              let jsonString = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = jsonString.split(separator: "\n")
        var entries: [BARKAuditEntry] = []

        for line in lines.reversed() {
            if entries.count >= limit { break }
            if let data = line.data(using: .utf8),
               let entry = try? JSONDecoder().decode(BARKAuditEntry.self, from: data) {
                if let since = date, entry.timestamp < since { continue }
                entries.append(entry)
            }
        }

        return entries
    }

    func generateAuditReport(startDate: Date, endDate: Date) -> Data? {
        let entries = getAuditEntries(since: startDate, limit: 10000).filter { $0.timestamp <= endDate }

        let report: [String: Any] = [
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "end_date": ISO8601DateFormatter().string(from: endDate),
            "total_entries": entries.count,
            "operator": BARKConfig.shared.operatorId,
            "entries": entries.map { $0.jsonRepresentation }
        ]

        return try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
    }

    private func appendToLog(_ entry: BARKAuditEntry) {
        guard let data = try? JSONEncoder().encode(entry),
              let string = String(data: data, encoding: .utf8) else { return }

        do {
            let fileURL = getLogFileURL()
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
            }

            let fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\n\(string)".data(using: .utf8)!)
            fileHandle.closeFile()
        } catch {
            print("Failed to write audit log: \(error)")
        }
    }

    private func rotateLogIfNeeded() {
        do {
            let fileURL = getLogFileURL()
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0

            if fileSize > maxLogSize {
                let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(logFilePath).bak")
                try FileManager.default.moveItem(at: fileURL, to: backupURL)

                // Start new log file
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to rotate audit log: \(error)")
        }
    }

    private func syncToRemoteIfEnabled(_ entry: BARKAuditEntry) {
        guard BARKConfig.shared.audit.enableRemoteSync else { return }

        // Sync to remote audit endpoint
        guard let data = try? JSONEncoder().encode(entry) else { return }

        var request = URLRequest(url: URL(string: BARKConfig.shared.audit.remoteAuditEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to sync audit entry: \(error)")
            }
        }.resume()
    }

    private func getLogFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(logFilePath)
    }
}
