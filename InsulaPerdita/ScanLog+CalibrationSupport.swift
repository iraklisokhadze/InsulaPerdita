import Foundation

// Lightweight representation of a persisted NFC scan used for calibration & UI display.
struct ScanLog: Identifiable {
    let id = UUID()
    let url: URL
    let timestamp: Date
    let meta: [String: String]
}

// Extension adds higher-level APIs required by CalibrationViewModel without
// modifying the original ScanLogStore implementation.
extension ScanLogStore {
    /// Return newest-first list of scan file URLs.
    static func listScans() -> [URL] { listScanLogs() }

    /// Load a scan log and transform JSON payload into a ScanLog model.
    static func load(_ url: URL) -> ScanLog? {
        guard let jsonString = loadLog(url: url), let data = jsonString.data(using: .utf8) else { return nil }
        guard let raw = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return nil }
        let iso = ISO8601DateFormatter()
        let tsString = raw["timestamp"] as? String ?? iso.string(from: Date())
        let ts = iso.date(from: tsString) ?? Date()
        var meta: [String: String] = [:]
        for (k, v) in raw {
            switch k {
            case "timestamp", "blocks", "blockCount": continue // skip large arrays / duplicates
            default:
                if let s = v as? String { meta[k] = s }
                else if let n = v as? NSNumber { meta[k] = n.stringValue }
            }
        }
        return ScanLog(url: url, timestamp: ts, meta: meta)
    }
}