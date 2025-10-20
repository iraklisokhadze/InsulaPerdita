// Moved to NFC/ folder
// Original file path: InsulaPerdita/ScanLog+CalibrationSupport.swift

import Foundation

struct ScanLog: Identifiable {
    let id = UUID()
    let url: URL
    let timestamp: Date
    let meta: [String: String]
}
extension ScanLogStore {
    static func listScans() -> [URL] { listScanLogs() }
    static func load(_ url: URL) -> ScanLog? {
        guard let jsonString = loadLog(url: url), let data = jsonString.data(using: .utf8) else { return nil }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let iso = ISO8601DateFormatter()
        let tsString = raw["timestamp"] as? String ?? iso.string(from: Date())
        let ts = iso.date(from: tsString) ?? Date()
        var meta: [String: String] = [:]
        for (k,v) in raw where k != "timestamp" && k != "blocks" && k != "blockCount" {
            if let s = v as? String { meta[k] = s } else if let n = v as? NSNumber { meta[k] = n.stringValue }
        }
        return ScanLog(url: url, timestamp: ts, meta: meta)
    }
}
