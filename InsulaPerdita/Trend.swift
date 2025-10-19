import SwiftUI

enum Trend: UInt8, CaseIterable, Identifiable {
    case north = 6
    case northEast = 5
    case east = 4
    case southEast = 3
    case south = 2
    case unknown = 0

    init(rawValue: UInt8) {
        switch rawValue {
        case 2: self = .south
        case 3: self = .southEast
        case 4: self = .east
        case 5: self = .northEast
        case 6: self = .north
        default: self = .unknown
        }
    }

    var id: Self { self }
    var symbol: String {
        switch self {
        case .north: return "arrow.up"
        case .northEast: return "arrow.up.right"
        case .east: return "arrow.right"
        case .southEast: return "arrow.down.right"
        case .south: return "arrow.down"
        case .unknown: return "questionmark"
        }
    }
    var multiplier: Double {
        switch self {
        case .north: return 1.4
        case .northEast: return 1.3
        case .east: return 1.2
        case .southEast: return 1.1
        case .south: return 1.0
        case .unknown: return 1.0
        }
    }
    var predictionDelta: Double {
        switch self {
        case .north: return 100
        case .northEast: return 50
        case .east: return 0
        case .southEast: return -50
        case .south: return -100
        case .unknown: return 0
        }
    }
}
