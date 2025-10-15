import SwiftUI

struct ContentView: View {
    // Persisted settings
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("sensitivity") private var sensitivityStorage: String = "medium"
    @AppStorage("target") private var targetStorage: String = "110"
    @AppStorage("nightDose") private var nightDoseSetting: Int = 10 // new: night insulin preset
    
    // Inputs
    @State private var sugarLevel: String = ""
    @State private var selectedTrend: Trend = .east
    
    // NFC
    @StateObject private var nfcManager = NFCManager()
    
    // Injection state
    @State private var showInjectionSheet = false
    @State private var injectionDose: Double = 0.5
    @State private var injectionPeriod: InjectionPeriod = .daytime
    @State private var injectionActions: [InjectionAction] = []
    @State private var injectionDoseWasManuallyChanged: Bool = false
    @FocusState private var sugarFieldFocused: Bool
    
    // Ad-hoc Activities (legacy quick activities list)
    @State private var activities: [Activity] = []
    @State private var showActionChooser = false
    @State private var newActivityTitle: String = ""
    @State private var newActivityEffect: Int? = nil
    @State private var editingActivityIndex: Int? = nil
    private let activityEffectOptions: [Int] = [-150,-100,-50,50,100,150]
    private let activitiesStorageKey = "ActivitiesStore.v1"
    
    private let injectionStorageKey = "injectionActions.v1"
    private var doseStep: Double {
        injectionPeriod == .nighttime ? 1.0 : 0.5
    }
    
    private var target: Double { Double(targetStorage.replacingOccurrences(of: ",", with: ".")) ?? 110 }
    private var sensitivity: Sensitivity { Sensitivity.fromStorage(sensitivityStorage) }
    private var weightValue: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
    private var sugarLevelValue: Double? { Double(sugarLevel.replacingOccurrences(of: ",", with: ".")) }
    private var sugarDifference: Double { max(0, (sugarLevelValue ?? 0) - target) }
    
    private var sugarLevelColor: Color {
        guard let current = sugarLevelValue, current > 0 else { return .primary }
        let predicted = current + selectedTrend.predictionDelta
        let lower = target - 30
        let upper = target + 30
        let highUpper = target + 90
        if predicted < lower { return .red }
        if predicted <= upper { return selectedTrend == .east ? .green : .yellow }
        if predicted <= highUpper { return .yellow }
        return .red
    }
    
    private var targetDisplayText: String {
        let t = formatNumber(target)
        return sugarDifference > 0 ? "სამიზნე: \(t) მმოლ/ლ - \(formatNumber(sugarDifference))" : "სამიზნე: \(t) მმოლ/ლ"
    }
    
    private var recommendedDose: Double? {
        guard let current = sugarLevelValue, current > 0 else { return nil }
        guard let w = weightValue, w > 0 else { return nil }
        let predicted = current + selectedTrend.predictionDelta
        if predicted <= target { return 0 }
        let difference = predicted - target
        let dailyDose = w * sensitivity.factor
        guard dailyDose > 0 else { return nil }
        let isf = 1800 / dailyDose
        guard isf > 0 else { return nil }
        let rawDose = difference / isf
        let rounded = (rawDose * 2).rounded() / 2
        return max(0, rounded)
    }
    
    // Injection dose bounds
    private var injectionMinDose: Double { 0.5 }
    private var injectionDailyDose: Double? { (weightValue ?? 0) > 0 ? (weightValue! * sensitivity.factor) : nil }
    private var injectionMaxDose: Double {
        if let dd = injectionDailyDose { return max(injectionMinDose, dd / 2.0) }
        if let rec = recommendedDose { return max(injectionMinDose, rec) }
        return injectionMinDose
    }
    
    // Registered activities (pre-registered reusable set)
    @State private var showRegisteredActivityPicker = false
    @State private var selectedRegisteredActivityId: UUID? = nil
    @State private var registeredActivities: [RegisteredActivity] = []
    @State private var showRegisteredActivitiesSheet = false
    @State private var newRegisteredActivityTitle: String = ""
    @State private var newRegisteredActivityEffect: Int? = nil
    @State private var editingRegisteredActivityIndex: Int? = nil
    
    // NEW: drives programmatic navigation to SettingsView
    @State private var showSettings: Bool = false
    @State private var showActivitiesView: Bool = false // <-- add this line
    @State private var showActivitySheet: Bool = false // <-- fix: add missing state
    // Deletion confirmation state
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteId: String? = nil
    
    @EnvironmentObject var activityHistory: ActivityHistoryStore
    
    // Replace body with simpler wrapper referencing extracted rootContent
    var body: some View {
        NavigationStack {
            rootContent // now excludes toolbar
                .toolbar { MainToolbar(showSettings: $showSettings, showActivitiesView: $showActivitiesView, showActionChooser: $showActionChooser) }
        }
    }
    
    // Extracted from previous body chain to reduce generic nesting complexity
    private var rootContent: some View {
        ScrollView(.vertical, showsIndicators: true) { // disambiguated explicit init
            mainVStack
        }
            .simultaneousGesture(TapGesture().onEnded { if sugarFieldFocused { dismissSugarKeyboard() } })
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                // Load persisted data with correct keys
                injectionActions = loadInjectionActions(key: injectionStorageKey)
                activities = loadActivities(key: activitiesStorageKey)
                registeredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
                // REMOVE: activityActions = loadActivityActions(key: activityActionsStorageKey)
            }
            .onChange(of: sugarLevel) { newValue in
                autoDismissSugarKeyboardIfNeeded(sugarLevel: newValue, dismiss: dismissSugarKeyboard)
                updateInjectionDoseIfNeeded()
            }
            .onChange(of: selectedTrend) { newValue in
                updateInjectionDoseIfNeeded()
            }
            .onChange(of: nfcManager.lastReading) { newValue in
                if let g = newValue?.glucose { sugarLevel = formatNumber(g) }
                updateInjectionDoseIfNeeded()
            }
            .sheet(isPresented: $showInjectionSheet) {
                InjectionSheetView(
                    isPresented: $showInjectionSheet,
                    injectionPeriod: $injectionPeriod,
                    injectionDose: $injectionDose,
                    injectionMinDose: injectionMinDose,
                    injectionMaxDose: injectionMaxDose,
                    injectionDailyDose: injectionDailyDose,
                    canIncrementDose: (injectionDose + doseStep) <= injectionMaxDose + 0.0001,
                    canDecrementDose: (injectionDose - doseStep) >= injectionMinDose - 0.0001,
                    decrementDose: {
                        injectionDoseWasManuallyChanged = true
                        injectionDose = clampDose(injectionDose - doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose)
                    },
                    incrementDose: {
                        injectionDoseWasManuallyChanged = true
                        injectionDose = clampDose(injectionDose + doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose)
                    },
                    saveAction: saveInjection
                )
            }
            .confirmationDialog("დამატება", isPresented: $showActionChooser, titleVisibility: .visible) {
                Button("ინექცია") { prepareInjectionSheet() }
                Button("აქტივობა") { showActivitiesView = true }
                Button("გაუქმება", role: .cancel) {}
            }
            .sheet(isPresented: $showActivitiesView, onDismiss: {
                // Ensure newly created registered activities inside ActivitiesView are visible
                registeredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
            }) {
                ActivitiesView(isPresented: $showActivitiesView) { activity in
                    let action = ActivityAction(id: UUID(), date: Date(), activityId: activity.id)
                    activityHistory.add(action) // persist immediately
                }
            }
            .navigationDestination(isPresented: $showSettings) { GeneralSettingsView() }
    }
    
    private var mainVStack: some View {
        VStack(spacing: 20) {
            nfcSection
            inputSection
            trendSection
            resultSection
            actionsSection
        }
    }
    
    // MARK: - Sections
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("შაქრის დონე")
                GeometryReader { geo in
                    TextField("მმოლ/ლ", text: $sugarLevel)
                        .keyboardType(.decimalPad)
                        .focused($sugarFieldFocused)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .frame(width: geo.size.width * 0.9, alignment: .leading)
                        .foregroundColor(sugarLevelColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(sugarLevel.isEmpty ? Color.secondary.opacity(0.3) : sugarLevelColor, lineWidth: 1)
                        )
                        .textFieldStyle(.roundedBorder)
                }
                .frame(height: 52) // fixed height so GeometryReader has layout
            }
        }
    }
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ტრენდი")
            HStack(spacing: 12) {
                ForEach(Trend.allCases) { trend in
                    Button { selectedTrend = trend; dismissSugarKeyboard() } label: {
                        Image(systemName: trend.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(selectedTrend == trend ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTrend == trend ? Color.accentColor : Color.clear, lineWidth: 2))
                            .foregroundColor(selectedTrend == trend ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if weightValue  == nil{
                Text("წონა არ არის დაყენებული პარამეტრებში").font(.subheadline).foregroundColor(.orange)
            } else if sugarLevelValue == nil || (sugarLevelValue ?? 0) <= 0 {
                Text("შეიყვანეთ მნიშვნელობები").foregroundColor(.secondary)
            
            } else if let dose = recommendedDose {
                Text("რეკომენდირებული დოზა: \(formatNumber(dose)) ერთეული").font(.headline).fontWeight(.semibold)
            } else {
                Text("შეიყვანეთ მნიშვნელობები").foregroundColor(.secondary)
            }
        }
    }
    private var actionsSection: some View {
        ActionsHistorySectionView(
            injectionActions: $injectionActions,
            activities: $activities,
            activityActions: $activityHistory.activityActions,
            registeredActivities: $registeredActivities,
            showDeleteConfirm: $showDeleteConfirm,
            pendingDeleteId: $pendingDeleteId
        )
    }
    
    // MARK: - Dose Auto-Update
    private func updateInjectionDoseIfNeeded() {
        guard showInjectionSheet, !injectionDoseWasManuallyChanged, let rec = recommendedDose else { return }
        injectionDose = clampDose(rec, minValue: injectionMinDose, maxValue: injectionMaxDose)
    }
    
    // MARK: - Sheets & Forms
    // MARK: - Activity CRUD
    private var canSaveActivity: Bool { !newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newActivityEffect != nil }
    private func beginAddActivity() { resetActivityForm(); showActivitySheet = true }
    private func resetActivityForm() { newActivityTitle = ""; newActivityEffect = nil; editingActivityIndex = nil }
    private func saveActivity() {
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
    private var canSaveRegisteredActivity: Bool { !newRegisteredActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newRegisteredActivityEffect != nil }
    private func beginAddRegisteredActivity() { resetRegisteredActivityForm(); showRegisteredActivitiesSheet = true }
    private func resetRegisteredActivityForm() { newRegisteredActivityTitle = ""; newRegisteredActivityEffect = nil; editingRegisteredActivityIndex = nil }
    private func saveRegisteredActivity() {
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
    
    // MARK: - Registered Activity Actions
    private func beginAddRegisteredActivityAction() { selectedRegisteredActivityId = nil; showRegisteredActivityPicker = true }
    private func saveRegisteredActivityAction() {
        guard let id = selectedRegisteredActivityId else { return }
        let action = ActivityAction(id: UUID(), date: Date(), activityId: id)
        activityHistory.activityActions.append(action)
        // persistActivityActions(activityActions, key: activityActionsStorageKey) // REMOVE: no longer needed
        showRegisteredActivityPicker = false
    }
    
    // MARK: - Injection Helpers
    private func prepareInjectionSheet() {
        injectionDoseWasManuallyChanged = false
        let start = recommendedDose ?? injectionMinDose
        injectionDose = clampDose(start, minValue: injectionMinDose, maxValue: injectionMaxDose)
        injectionPeriod = .daytime
        showInjectionSheet = true
    }
    private func saveInjection() {
        let clamped = clampDose(injectionDose, minValue: injectionMinDose, maxValue: injectionMaxDose)
        let action = InjectionAction(id: UUID(), date: Date(), period: injectionPeriod, dose: clamped)
        injectionActions.append(action)
        persistInjectionActions(injectionActions, key: injectionStorageKey)
        showInjectionSheet = false
    }
    
    // MARK: - Hide Keyboard
    private func dismissSugarKeyboard() { sugarFieldFocused = false }
    private func autoDismissSugarKeyboardIfNeeded(sugarLevel: String, dismiss: () -> Void) { let digits = sugarLevel.filter { $0.isNumber }.count; if digits >= 3 { dismiss() } }
    
    // MARK: - NFC Section
    private var nfcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { nfcManager.startScan() } label: {
                    HStack {
                        Image(systemName: nfcManager.isScanning ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                        Text(nfcManager.isScanning ? "სკანირება..." : "სკანირება")
                    }
                }.disabled(nfcManager.isScanning)
            }
            if let r = nfcManager.lastReading { Text("ბოლო სენსორი: \(formatNumber(r.glucose ?? 0)) მმოლ/ლ").font(.subheadline) }
            if let e = nfcManager.errorMessage { Text(e).font(.caption).foregroundColor(.red) }
        }
    }
}

#Preview("Light") {
    NavigationStack { ContentView() }
}

#Preview("Dark") {
    NavigationStack { ContentView() }
        .preferredColorScheme(.dark)
}

private struct MainToolbar: ToolbarContent {
    @Binding var showSettings: Bool
    @Binding var showActivitiesView: Bool // <-- remove default value
    @Binding var showActionChooser: Bool
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            
                Button { showSettings = true }
            label: { Label("პარამეტრები",
                           systemImage: "gear")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showActionChooser = true }) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("დამატება")
        }
    }
}
