import SwiftUI

final class HubViewModel: ObservableObject {
    // Core user-input & derived states moved from HubView
    @Published var sugarLevel: String = ""
    @Published var selectedTrend: Trend = .east
    @Published var injectionDose: Double = 0.5
    @Published var injectionPeriod: InjectionPeriod = .daytime
    @Published var injectionDoseWasManuallyChanged: Bool = false

    // Data collections
    @Published var injectionActions: [InjectionAction] = []
    @Published var glucoseReadings: [GlucoseReadingAction] = []
    @Published var activities: [Activity] = []
    @Published var registeredActivities: [RegisteredActivity] = []

    // Activity form (kept here for future extraction of a dedicated ActivityViewModel if needed)
    @Published var newActivityTitle: String = ""
    @Published var newActivityEffect: Int? = nil
    @Published var editingActivityIndex: Int? = nil

    // Registered Activity form
    @Published var newRegisteredActivityTitle: String = ""
    @Published var newRegisteredActivityEffect: Int? = nil
    @Published var editingRegisteredActivityIndex: Int? = nil

    // Picker / sheets
    @Published var selectedRegisteredActivityId: UUID? = nil
    @Published var showRegisteredActivityPicker: Bool = false
    @Published var showRegisteredActivitiesSheet: Bool = false
    @Published var showActivitySheet: Bool = false

    // Deletion confirmation
    @Published var showDeleteConfirm: Bool = false
    @Published var pendingDeleteId: String? = nil

    // MARK: - Loading
    func loadAll() {
        injectionActions = loadInjectionActions(key: injectionStorageKey)
        activities = loadActivities(key: activitiesStorageKey)
        registeredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
        glucoseReadings = loadGlucoseReadings(key: glucoseReadingsStorageKey)
    }

    // MARK: - Computed helpers (string -> Double)
    var sugarLevelValue: Double? { Double(sugarLevel.replacingOccurrences(of: ",", with: ".")) }

    // MARK: - Activity CRUD
    var canSaveActivity: Bool { !newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newActivityEffect != nil }
    func beginAddActivity() { resetActivityForm(); showActivitySheet = true }
    func resetActivityForm() { newActivityTitle = ""; newActivityEffect = nil; editingActivityIndex = nil }
    func saveActivity() {
        guard canSaveActivity, let eff = newActivityEffect else { return }
        let trimmed = newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = editingActivityIndex, activities.indices.contains(idx) {
            activities[idx].title = trimmed
            activities[idx].averageEffect = eff
            if activities[idx].createdAt == nil { activities[idx].createdAt = Date() }
        } else {
            activities.append(Activity(id: UUID(), title: trimmed, averageEffect: eff, createdAt: Date()))
        }
        persistActivities(activities, key: activitiesStorageKey)
        showActivitySheet = false
    }

    // MARK: - Registered Activities CRUD
    var canSaveRegisteredActivity: Bool { !newRegisteredActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newRegisteredActivityEffect != nil }
    func beginAddRegisteredActivity() { resetRegisteredActivityForm(); showRegisteredActivitiesSheet = true }
    func resetRegisteredActivityForm() { newRegisteredActivityTitle = ""; newRegisteredActivityEffect = nil; editingRegisteredActivityIndex = nil }
    func saveRegisteredActivity() {
        guard canSaveRegisteredActivity, let eff = newRegisteredActivityEffect else { return }
        let trimmed = newRegisteredActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = editingRegisteredActivityIndex, registeredActivities.indices.contains(idx) {
            registeredActivities[idx].title = trimmed
            registeredActivities[idx].averageEffect = eff
        } else {
            registeredActivities.append(RegisteredActivity(id: UUID(), title: trimmed, averageEffect: eff))
        }
        persistRegisteredActivities(registeredActivities, key: registeredActivitiesStorageKey)
        showRegisteredActivitiesSheet = false
    }

    // MARK: - Registered Activity Action
    func beginAddRegisteredActivityAction() { selectedRegisteredActivityId = nil; showRegisteredActivityPicker = true }
    func saveRegisteredActivityAction(activityHistory: ActivityHistoryStore) {
        guard let id = selectedRegisteredActivityId else { return }
        let action = ActivityAction(id: UUID(), date: Date(), activityId: id)
        activityHistory.activityActions.append(action)
        showRegisteredActivityPicker = false
    }

    // MARK: - Glucose Reading
    func acceptGlucoseReading(_ value: Double) {
        let action = GlucoseReadingAction(id: UUID(), date: Date(), value: value)
        glucoseReadings.append(action)
        persistGlucoseReadings(glucoseReadings, key: glucoseReadingsStorageKey)
    }
}
