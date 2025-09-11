import SwiftUI

// MARK: - General Purpose Helpers
func formatNumber(_ value: Double) -> String {
    let f = NumberFormatter()
    f.decimalSeparator = ","
    f.maximumFractionDigits = 1
    f.minimumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
}

func formatDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "ka_GE")
    df.dateStyle = .short
    df.timeStyle = .short
    return df.string(from: date)
}

func effectColor(_ value: Int) -> Color {
    value == 0 ? .gray : (value > 0 ? .green : .red)
}

func clampDose(_ value: Double, minValue: Double, maxValue: Double) -> Double {
    let clamped = min(max(value, minValue), maxValue)
    return ((clamped * 2).rounded() / 2) // ensure 0.5 step
}

// MARK: - Keyboard Utilities
func autoDismissSugarKeyboardIfNeeded(sugarLevel: String, dismiss: () -> Void) {
    let digitCount = sugarLevel.filter { $0.isNumber }.count
    if digitCount >= 3 { dismiss() }
}

// MARK: - Persistence Helpers
// These can be further grouped by model type if needed
func persistActivities(_ activities: [Activity], key: String) {
    if let data = try? JSONEncoder().encode(activities) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

func loadActivities(key: String) -> [Activity] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([Activity].self, from: data)) ?? []
}

func persistRegisteredActivities(_ activities: [RegisteredActivity], key: String) {
    if let data = try? JSONEncoder().encode(activities) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

func loadRegisteredActivities(key: String) -> [RegisteredActivity] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([RegisteredActivity].self, from: data)) ?? []
}

func persistActivityActions(_ actions: [ActivityAction], key: String) {
    if let data = try? JSONEncoder().encode(actions) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

func loadActivityActions(key: String) -> [ActivityAction] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([ActivityAction].self, from: data)) ?? []
}

func persistInjectionActions(_ actions: [InjectionAction], key: String) {
    if let data = try? JSONEncoder().encode(actions) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

func loadInjectionActions(key: String) -> [InjectionAction] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([InjectionAction].self, from: data)) ?? []
}
