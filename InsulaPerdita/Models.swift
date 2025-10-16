import SwiftUI

// Injection period and action models
enum InjectionPeriod: String, CaseIterable, Codable, Identifiable {
    case daytime
    case nighttime
    var id: String { rawValue }
    var display: String {
        switch self {
        case .daytime: return "დღის"
        case .nighttime: return "ღამის"
        }
    }
    var symbol: String {
        switch self {
        case .daytime: return "sun.max"
        case .nighttime: return "moon.stars"
        }
    }
}

struct InjectionAction: Identifiable, Codable {
    let id: UUID
    var date: Date
    var period: InjectionPeriod
    var dose: Double
    var deletedAt: Date? = nil // soft delete timestamp
}

struct RegisteredActivity: Identifiable, Codable {
    let id: UUID
    var title: String
    var averageEffect: Int
}

struct ActivityAction: Identifiable, Codable {
    let id: UUID
    var date: Date
    var activityId: UUID
    var deletedAt: Date? = nil // soft delete timestamp
}

struct Activity: Identifiable, Codable {
    let id: UUID
    var title: String
    var averageEffect: Int
    var createdAt: Date?
    var deletedAt: Date? = nil // soft delete timestamp (legacy ad-hoc)
}

struct UnifiedAction: Identifiable {
    let id: String
    let date: Date
    let icon: String
    let tint: Color
    let primaryLine: String
    let secondaryLine: String
    let isDeleted: Bool // new flag for soft delete state
}

struct GlucoseReadingAction: Identifiable, Codable {
    let id: UUID
    var date: Date
    var value: Double
    var deletedAt: Date? = nil
}

// Constants
let registeredActivitiesStorageKey = "RegisteredActivitiesStore.v1"
let activityActionsStorageKey = "ActivityActionsStore.v1"
let activitiesStorageKey = "ActivitiesStore.v1"
let injectionStorageKey = "injectionActions.v1"
let glucoseReadingsStorageKey = "GlucoseReadingsStore.v1"
let doseStep: Double = 0.5
let activityEffectOptions: [Int] = [-150,-100,-50,50,100,150]
