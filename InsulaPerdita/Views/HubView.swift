import SwiftUI

struct HubView: View {
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("sensitivity") private var sensitivityStorage: String = "medium"
    @AppStorage("target") private var targetStorage: String = "110"
    @AppStorage("nightDose") private var nightDoseSetting: Int = 10

    // ViewModel consolidates most state & CRUD logic
    @StateObject private var viewModel = HubViewModel()

    // NFC
    @StateObject private var nfcManager = NFCManager()
    @AppStorage("isAutoScanOnProximityEnabled") private var isAutoScanEnabled: Bool = false

    // UI States still local to view
    @State private var showInjectionSheet = false
    @State private var showActivitiesView: Bool = false
    @FocusState private var sugarFieldFocused: Bool

    // Success banner
    @State private var pendingSuccess: SuccessKind? = nil
    @State private var activeSuccess: SuccessKind? = nil
    @State private var successHideTask: DispatchWorkItem? = nil

    @EnvironmentObject var activityHistory: ActivityHistoryStore

    // MARK: - Derived values from persisted strings
    private var target: Double { Double(targetStorage.replacingOccurrences(of: ",", with: ".")) ?? 110 }
    private var sensitivity: Sensitivity { Sensitivity.fromStorage(sensitivityStorage) }
    private var weightValue: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
    private var sugarLevelValue: Double? { viewModel.sugarLevelValue }
    private var sugarDifference: Double { max(0, (sugarLevelValue ?? 0) - target) }

    private var recommendedDose: Double? {
        guard let current = sugarLevelValue, current > 0 else { return nil }
        guard let w = weightValue, w > 0 else { return nil }
        let predicted = current + viewModel.selectedTrend.predictionDelta
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
    private var injectionDailyDose: Double? { (weightValue ?? 0) > 0 ? (weightValue! * sensitivity.factor) : nil }
    private var dailyInjectedDoseSoFar: Double {
        viewModel.injectionActions.filter { $0.deletedAt == nil && Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.dose }
    }
    private var injectionRemainingDailyDose: Double? { guard let dd = injectionDailyDose else { return nil }; return dd - dailyInjectedDoseSoFar }
    private var injectionMinDose: Double {
        if let remaining = injectionRemainingDailyDose, remaining < 0.5 { return 0 }
        return 0.5
    }
    private var injectionMaxDose: Double {
        if let remaining = injectionRemainingDailyDose {
            let stepped = floor(max(0, remaining) * 2) / 2
            return stepped
        }
        if let rec = recommendedDose { return max(injectionMinDose, rec) }
        return injectionMinDose
    }

    private var sugarLevelColor: Color {
        guard let current = sugarLevelValue, current > 0 else { return .primary }
        let predicted = current + viewModel.selectedTrend.predictionDelta
        let lower = target - 30
        let upper = target + 30
        let highUpper = target + 90
        if predicted < lower { return .red }
        if predicted <= upper { return viewModel.selectedTrend == .east ? .green : .yellow }
        if predicted <= highUpper { return .yellow }
        return .red
    }

    // MARK: - Body
    var body: some View {
        // Removed inner NavigationStack to avoid nested navigation suppression of toolbars.
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // NFC Section
                NFCSectionView(nfcManager: nfcManager, formatNumber: formatNumber, onNewReading: { g in viewModel.sugarLevel = formatNumber(g); updateInjectionDoseIfNeeded() })
                // Sugar input
                SugarInputSectionView(
                    sugarLevel: $viewModel.sugarLevel,
                    sugarLevelValue: sugarLevelValue,
                    sugarLevelColor: sugarLevelColor,
                    acceptAction: { val in acceptGlucoseReading(val) }
                )
                .focused($sugarFieldFocused)
                // Trend picker
                TrendPickerView(selectedTrend: $viewModel.selectedTrend, dismissKeyboard: dismissSugarKeyboard)
                // Recommended dose
                RecommendedDoseSectionView(
                    weightValue: weightValue,
                    sugarLevelValue: sugarLevelValue,
                    recommendedDose: recommendedDose
                )
                // Actions history (existing separate view)
                ActionsHistorySectionView(
                    injectionActions: $viewModel.injectionActions,
                    activities: $viewModel.activities,
                    activityActions: $activityHistory.activityActions,
                    registeredActivities: $viewModel.registeredActivities,
                    glucoseReadings: $viewModel.glucoseReadings,
                    showDeleteConfirm: $viewModel.showDeleteConfirm,
                    pendingDeleteId: $viewModel.pendingDeleteId
                )
            }
            .onTapGesture {
                if sugarFieldFocused {
                    dismissSugarKeyboard()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("მთავარი")
        .onAppear {
            viewModel.loadAll()
        }
        .onChange(of: viewModel.sugarLevel) { _, newValue in
            autoDismissSugarKeyboardIfNeeded(sugarLevel: newValue, dismiss: dismissSugarKeyboard)
            updateInjectionDoseIfNeeded()
        }
        .onChange(of: viewModel.selectedTrend) { _, _ in updateInjectionDoseIfNeeded() }
        .onChange(of: viewModel.injectionPeriod) { _, newValue in
            if newValue == .nighttime {
                viewModel.injectionDoseWasManuallyChanged = true
                let preset = Double(nightDoseSetting)
                viewModel.injectionDose = clampDose(preset, minValue: injectionMinDose, maxValue: injectionMaxDose)
            } else {
                viewModel.injectionDoseWasManuallyChanged = false
                updateInjectionDoseIfNeeded()
            }
        }
        .sheet(isPresented: $showInjectionSheet, onDismiss: { showPendingSuccessIfAny() }) {
            InjectionSheetView(
                isPresented: $showInjectionSheet,
                injectionPeriod: $viewModel.injectionPeriod,
                injectionDose: $viewModel.injectionDose,
                injectionMinDose: injectionMinDose,
                injectionMaxDose: injectionMaxDose,
                injectionDailyDose: injectionDailyDose,
                canIncrementDose: (viewModel.injectionDose + doseStep) <= injectionMaxDose + 0.0001,
                canDecrementDose: (viewModel.injectionDose - doseStep) >= injectionMinDose - 0.0001,
                decrementDose: {
                    viewModel.injectionDoseWasManuallyChanged = true
                    viewModel.injectionDose = clampDose(viewModel.injectionDose - doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose)
                },
                incrementDose: {
                    viewModel.injectionDoseWasManuallyChanged = true
                    viewModel.injectionDose = clampDose(viewModel.injectionDose + doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose)
                },
                saveAction: saveInjection
            )
        }
        .sheet(isPresented: $showActivitiesView, onDismiss: {
            viewModel.registeredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
            showPendingSuccessIfAny()
        }) {
            ActivitiesView(isPresented: $showActivitiesView) { activity, chosenDate in
                let action = ActivityAction(id: UUID(), date: chosenDate, activityId: activity.id)
                activityHistory.add(action)
                pendingSuccess = .activity(title: activity.title, effect: activity.averageEffect)
            }
        }
        .toolbar { mainToolbarContent }
        .overlay(successBannerOverlay, alignment: .top)
    }

    // MARK: - Success Banner
    private var successBannerOverlay: some View {
        Group { if let success = activeSuccess { SuccessBannerView(kind: success, sugarLevelColor: sugarLevelColor) { activeSuccess = nil } } }
            .animation(.easeInOut(duration: 0.25), value: activeSuccess != nil)
            .padding(.top, 8)
    }
    private func showPendingSuccessIfAny() {
        guard activeSuccess == nil, let p = pendingSuccess else { return }
        pendingSuccess = nil
        activeSuccess = p
        successHideTask?.cancel()
        let task = DispatchWorkItem { withAnimation(.easeInOut(duration: 0.25)) { activeSuccess = nil } }
        successHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    // MARK: - Injection Helpers
    private func prepareInjectionSheet() {
        viewModel.injectionDoseWasManuallyChanged = false
        let start = recommendedDose ?? injectionMinDose
        viewModel.injectionDose = clampDose(start, minValue: injectionMinDose, maxValue: injectionMaxDose)
        viewModel.injectionPeriod = .daytime
        showInjectionSheet = true
    }
    private func saveInjection() {
        let clamped = clampDose(viewModel.injectionDose, minValue: injectionMinDose, maxValue: injectionMaxDose)
        let action = InjectionAction(id: UUID(), date: Date(), period: viewModel.injectionPeriod, dose: clamped)
        viewModel.injectionActions.append(action)
        persistInjectionActions(viewModel.injectionActions, key: injectionStorageKey)
        pendingSuccess = .injection(dose: clamped, period: viewModel.injectionPeriod)
        showInjectionSheet = false
    }
    private func acceptGlucoseReading(_ value: Double) {
        viewModel.acceptGlucoseReading(value)
        pendingSuccess = .glucose(value: value)
        dismissSugarKeyboard()
        showPendingSuccessIfAny()
    }
    private func updateInjectionDoseIfNeeded() {
        guard showInjectionSheet, !viewModel.injectionDoseWasManuallyChanged, let rec = recommendedDose else { return }
        viewModel.injectionDose = clampDose(rec, minValue: injectionMinDose, maxValue: injectionMaxDose)
    }

    // MARK: - Keyboard
    private func dismissSugarKeyboard() { sugarFieldFocused = false }
    
    @ToolbarContentBuilder
    private var mainToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            NavigationLink(destination: GeneralSettingsView()) {
                Label("პარამეტრები", systemImage: "gear")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("ინექცია", action: prepareInjectionSheet)
                Button("აქტივობა", action: { showActivitiesView = true })
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("დამატება")
        }
    }
}

#Preview("Light") { NavigationStack { HubView() }.environmentObject(ActivityHistoryStore()) }
#Preview("Dark") { NavigationStack { HubView() }.preferredColorScheme(.dark).environmentObject(ActivityHistoryStore()) }
