import SwiftUI

enum Sensitivity: String, CaseIterable, Identifiable {
    case low = "დაბალი"
    case medium = "საშუალო"
    case high = "მაღალი"

    var id: String { self.rawValue }

    // Raw value used for persistence (non-localized tokens)
    var storageValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    static func fromStorage(_ value: String) -> Sensitivity {
        switch value {
        case "low": return .low
        case "high": return .high
        default: return .medium
        }
    }

    var factor: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 0.7
        case .high: return 0.4
        }
    }
}
