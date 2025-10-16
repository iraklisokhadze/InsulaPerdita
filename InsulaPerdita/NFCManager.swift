import Foundation
import SwiftUI
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
    let glucose: Double? // mg/dL or mmol/L depending on decoder (placeholder mmol/L)
    let rawBlocks: [Data]
}

final class NFCManager: NSObject, ObservableObject {
    @Published var isScanning: Bool = false
    @Published var lastReading: SensorReading? = nil
    @Published var errorMessage: String? = nil
    // NEW: proximity-triggered auto scan flag
    private var autoScanOnProximityEnabled = false
    // NEW: cooldown tracking to avoid repeated triggers
    private var lastProximityTriggeredAt: Date? = nil
    private let minTriggerInterval: TimeInterval = 5 // seconds between auto scans

    // Start an NFC scan for ISO15693 (used by FreeStyle Libre sensors)
    @MainActor
    func startScan() {
        #if canImport(CoreNFC)
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC not available on this device"
            return
        }
        errorMessage = nil
        isScanning = true
        let session = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: nil)
        session?.alertMessage = "Hold the top of the iPhone near the Libre sensor"
        session?.begin()
        self.session = session
        #else
        errorMessage = "CoreNFC not supported in this build context"
        #endif
    }

    // NEW: Enable automatic NFC scan when proximity sensor (near front camera) is covered.
    // This uses UIDevice proximity monitoring; when proximityState becomes true we trigger a scan if not already scanning.
    func enableAutoScanOnProximity() {
        #if os(iOS)
        guard !autoScanOnProximityEnabled else { return }
        autoScanOnProximityEnabled = true
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleProximityChange), name: UIDevice.proximityStateDidChangeNotification, object: nil)
        #endif
    }
    func disableAutoScanOnProximity() {
        #if os(iOS)
        guard autoScanOnProximityEnabled else { return }
        autoScanOnProximityEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
        UIDevice.current.isProximityMonitoringEnabled = false
        #endif
    }
    @objc private func handleProximityChange() {
        #if os(iOS)
        guard autoScanOnProximityEnabled else { return }
        // Only start when sensor reports close (true), not already scanning
        if UIDevice.current.proximityState {
            let now = Date()
            if let last = lastProximityTriggeredAt, now.timeIntervalSince(last) < minTriggerInterval { return }
            Task { @MainActor in
                if !isScanning {
                    lastProximityTriggeredAt = now
                    startScan()
                }
            }
        }
        #endif
    }

    deinit {
        disableAutoScanOnProximity()
    }

    // MARK: - Private
    #if canImport(CoreNFC)
    private var session: NFCTagReaderSession?
    #endif
}

#if canImport(CoreNFC)
extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            isScanning = false
            if (error as NSError).code != 201 { // 201 = user canceled
                errorMessage = error.localizedDescription
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else { return }
        session.connect(to: first) { [weak self] connectError in
            if let connectError = connectError {
                session.invalidate(errorMessage: connectError.localizedDescription)
                return
            }
            guard case let .iso15693(tag) = first else {
                session.invalidate(errorMessage: "Unsupported tag type")
                return
            }
            self?.readLibreBlocks(tag: tag, session: session)
        }
    }

    private func readLibreBlocks(tag: NFCISO15693Tag, session: NFCTagReaderSession) {
        // Libre 1 typically has 43 blocks (0-42) of 8 bytes each. We'll attempt first 43; ignore failures.
        let blockRange = 0..<43
        var collected: [Data] = Array(repeating: Data(), count: blockRange.count)
        let group = DispatchGroup()
        for i in blockRange {
            group.enter()
            tag.readSingleBlock(requestFlags: [.highDataRate, .address], blockNumber: UInt8(i)) { data, error in
                // data is non-optional in this API; only check error
                if error == nil {
                    collected[i] = data
                }
                group.leave()
            }
        }
        group.notify(queue: .global()) { [weak self] in
            // Basic placeholder decoding
            let reading = LibreSensorDecoder.decode(blocks: collected)
            session.alertMessage = "Sensor read complete"
            session.invalidate()
            Task { @MainActor in
                self?.isScanning = false
                self?.lastReading = reading
            }
        }
    }
}
#endif
