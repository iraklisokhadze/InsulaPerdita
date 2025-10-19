import Foundation
import Combine

struct Calibration: Codable {
    var slope: Double = 1.0
    var intercept: Double = 0.0
    var isCalibrated: Bool = false
}

struct CalibrationPoint: Identifiable {
    let id: UUID
    let scan: ScanLog
    var raw: Int { Int(scan.meta["raw16"] ?? scan.meta["rawGlucoseMasked"] ?? "0") ?? 0 }
    var officialValue: String = ""
}

class CalibrationViewModel: ObservableObject {
    @Published var calibration: Calibration
    @Published var calibrationPoints: [CalibrationPoint] = []
    @Published var isLoading: Bool = false
    @Published var lastLoadError: String? = nil

    private let calibrationKey = "sensorCalibration"
    private var cancellables = Set<AnyCancellable>()
    private let maxPoints = 8 // show more than original 5 for better regression spread

    init() {
        if let data = UserDefaults.standard.data(forKey: calibrationKey),
           let decoded = try? JSONDecoder().decode(Calibration.self, from: data) {
            self.calibration = decoded
        } else {
            self.calibration = Calibration()
        }
        observeScanPersistence()
    }

    private func observeScanPersistence() {
        NotificationCenter.default.publisher(for: .scanLogPersisted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPoints(reason: "notification")
            }
            .store(in: &cancellables)
    }

    func refreshPoints(reason: String = "manual") { loadRecentScans() }

    func loadRecentScans() {
        isLoading = true
        lastLoadError = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let urls = ScanLogStore.listScans()
            // Map into ScanLog objects; discard failures.
            let logs: [ScanLog] = urls.compactMap { ScanLogStore.load($0) }
            // Sort by timestamp desc (newest first)
            let sorted = logs.sorted { $0.timestamp > $1.timestamp }
            // Limit
            let limited = Array(sorted.prefix(self.maxPoints))
            // Build points
            let points = limited.map { CalibrationPoint(id: $0.id, scan: $0) }
            DispatchQueue.main.async {
                self.calibrationPoints = points
                self.isLoading = false
                if points.isEmpty { self.lastLoadError = "No saved scans yet. Perform an NFC scan to populate calibration points." }
            }
        }
    }

    func calculateAndSave() {
        let validPoints = calibrationPoints.compactMap { point -> (raw: Double, official: Double)? in
            guard let official = Double(point.officialValue) else { return nil }
            return (raw: Double(point.raw), official: official)
        }
        guard validPoints.count >= 2 else { return }
        let (slope, intercept) = linearRegression(validPoints)
        var newCalibration = Calibration()
        newCalibration.slope = slope
        newCalibration.intercept = intercept
        newCalibration.isCalibrated = true
        self.calibration = newCalibration
        save()
    }

    func resetCalibration() {
        self.calibration = Calibration()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(calibration) {
            UserDefaults.standard.set(data, forKey: calibrationKey)
        }
    }

    private func linearRegression(_ points: [(raw: Double, official: Double)]) -> (slope: Double, intercept: Double) {
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.raw }
        let sumY = points.reduce(0) { $0 + $1.official }
        let sumXY = points.reduce(0) { $0 + ($1.raw * $1.official) }
        let sumX2 = points.reduce(0) { $0 + ($1.raw * $1.raw) }
        let denominator = (n * sumX2 - sumX * sumX)
        guard denominator != 0 else { return (slope: 1.0, intercept: 0.0) }
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }
}
