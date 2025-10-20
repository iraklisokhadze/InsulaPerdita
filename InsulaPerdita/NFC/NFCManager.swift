// Moved to NFC/ folder
// Original file path: InsulaPerdita/NFCManager.swift

import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif
#if canImport(CoreNFC)
import CoreNFC
#endif

struct SensorReading: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let glucose: Double? // mg/dL
    let rawBlocks: [Data]
    let trend: Trend?
    let meta: [String: String]
}
#if DEBUG
private func nfcLog(_ msg: String) { print("[NFC] " + msg) }
#else
private func nfcLog(_ msg: String) { }
#endif
private extension Data { var hexString: String { map { String(format: "%02X", $0) }.joined() } }

final class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastReading: SensorReading? = nil
    @Published var errorMessage: String? = nil
    private(set) var autoScanEnabled: Bool = false
    private var isProximityObserverActive = false
    private var lastProximityTriggeredAt: Date? = nil
    private let minTriggerInterval: TimeInterval = 10
    var verboseLogging: Bool = true
    // Verification configuration to reduce misreadings
    private let verificationWindowSeconds: TimeInterval = 10
    private let requiredConsistentReads: Int = 3
    private let maxVerificationAttempts: Int = 8
    // Using raw16 equality for consistency; tolerance for calibrated glucose comparison if needed
    private let glucoseToleranceMgdl: Double = 2.0
    override init() {
        super.init()
        let initial = UserDefaults.standard.bool(forKey: "isAutoScanOnProximityEnabled")
        autoScanEnabled = initial
        configureAutoScan(enabled: initial)
    }
    func setAutoScanEnabled(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if enabled == self.autoScanEnabled { if self.verboseLogging { self.log("setAutoScanEnabled noop (unchanged: \(enabled))") }; return }
            if self.verboseLogging { self.log("setAutoScanEnabled -> \(enabled ? "ENABLE" : "DISABLE") request (previous: \(self.autoScanEnabled))") }
            self.autoScanEnabled = enabled
            self.configureAutoScan(enabled: enabled)
        }
    }
    @MainActor func startScan() {
        #if canImport(CoreNFC)
        guard NFCTagReaderSession.readingAvailable else { errorMessage = "NFC not available on this device"; return }
        errorMessage = nil
        isScanning = true
        if verboseLogging { nfcLog("Starting scan session (ISO15693)...") }
        let session = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: nil)
        session?.alertMessage = "Hold the top of the iPhone near the Libre sensor"
        session?.begin()
        self.session = session
        #else
        errorMessage = "CoreNFC not supported in this build context"
        #endif
    }
    private func configureAutoScan(enabled: Bool) {
        #if os(iOS)
        if verboseLogging { log("Configure auto-scan requested: \(enabled ? "ENABLE" : "DISABLE"). Observer active: \(isProximityObserverActive).") }
        if enabled {
            guard !isProximityObserverActive else { if verboseLogging { log("AutoScanOnProximity already ENABLED (guard skip).") }; return }
            isProximityObserverActive = true
            UIDevice.current.isProximityMonitoringEnabled = true
            NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
            if verboseLogging { log("AutoScanOnProximity has been ENABLED.") }
        } else {
            guard !isProximityObserverActive else {
                isProximityObserverActive = false
                NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
                UIDevice.current.isProximityMonitoringEnabled = false
                if verboseLogging { log("AutoScanOnProximity has been DISABLED.") }
                return
            }
        }
        #endif
    }
    @objc private func handleProximityChange() {
        #if os(iOS)
        guard autoScanEnabled, UIDevice.current.proximityState else { return }
        let now = Date()
        if let last = lastProximityTriggeredAt, now.timeIntervalSince(last) < minTriggerInterval { if verboseLogging { nfcLog("Proximity trigger ignored due to cooldown.") }; return }
        Task { @MainActor in
            if !isScanning { lastProximityTriggeredAt = now; if verboseLogging { nfcLog("Proximity trigger -> starting scan") }; startScan() }
        }
        #endif
    }
    deinit {
        #if os(iOS)
        if isProximityObserverActive { NotificationCenter.default.removeObserver(self) }
        #endif
    }
    private func log(_ msg: String) {
#if DEBUG
        print("[NFC] \(msg)")
#endif
    }
#if canImport(CoreNFC)
    private var session: NFCTagReaderSession?
#endif
}
#if canImport(CoreNFC)
extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { if verboseLogging { nfcLog("Session became active") } }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in // fixed typo (was @MagiinActor)
            isScanning = false
            let nsError = error as NSError
            if nsError.code != 201 {
                let message = nsError.localizedDescription
                self.errorMessage = message
                if verboseLogging { nfcLog("Session invalidated with error: \(message)") }
                Task { try? await Task.sleep(nanoseconds: 5_000_000_000); if self.errorMessage == message { self.errorMessage = nil } }
            } else if verboseLogging { nfcLog("Session cancelled by user") }
        }
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else { return }
        if verboseLogging { nfcLog("Detected \(tags.count) tag(s). Connecting to first...") }
        session.connect(to: first) { [weak self] err in
            if let err = err { if self?.verboseLogging == true { nfcLog("Connect error: \(err.localizedDescription)") }; session.invalidate(errorMessage: err.localizedDescription); return }
            guard case let .iso15693(tag) = first else { if self?.verboseLogging == true { nfcLog("Unsupported tag type detected") }; session.invalidate(errorMessage: "Unsupported tag type"); return }
            if self?.verboseLogging == true { nfcLog("Connected. Starting block reads...") }
            self?.readLibreBlocks(tag: tag, session: session)
        }
    }
    private func readLibreBlocks(tag: NFCISO15693Tag, session: NFCTagReaderSession) {
        Task {
            // Cluster-based verification parameters
            let overallStart = Date()
            var attemptCount = 0
            let clusterTolerance = 2 // raw16 difference tolerated within cluster
            var clusters: [Int: (count: Int, representative: Int, firstReading: SensorReading, blocks: [Data], firstDuration: Double)] = [:]
            var winningRep: Int? = nil
            var finalReading: SensorReading? = nil
            var finalBlocks: [Data] = []
            var finalDuration: Double = 0

            while Date().timeIntervalSince(overallStart) < verificationWindowSeconds && attemptCount < maxVerificationAttempts && winningRep == nil {
                attemptCount += 1
                let attemptStart = Date()
                var collected: [Data] = []
                do {
                    for i in 0..<43 {
                        let data = try await tag.readSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: UInt8(i))
                        collected.append(data)
                        if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) Block #\(i) -> \(data.hexString)") }
                    }
                    let attemptDuration = Date().timeIntervalSince(attemptStart)
                    if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) completed in \(String(format: "%.2f", attemptDuration))s") }
                    let reading = LibreSensorDecoder.decode(blocks: collected, verbose: verboseLogging)

                    if let raw16Str = reading.meta["raw16"], let raw16Val = Int(raw16Str), reading.glucose != nil {
                        // Find existing cluster within tolerance
                        var matchedRep: Int? = nil
                        for (rep, tuple) in clusters {
                            if abs(rep - raw16Val) <= clusterTolerance { matchedRep = rep; break }
                        }
                        if let rep = matchedRep {
                            var tuple = clusters[rep]!
                            tuple.count += 1
                            clusters[rep] = tuple
                            if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) raw16=\(raw16Val) -> cluster rep=\(rep) count=\(tuple.count)") }
                            if tuple.count >= requiredConsistentReads {
                                winningRep = rep
                                finalReading = reading
                                finalBlocks = collected
                                finalDuration = attemptDuration
                                if verboseLogging { nfcLog("[Verify] Consistency achieved (cluster rep=\(rep), count=\(tuple.count)) after \(attemptCount) attempts") }
                            }
                        } else {
                            // New cluster
                            clusters[raw16Val] = (count: 1, representative: raw16Val, firstReading: reading, blocks: collected, firstDuration: attemptDuration)
                            if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) raw16=\(raw16Val) started new cluster") }
                        }
                    } else {
                        if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) no plausible reading (discardReason=\(reading.meta["discardReason"] ?? "none"))") }
                    }
                } catch {
                    if verboseLogging { nfcLog("[Verify] Attempt #\(attemptCount) failed early: \(error.localizedDescription)") }
                    // continue attempts while time remains
                }
            }

            // Success path already assigned finalReading. If not successful, decide failure.
            if finalReading == nil {
                // Majority cluster check (still failure if < requiredConsistentReads)
                if let best = clusters.max(by: { $0.value.count < $1.value.count }) {
                    if verboseLogging { nfcLog("[Verify] Majority cluster rep=\(best.key) count=\(best.value.count) (< required \(requiredConsistentReads))") }
                    // Use majority cluster firstReading for meta but mark failure
                    finalReading = best.value.firstReading
                    finalBlocks = best.value.blocks
                    finalDuration = best.value.firstDuration
                } else {
                    // Fallback attempt to get some meta
                    if verboseLogging { nfcLog("[Verify] No clusters formed; performing fallback attempt") }
                    var collected: [Data] = []
                    let fallbackStart = Date()
                    do { for i in 0..<43 { let data = try await tag.readSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: UInt8(i)); collected.append(data) } } catch {}
                    finalReading = LibreSensorDecoder.decode(blocks: collected, verbose: verboseLogging)
                    finalBlocks = collected
                    finalDuration = Date().timeIntervalSince(fallbackStart)
                }
            }

            guard let readingToPersist = finalReading else {
                session.invalidate(errorMessage: "Scan produced no data. Try again.")
                Task { @MainActor in
                    self.isScanning = false
                    self.errorMessage = "Scan produced no data."
                }
                return
            }

            var meta = readingToPersist.meta
            meta["verificationAttempts"] = String(attemptCount)
            meta["verificationWindowSeconds"] = String(format: "%.1f", verificationWindowSeconds)
            meta["verificationRequired"] = String(requiredConsistentReads)
            meta["verificationClusterToleranceRaw16"] = String(clusterTolerance)
            meta["overallVerificationDuration"] = String(format: "%.2f", Date().timeIntervalSince(overallStart))
            meta["finalAttemptDuration"] = String(format: "%.2f", finalDuration) // NEW: consume finalDuration
            // Serialize clusters summary
            if !clusters.isEmpty {
                let clusterSummary = clusters.map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: ",")
                meta["verificationClusters"] = clusterSummary
            }
            if let rep = winningRep {
                meta["verificationSucceeded"] = "true"
                meta["verificationFinalRaw16ClusterRep"] = String(rep)
            } else {
                meta["verificationSucceeded"] = "false"
                meta["discardReason"] = meta["discardReason"] ?? "verificationInsufficientMatches"
                // Mark glucose as nil for failure to avoid misleading value
                meta["glucoseDiscarded"] = "true"
            }

            // If failed, null out glucose before persistence
            let finalGlucose = (meta["verificationSucceeded"] == "true") ? readingToPersist.glucose : nil
            if finalGlucose == nil { if verboseLogging { nfcLog("[Verify] Verification failed; glucose discarded") } }

            if let g = finalGlucose { meta["glucoseMgdl"] = String(format: "%.1f", g) } else { meta.removeValue(forKey: "glucoseMgdl") }

            ScanLogStore.persistScan(rawBlocks: finalBlocks, meta: meta)
            let alertMsg: String
            if meta["verificationSucceeded"] == "true" {
                alertMsg = "Sensor read complete"
            } else {
                alertMsg = "Reading not consistent. Try again."
            }
            session.alertMessage = alertMsg
            session.invalidate()

            Task { @MainActor in
                self.isScanning = false
                self.lastReading = SensorReading(timestamp: readingToPersist.timestamp, glucose: finalGlucose, rawBlocks: finalBlocks, trend: readingToPersist.trend, meta: meta)
                if meta["verificationSucceeded"] != "true" {
                    self.errorMessage = alertMsg
                    Task { try? await Task.sleep(nanoseconds: 5_000_000_000); if self.errorMessage == alertMsg { self.errorMessage = nil } }
                } else if self.verboseLogging, let g = finalGlucose {
                    nfcLog("Verified glucose (cluster): \(String(format: "%.0f", g)) mg/dL attempts=\(attemptCount) clusterRep=\(winningRep!)")
                }
            }
        }
    }
}
#endif
