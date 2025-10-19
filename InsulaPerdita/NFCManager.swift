import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit // for UIDevice proximity monitoring
#endif
#if canImport(CoreNFC)
import CoreNFC
#endif

// Simple model representing a glucose sensor reading
struct SensorReading: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let glucose: Double? // mg/dL
    let rawBlocks: [Data]
    let trend: Trend? // decoded trend arrow if available
    let meta: [String: String] // auxiliary decode metadata for logging / diagnostics
}

// MARK: - Internal Helpers
#if DEBUG
private func nfcLog(_ msg: String) { print("[NFC] " + msg) }
#else
private func nfcLog(_ msg: String) { /* no-op in release */ }
#endif

private extension Data {
    var hexString: String { map { String(format: "%02X", $0) }.joined() }
}

final class NFCManager: NSObject, ObservableObject {
    @Published var isScanning: Bool = false
    @Published var lastReading: SensorReading? = nil
    @Published var errorMessage: String? = nil

    // External setting now passed in explicitly (single source of truth stays in UserDefaults via SettingsView)
    private(set) var autoScanEnabled: Bool = false
    
    private var isProximityObserverActive = false
    private var cancellable: AnyCancellable? // retained for future use if needed (currently unused)
    private var lastProximityTriggeredAt: Date? = nil
    private let minTriggerInterval: TimeInterval = 10 // Increased cooldown to 10 seconds
    
    var verboseLogging: Bool = true

    override init() {
        super.init()
        // Initialize from persisted user default once; do NOT observe all defaults (prevents loops)
        let initial = UserDefaults.standard.bool(forKey: "isAutoScanOnProximityEnabled")
        autoScanEnabled = initial
        configureAutoScan(enabled: initial)
    }

    // Public API to update auto-scan state (called from Settings toggle)
    func setAutoScanEnabled(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if enabled == self.autoScanEnabled {
                if self.verboseLogging { self.log("setAutoScanEnabled noop (unchanged: \(enabled))") }
                return
            }
            if self.verboseLogging { self.log("setAutoScanEnabled -> \(enabled ? "ENABLE" : "DISABLE") request (previous: \(self.autoScanEnabled))") }
            self.autoScanEnabled = enabled
            self.configureAutoScan(enabled: enabled)
        }
    }

    @MainActor
    func startScan() {
        #if canImport(CoreNFC)
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC not available on this device"
            return
        }
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

    // Configure proximity monitoring strictly based on the passed flag.
    private func configureAutoScan(enabled: Bool) {
        #if os(iOS)
        if verboseLogging { log("Configure auto-scan requested: \(enabled ? "ENABLE" : "DISABLE"). Observer active: \(isProximityObserverActive).") }
        if enabled {
            guard !isProximityObserverActive else {
                if verboseLogging { log("AutoScanOnProximity already ENABLED (guard skip).") }
                return
            }
            isProximityObserverActive = true
            UIDevice.current.isProximityMonitoringEnabled = true
            NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
            if verboseLogging { log("AutoScanOnProximity has been ENABLED.") }
        } else {
            guard !isProximityObserverActive else {
                // disable
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
        if let last = lastProximityTriggeredAt, now.timeIntervalSince(last) < minTriggerInterval {
            if verboseLogging { nfcLog("Proximity trigger ignored due to cooldown.") }
            return
        }
        Task { @MainActor in
            if !isScanning {
                lastProximityTriggeredAt = now
                if verboseLogging { nfcLog("Proximity trigger -> starting scan") }
                startScan()
            }
        }
        #endif
    }

    deinit {
        #if os(iOS)
        if isProximityObserverActive {
            NotificationCenter.default.removeObserver(self)
        }
        cancellable?.cancel()
        #endif
    }

    // MARK: - Private
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
        Task { @MainActor in
            isScanning = false
            let nsError = error as NSError
            // 201 is "Session Cancelled by User", which we don't treat as an error to display.
            if nsError.code != 201 {
                let message = nsError.localizedDescription
                self.errorMessage = message
                if verboseLogging { nfcLog("Session invalidated with error: \(message)") }

                // Clear the message after a 5-second delay.
                Task {
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    // Only clear the message if it hasn't been replaced by a new one.
                    if self.errorMessage == message {
                        self.errorMessage = nil
                    }
                }
            } else if verboseLogging {
                nfcLog("Session cancelled by user")
            }
        }
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else { return }
        if verboseLogging { nfcLog("Detected \(tags.count) tag(s). Connecting to first...") }
        session.connect(to: first) { [weak self] connectError in
            if let connectError = connectError {
                if self?.verboseLogging == true { nfcLog("Connect error: \(connectError.localizedDescription)") }
                session.invalidate(errorMessage: connectError.localizedDescription)
                return
            }
            guard case let .iso15693(tag) = first else {
                if self?.verboseLogging == true { nfcLog("Unsupported tag type detected") }
                session.invalidate(errorMessage: "Unsupported tag type")
                return
            }
            if self?.verboseLogging == true { nfcLog("Connected. Starting block reads...") }
            self?.readLibreBlocks(tag: tag, session: session)
        }
    }
    private func readLibreBlocks(tag: NFCISO15693Tag, session: NFCTagReaderSession) {
        Task {
            let blockRange = 0..<43
            var collected: [Data] = []
            let startTime = Date()
            do {
                for i in blockRange {
                    let data = try await tag.readSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: UInt8(i))
                    collected.append(data)
                    if self.verboseLogging { nfcLog("Block #\(i) -> \(data.hexString)") }
                }
                let duration = Date().timeIntervalSince(startTime)
                if self.verboseLogging { nfcLog("Finished reading blocks. Non-empty: \(collected.count)/\(blockRange.count) in \(String(format: "%.2f", duration))s") }
                let reading = LibreSensorDecoder.decode(blocks: collected, verbose: self.verboseLogging)
                if self.verboseLogging, let value = reading.glucose {
                    nfcLog("Decoded glucose: \(String(format: "%.0f", value)) mg/dL @ \(reading.timestamp)")
                }
                // Persist scan log (even if decode failed we store raw blocks)
                var meta = reading.meta
                meta["scanDuration"] = String(format: "%.2f", duration)
                if let g = reading.glucose { meta["glucoseMgdl"] = String(format: "%.1f", g) }
                ScanLogStore.persistScan(rawBlocks: collected, meta: meta)

                let readingErrorMessage = reading.glucose == nil ? "Reading not plausible (\(reading.meta["discardReason"] ?? "unknown"))." : nil
                session.alertMessage = readingErrorMessage == nil ? "Sensor read complete" : "Reading not plausible yet. Try again later."
                session.invalidate()

                Task { @MainActor in
                    self.isScanning = false
                    self.lastReading = reading
                    if let readingErrorMessage {
                        self.errorMessage = readingErrorMessage
                        // Also clear this message after a delay
                        Task {
                            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                            if self.errorMessage == readingErrorMessage {
                                self.errorMessage = nil
                            }
                        }
                    }
                }
            } catch {
                let errorMessage = "Scan failed. Keep your iPhone still and try again."
                if self.verboseLogging { nfcLog("Read failed: \(error.localizedDescription). Invalidating session.") }
                ScanLogStore.logError("Read failure: \(error.localizedDescription)")
                session.invalidate(errorMessage: errorMessage)
                Task { @MainActor in
                    self.errorMessage = errorMessage
                    // Also clear this message after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                        if self.errorMessage == errorMessage {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
}
#endif
