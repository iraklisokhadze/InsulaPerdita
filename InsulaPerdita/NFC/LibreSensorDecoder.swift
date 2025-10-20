// Moved to NFC/ folder
// Original file path: InsulaPerdita/LibreSensorDecoder.swift

import Foundation

// --- Original content below ---

/// Heuristic decoder for FreeStyle Libre raw blocks (Experimental / NOT for medical decisions!)
/// Current focus: provide raw memory insight + safe plausibility filtering while a proper
/// calibration algorithm is not implemented. The official Libre algorithms are proprietary.
///
/// Memory overview (simplified for Libre 1 style sensors):
/// - 43 blocks * 8 bytes = 344 bytes.
/// - Blocks 26..41 (16 blocks) form a circular buffer of trend entries (newest pointed by trend pointer).
/// - Each trend slot is 8 bytes; first 2 bytes contain a 16-bit raw glucose sample (little-endian, 14 bits used).
/// - Converting raw to mg/dL normally requires factory calibration constants (not implemented here).
///
/// Heuristic strategy:
/// 1. Acquire trend pointer from block 3, byte 3 (mod 16 -> 0..15) mapping to block 26 + offset.
/// 2. Read first two bytes of that trend block => raw16.
/// 3. Try two scalings:
///    a) raw16 / 10   (some early community tooling assumption)
///    b) raw16        (direct mg/dL)
///    Choose the first scaling producing a plausible mg/dL in 40...500.
/// 4. If neither plausible -> report glucose = nil and include reasons in meta.
/// 5. Trend arrow mapping currently speculative; we only map a restricted subset (2..6) else unknown.
///
/// Returned SensorReading.meta keys (strings):
///  - sensorStateHex
///  - trendIndex
///  - historyIndex
///  - selectedTrendBlock
///  - raw16
///  - appliedScaling ("/10", "*1", or "none")
///  - plausible ("true"/"false")
///  - discardReason (if any)
///  - trendArrowRaw
///
/// NOTE: This file purposely avoids any claim of medical accuracy.
enum LibreSensorDecoder {
    static func decode(blocks: [Data]) -> SensorReading { decode(blocks: blocks, verbose: false) }

    private static func deriveSensorAge(from block0: Data, verbose: Bool) -> (ageMinutes: Int?, warmupRemaining: Int?, isWarmup: Bool, reason: String?) {
        #if DEBUG
        func dlog(_ msg: String) { if verbose { print("[LibreDecoder] " + msg) } }
        #else
        func dlog(_ msg: String) { }
        #endif
        guard block0.count >= 6 else { dlog("Block0 too short for age heuristic (") ; return (nil,nil,false,nil) }
        let le01 = Int((UInt16(block0[1]) << 8) | UInt16(block0[0]))
        let be01 = Int((UInt16(block0[0]) << 8) | UInt16(block0[1]))
        let le23 = Int((UInt16(block0[3]) << 8) | UInt16(block0[2]))
        let be23 = Int((UInt16(block0[2]) << 8) | UInt16(block0[3]))
        let maxMinutes = 14 * 24 * 60
        var candidates: [(String, Int)] = []
        for (label,val) in [("le01",le01),("be01",be01),("le23",le23),("be23",be23)] { if (0...maxMinutes).contains(val) { candidates.append((label,val)) } }
        let chosen = candidates.max { $0.1 < $1.1 }
        if let chosen = chosen { dlog("Sensor age heuristic candidates: le01=\(le01), be01=\(be01), le23=\(le23), be23=\(be23) -> chosen=\(chosen.0)=\(chosen.1) min") } else { dlog("No plausible sensor age candidate among le01=\(le01), be01=\(be01), le23=\(le23), be23=\(be23)") }
        guard let age = chosen?.1 else { return (nil,nil,false,"noPlausibleAgeCandidate") }
        let warmupThreshold = 60
        let isWarmup = age < warmupThreshold
        let remaining = isWarmup ? (warmupThreshold - age) : nil
        return (age, remaining, isWarmup, nil)
    }

    static func decode(blocks: [Data], verbose: Bool) -> SensorReading {
        #if DEBUG
        func dlog(_ msg: String) { if verbose { print("[LibreDecoder] " + msg) } }
        #else
        func dlog(_ msg: String) { }
        #endif
        dlog("Decoding start. Blocks count = \(blocks.count)")
        var meta: [String: String] = [:]
        guard blocks.count >= 43 else {
            dlog("Error: insufficient blocks (\(blocks.count))")
            meta["discardReason"] = "insufficientBlocks"
            return SensorReading(timestamp: Date(), glucose: nil, rawBlocks: blocks, trend: .unknown, meta: meta)
        }
        guard !blocks[0].isEmpty, !blocks[3].isEmpty else {
            dlog("Critical block missing (0 or 3)")
            meta["discardReason"] = "missingCriticalBlock"
            return SensorReading(timestamp: Date(), glucose: nil, rawBlocks: blocks, trend: .unknown, meta: meta)
        }
        let state = blocks[0][4]
        meta["sensorStateHex"] = String(format: "%02X", state)
        dlog("Sensor state: 0x\(String(format: "%02X", state))")
        let ageResult = deriveSensorAge(from: blocks[0], verbose: verbose)
        if let age = ageResult.ageMinutes { meta["sensorAgeMinutes"] = String(age) }
        if let remain = ageResult.warmupRemaining { meta["warmupRemainingMinutes"] = String(remain) }
        meta["isWarmup"] = ageResult.isWarmup ? "true" : "false"
        if let reason = ageResult.reason { meta["sensorAgeReason"] = reason }
        let trendIndex = Int(blocks[3][3] & 0x1F)
        let historyIndex = Int(blocks[3][4])
        meta["trendIndex"] = String(trendIndex)
        meta["historyIndex"] = String(historyIndex)
        dlog("Trend index: \(trendIndex), History index: \(historyIndex)")
        let trendBlockIndex = 26 + (trendIndex % 16)
        meta["selectedTrendBlock"] = String(trendBlockIndex)
        dlog("Calculated trend block index: \(trendBlockIndex)")
        guard blocks.indices.contains(trendBlockIndex), !blocks[trendBlockIndex].isEmpty else {
            dlog("Trend block missing @ \(trendBlockIndex)")
            meta["discardReason"] = "trendBlockMissing"
            return SensorReading(timestamp: Date(), glucose: nil, rawBlocks: blocks, trend: .unknown, meta: meta)
        }
        let trendBlock = blocks[trendBlockIndex]
        if trendBlock.count < 4 {
            dlog("Trend block too short: \(trendBlock.count) bytes")
            meta["discardReason"] = "trendBlockTooShort"
            return SensorReading(timestamp: Date(), glucose: nil, rawBlocks: blocks, trend: .unknown, meta: meta)
        }
        let raw16 = (UInt16(trendBlock[1]) << 8) | UInt16(trendBlock[0])
        meta["raw16"] = String(raw16)
        let rawGlucose = Double(raw16 & 0x1FFF)
        let trend = Trend(rawValue: trendBlock[3] & 0x7F)
        var calibration = Calibration()
        if let data = UserDefaults.standard.data(forKey: "sensorCalibration"), let decoded = try? JSONDecoder().decode(Calibration.self, from: data) { calibration = decoded }
        var glucose: Double? = nil
        var scaling = "none"
        if calibration.isCalibrated {
            let calibrated = (rawGlucose * calibration.slope) + calibration.intercept
            dlog("Applied calibration: (\(rawGlucose) * \(calibration.slope)) + \(calibration.intercept) = \(calibrated)")
            if (40...500).contains(calibrated) { glucose = calibrated; scaling = "calibrated" } else { meta["discardReason"] = "calibratedValueOutOfRange" }
        } else {
            for (value, scale) in [(rawGlucose/10.0,"/10"),(rawGlucose,"*1")] { if (40...500).contains(value) { glucose = value; scaling = scale; break } }
            if glucose == nil { meta["discardReason"] = "outOfRangeRawValue" }
        }
        meta["appliedScaling"] = scaling
        meta["plausible"] = glucose == nil ? "false" : "true"
        if glucose == nil && meta["discardReason"] == nil { meta["discardReason"] = "unknown" }
        meta["trendArrowValue"] = String(Int(trendBlock[3] & 0x7F))
        meta["trendArrowRaw"] = String(Int(trendBlock[3]))
        return SensorReading(timestamp: Date(), glucose: glucose, rawBlocks: blocks, trend: trend, meta: meta)
    }
}
