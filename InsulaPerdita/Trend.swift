import SwiftUI

enum Trend: CaseIterable, Identifiable {
    case north, northEast, east, southEast, south
    var id: Self { self }
    var symbol: String {
        switch self {
        case .north: return "arrow.up"
        case .northEast: return "arrow.up.right"
        case .east: return "arrow.right"
        case .southEast: return "arrow.down.right"
        case .south: return "arrow.down"
        }
    }
    var multiplier: Double {
        switch self {
        case .north: return 1.4
        case .northEast: return 1.3
        case .east: return 1.2
        case .southEast: return 1.1
        case .south: return 1.0
        }
    }
    var predictionDelta: Double {
        switch self {
        case .north: return 100
        case .northEast: return 50
        case .east: return 0
        case .southEast: return -50
        case .south: return -100
        }
    }
}
