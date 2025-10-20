// Moved to NFC/ folder
// Original file path: InsulaPerdita/ScanLogStore.swift

import Foundation
import os.log

struct ScanLogStore {
    static let subsystem = Bundle.main.bundleIdentifier ?? "InsulaPerdita"
    private static let log = OSLog(subsystem: subsystem, category: "NFC")
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
    static func persistScan(rawBlocks: [Data], meta: [String: Any]) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let blocksHex = rawBlocks.enumerated().map { idx, data in ["index": idx, "hex": data.map { String(format: "%02X", $0) }.joined()] }
        var payload: [String: Any] = ["timestamp": ts, "blockCount": rawBlocks.count, "blocks": blocksHex]
        meta.forEach { payload[$0.key] = $0.value }
        do {
            let json = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            if let dir = scansDirectory {
                let fileURL = dir.appending(path: "scan_\(ts.replacingOccurrences(of: ":", with: "-"))_.json")
                try json.write(to: fileURL, options: .atomic)
                os_log("Persisted scan to %{public}@", log: log, type: .info, fileURL.lastPathComponent)
                NotificationCenter.default.post(name: .scanLogPersisted, object: fileURL)
            } else {
                os_log("Scan directory unavailable; skipping file persistence", log: log, type: .error)
            }
        } catch { os_log("Failed to persist scan JSON: %{public}@", log: log, type: .error, error.localizedDescription) }
    }
    static func listScanLogs() -> [URL] {
        guard let dir = scansDirectory else { return [] }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
            return files.sorted { (a, b) -> Bool in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return da > db
            }
        } catch { os_log("Failed listing logs: %{public}@", log: log, type: .error, error.localizedDescription); return [] }
    }
    static func loadLog(url: URL) -> String? {
        do { let data = try Data(contentsOf: url); return String(data: data, encoding: .utf8) } catch {
            os_log("Failed reading log %{public}@ error=%{public}@", log: log, type: .error, url.lastPathComponent, error.localizedDescription); return nil }
    }
    static func deleteLog(url: URL) { do { try FileManager.default.removeItem(at: url); os_log("Deleted log %{public}@", log: log, type: .info, url.lastPathComponent) } catch { os_log("Failed delete log: %{public}@", log: log, type: .error, error.localizedDescription) } }
    static func purgeAll() { listScanLogs().forEach { deleteLog(url: $0) } }
    static func logInfo(_ m: String) { os_log("%{public}@", log: log, type: .info, m) }
    static func logError(_ m: String) { os_log("%{public}@", log: log, type: .error, m) }
}
extension Notification.Name { static let scanLogPersisted = Notification.Name("ScanLogPersisted") }
