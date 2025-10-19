import Foundation
import os.log

// Centralized persistent logging for NFC scans so data is available even when Xcode debugger was not attached.
// Stores each completed scan as a JSON file under Application Support / ScanLogs.
// Uses legacy OSLog + os_log to avoid name collision with the app's custom `Logger` class.
struct ScanLogStore {
    static let subsystem = Bundle.main.bundleIdentifier ?? "InsulaPerdita"
    private static let log = OSLog(subsystem: subsystem, category: "NFC")
    
    // Directory for persisted scan JSON files.
    private static var scansDirectory: URL? = {
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = base.appending(path: "ScanLogs", directoryHint: .isDirectory)
            if !FileManager.default.fileExists(atPath: dir.path()) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        } catch {
            os_log("Failed to resolve ScanLogs directory: %{public}@", log: log, type: .error, error.localizedDescription)
            return nil
        }
    }()
    
    /// Persist a scan. Meta should contain only JSON-compatible values.
    static func persistScan(rawBlocks: [Data], meta: [String: Any]) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let blocksHex = rawBlocks.enumerated().map { idx, data in
            return ["index": idx, "hex": data.map { String(format: "%02X", $0) }.joined()] as [String: Any]
        }
        var payload: [String: Any] = [
            "timestamp": ts,
            "blockCount": rawBlocks.count,
            "blocks": blocksHex
        ]
        meta.forEach { payload[$0.key] = $0.value }
        do {
            let json = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            if let dir = scansDirectory {
                let fileURL = dir.appending(path: "scan_\(ts.replacingOccurrences(of: ":", with: "-"))_.json")
                try json.write(to: fileURL, options: .atomic)
                os_log("Persisted scan to %{public}@", log: log, type: .info, fileURL.lastPathComponent)
                // NEW: broadcast notification for observers (CalibrationViewModel, etc.)
                NotificationCenter.default.post(name: .scanLogPersisted, object: fileURL)
            } else {
                os_log("Scan directory unavailable; skipping file persistence", log: log, type: .error)
            }
        } catch {
            os_log("Failed to persist scan JSON: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    /// Return list of scan log file URLs sorted newest first.
    static func listScanLogs() -> [URL] {
        guard let dir = scansDirectory else { return [] }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
            return files.sorted { (a, b) -> Bool in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return da > db
            }
        } catch {
            os_log("Failed listing logs: %{public}@", log: log, type: .error, error.localizedDescription)
            return []
        }
    }
    
    /// Load a log file's JSON (raw string) for UI display.
    static func loadLog(url: URL) -> String? {
        // Files are inside the app's Application Support container; no need for security-scoped access.
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                os_log("Failed decoding UTF8 for log %{public}@", log: log, type: .error, url.lastPathComponent)
                return nil
            }
            return text
        } catch {
            os_log("Failed reading log %{public}@ error=%{public}@", log: log, type: .error, url.lastPathComponent, error.localizedDescription)
            return nil
        }
    }
    
    /// Delete a single log file.
    static func deleteLog(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            os_log("Deleted log %{public}@", log: log, type: .info, url.lastPathComponent)
        } catch {
            os_log("Failed delete log: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    /// Purge all logs.
    static func purgeAll() {
        listScanLogs().forEach { deleteLog(url: $0) }
    }
    
    /// Log an informational line to unified logging
    static func logInfo(_ message: String) { os_log("%{public}@", log: log, type: .info, message) }
    static func logError(_ message: String) { os_log("%{public}@", log: log, type: .error, message) }
}

// NEW notification name extension
extension Notification.Name {
    static let scanLogPersisted = Notification.Name("ScanLogPersisted")
}
