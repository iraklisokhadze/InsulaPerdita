import SwiftUI

struct ContentView: View {
    // Persisted settings
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("sensitivity") private var sensitivityStorage: String = "medium"
    @AppStorage("target") private var targetStorage: String = "110"
    
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
    @State private var showActivitySheet = false
    @State private var newActivityTitle: String = ""
    @State private var newActivityEffect: Int? = nil
    @State private var editingActivityIndex: Int? = nil
    private let activityEffectOptions: [Int] = [-150,-100,-50,50,100,150]
    private let activitiesStorageKey = "ActivitiesStore.v1"
    
    private let injectionStorageKey = "injectionActions.v1"
    private let doseStep: Double = 0.5
    
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
    private var canIncrementDose: Bool { (injectionDose + doseStep) <= injectionMaxDose + 0.0001 }
    private var canDecrementDose: Bool { (injectionDose - doseStep) >= injectionMinDose - 0.0001 }
    
    // Registered activities (pre-registered reusable set)
    @State private var showRegisteredActivityPicker = false
    @State private var selectedRegisteredActivityId: UUID? = nil
    @State private var registeredActivities: [RegisteredActivity] = []
    @State private var activityActions: [ActivityAction] = []
    @State private var showRegisteredActivitiesSheet = false
    @State private var newRegisteredActivityTitle: String = ""
    @State private var newRegisteredActivityEffect: Int? = nil
    @State private var editingRegisteredActivityIndex: Int? = nil
    private let registeredActivitiesStorageKey = "RegisteredActivities.v1"
    private let activityActionsStorageKey = "ActivityActions.v1"
    
    // NEW: drives programmatic navigation to SettingsView
    @State private var showSettings: Bool = false
    
    // Replace body with simpler wrapper referencing extracted rootContent
    var body: some View {
        NavigationStack { rootContent }
    }
    
    // Extracted from previous body chain to reduce generic nesting complexity
    private var rootContent: some View {
        ScrollView { mainVStack }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .toolbar { leadingToolbar }
            .toolbar { trailingToolbar }
            .toolbar { keyboardToolbar }
            .onAppear {
                // Load persisted data with correct keys
                injectionActions = loadInjectionActions(key: injectionStorageKey)
                activities = loadActivities(key: activitiesStorageKey)
                registeredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
                activityActions = loadActivityActions(key: activityActionsStorageKey)
            }
            .onChange(of: sugarLevel) { _, newValue in
                autoDismissSugarKeyboardIfNeeded(sugarLevel: newValue, dismiss: dismissSugarKeyboard)
                updateInjectionDoseIfNeeded()
            }
            .onChange(of: selectedTrend) { _, _ in updateInjectionDoseIfNeeded() }
            //.onChange(of: weight) { _, _ in updateInjectionDoseIfNeeded() }
            //.onChange(of: sensitivityStorage) { _, _ in updateInjectionDoseIfNeeded() }
            //.onChange(of: targetStorage) { _, _ in updateInjectionDoseIfNeeded() }
            .onChange(of: nfcManager.lastReading) { _, newValue in
                if let g = newValue?.glucose { sugarLevel = formatNumber(g) }
                updateInjectionDoseIfNeeded()
            }
            .sheet(isPresented: $showInjectionSheet) { injectionSheet }
            .sheet(isPresented: $showActivitySheet) { activitySheet }
            .sheet(isPresented: $showRegisteredActivitiesSheet) { registeredActivitiesSheet }
            .sheet(isPresented: $showRegisteredActivityPicker) { registeredActivityPickerSheet }
            .confirmationDialog("დამატება", isPresented: $showActionChooser, titleVisibility: .visible) {
                Button("ინექცია") { prepareInjectionSheet() }
                Button("აქტივობა") { beginAddActivity() }
                Button("რეგისტრირებული აქტივობა") { beginAddRegisteredActivityAction() }
                Button("გაუქმება", role: .cancel) {}
            }
            // Replaced deprecated hidden NavigationLink with navigationDestination
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
    }
    
    private var mainVStack: some View {
        VStack(spacing: 20) {
            headerSection
            nfcSection
            inputSection
            trendSection
            resultSection
            actionsSection
        }
    }
    
    // MARK: - Toolbars
    private var leadingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                // Changed: Button triggers programmatic navigation
                Button {
                    showSettings = true
                } label: {
                    Label("პარამეტრები", systemImage: "gear")
                }
                NavigationLink(destination: ActivitiesView()) {
                    Label("აქტივობები", systemImage: "list.bullet")
                }
            } label: {
                Image(systemName: "gearshape").font(.title2)
            }
        }
    }
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showActionChooser = true }) {
                Image(systemName: "plus.circle").font(.title2)
            }.accessibilityLabel("დამატება")
        }
    }
    
    private func updateInjectionDoseIfNeeded() {
        guard showInjectionSheet, !injectionDoseWasManuallyChanged, let rec = recommendedDose else { return }
        injectionDose = clampDose(rec, minValue: injectionMinDose, maxValue: injectionMaxDose)
    }
    
    // MARK: - Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(targetDisplayText).font(.subheadline).foregroundColor(.secondary)
        }
    }
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let w = weightValue {
                Text("წონა: \(formatNumber(w)) კგ").font(.subheadline).foregroundColor(.secondary)
            } else {
                Text("წონა არ არის დაყენებული პარამეტრებში").font(.subheadline).foregroundColor(.orange)
            }
            Text("მგრძნობიარობა: \(sensitivity.rawValue)").font(.subheadline).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("შაქრის დონე")
                TextField("მმოლ/ლ", text: $sugarLevel)
                    .keyboardType(.decimalPad)
                    .focused($sugarFieldFocused)
                    .font(.system(size: 26, weight: .semibold))
                    .padding(.vertical, 6)
                    .foregroundColor(sugarLevelColor)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(sugarLevel.isEmpty ? Color.secondary.opacity(0.3) : sugarLevelColor, lineWidth: 2))
                    .textFieldStyle(.roundedBorder)
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
            if sugarLevelValue == nil || (sugarLevelValue ?? 0) <= 0 {
                Text("შეიყვანეთ მნიშვნელობები").foregroundColor(.secondary)
            } else if let dose = recommendedDose {
                Text("რეკომენდირებული დოზა: \(formatNumber(dose)) ერთეული").font(.headline).fontWeight(.semibold)
            } else {
                Text("შეიყვანეთ მნიშვნელობები").foregroundColor(.secondary)
            }
        }
    }
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let combined = buildUnifiedActions()
            if !combined.isEmpty {
                Text("მოქმედებები").font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(combined) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon).foregroundColor(item.tint).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.primaryLine).font(.subheadline).fontWeight(.semibold)
                                Text(item.secondaryLine).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
    
    // MARK: - Unified Action Model (simplified for compiler)
    private func buildUnifiedActions() -> [UnifiedAction] {
        var unified: [UnifiedAction] = []
        unified.reserveCapacity(injectionActions.count + activities.count + activityActions.count)
        // Injections
        for inj in injectionActions {
            unified.append(UnifiedAction(
                id: "inj-" + inj.id.uuidString,
                date: inj.date,
                icon: "syringe",
                tint: inj.period == .daytime ? .orange : .indigo,
                primaryLine: "ინექცია • " + formatNumber(inj.dose) + " ერთ",
                secondaryLine: inj.period.display + " • " + formatDate(inj.date)
            ))
        }
        // Ad-hoc activities
        for act in activities {
            let date = act.createdAt ?? Date.distantPast
            let tint = effectColor(act.averageEffect)
            let effectString = (act.averageEffect > 0 ? "+" : "") + String(act.averageEffect)
            unified.append(UnifiedAction(
                id: "act-" + act.id.uuidString,
                date: date,
                icon: act.averageEffect > 0 ? "arrow.up.circle" : (act.averageEffect < 0 ? "arrow.down.circle" : "circle"),
                tint: tint,
                primaryLine: act.title + " • " + effectString,
                secondaryLine: formatDate(date)
            ))
        }
        // Pre-registered activity actions
        for action in activityActions {
            if let act = registeredActivities.first(where: { $0.id == action.activityId }) {
                let tint = effectColor(act.averageEffect)
                let effectString = (act.averageEffect > 0 ? "+" : "") + String(act.averageEffect)
                unified.append(UnifiedAction(
                    id: "regact-" + action.id.uuidString,
                    date: action.date,
                    icon: act.averageEffect > 0 ? "arrow.up.circle" : (act.averageEffect < 0 ? "arrow.down.circle" : "circle"),
                    tint: tint,
                    primaryLine: act.title + " • " + effectString,
                    secondaryLine: formatDate(action.date)
                ))
            }
        }
        return unified.sorted { $0.date > $1.date }
    }
    
    // MARK: - Sheets & Forms
    private var injectionSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("დრო")) {
                    Picker("", selection: $injectionPeriod) {
                        ForEach(InjectionPeriod.allCases) { p in
                            Image(systemName: p.symbol)
                                .tag(p)
                                .accessibilityLabel(p.display)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("დოზა")) {
                    HStack(alignment: .center, spacing: 0) {
                        Button(action: decrementDose) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .frame(width: 34, height: 34)
                        }
                        .disabled(!canDecrementDose)
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .padding(.trailing, 12)
                        Spacer(minLength: 8)
                        Text(formatNumber(injectionDose))
                            .font(.system(size: 34, weight: .semibold))
                            .frame(minWidth: 80)
                            .monospacedDigit()
                            .accessibilityLabel("Dose \(formatNumber(injectionDose))")
                        Spacer(minLength: 8)
                        Button(action: incrementDose) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .frame(width: 34, height: 34)
                        }
                        .disabled(!canIncrementDose)
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .padding(.leading, 12)
                    }
                    .padding(.vertical, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("მინ: \(formatNumber(injectionMinDose)) მაქს: \(formatNumber(injectionMaxDose))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if injectionDailyDose == nil {
                            Text("მაქსიმუმი გამოთვლილია რეკომენდაციიდან ან მინიმუმიდან (დააყენე წონა უფრო ზუსტი ზღვრისთვის)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("ინექცია")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { showInjectionSheet = false } }
                ToolbarItem(placement: .confirmationAction) { Button("შენახვა") { saveInjection() } }
            }
        }
    }
    
    private var activitySheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("დასახელება")) { TextField("დასახელება", text: $newActivityTitle) }
                Section(header: Text("საშალო გავლენა")) { activityEffectChips(selected: $newActivityEffect) }
            }
            .navigationTitle(editingActivityIndex == nil ? "ახალი აქტივობა" : "რედაქტირება")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { showActivitySheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingActivityIndex == nil ? "შენახვა" : "განახლება") { saveActivity() }.disabled(!canSaveActivity)
                }
            }
        }
    }
    
    private var registeredActivitiesSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("დასახელება")) { TextField("დასახელება", text: $newRegisteredActivityTitle) }
                Section(header: Text("საშალო გავლენა")) { activityEffectChips(selected: $newRegisteredActivityEffect) }
                Section(header: Text("შენახული აქტივობები")) {
                    if registeredActivities.isEmpty {
                        Text("აქტივობები ჯერ არ არის").foregroundColor(.secondary)
                    } else {
                        ForEach(registeredActivities.indices, id: \ .self) { idx in
                            let act = registeredActivities[idx]
                            HStack {
                                Text(act.title)
                                Spacer()
                                Text((act.averageEffect > 0 ? "+" : "") + String(act.averageEffect))
                                    .foregroundColor(effectColor(act.averageEffect))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                newRegisteredActivityTitle = act.title
                                newRegisteredActivityEffect = act.averageEffect
                                editingRegisteredActivityIndex = idx
                            }
                        }
                        .onDelete { indices in
                            registeredActivities.remove(atOffsets: indices)
                            persistRegisteredActivities(registeredActivities, key: registeredActivitiesStorageKey)
                        }
                    }
                }
            }
            .navigationTitle(editingRegisteredActivityIndex == nil ? "ახალი აქტივობა" : "რედაქტირება")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { showRegisteredActivitiesSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingRegisteredActivityIndex == nil ? "შენახვა" : "განახლება") { saveRegisteredActivity() }.disabled(!canSaveRegisteredActivity)
                }
            }
        }
    }
    
    private func activityEffectChips(selected: Binding<Int?>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activityEffectOptions, id: \ .self) { value in
                    let isSel = value == selected.wrappedValue
                    Text((value > 0 ? "+" : "") + String(value))
                        .font(.subheadline.monospacedDigit())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isSel ? effectColor(value) : Color(.systemGray5))
                        .foregroundColor(isSel ? .white : effectColor(value))
                        .clipShape(Capsule())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selected.wrappedValue = value } }
                }
            }.padding(.vertical, 4)
        }
    }
    
    private var registeredActivityPickerSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("აირჩიეთ აქტივობა")) {
                    if registeredActivities.isEmpty {
                        Text("ჯერ არ არის რეგისტრირებული აქტივობები").foregroundColor(.secondary)
                    } else {
                        ForEach(registeredActivities) { act in
                            Button {
                                selectedRegisteredActivityId = act.id
                                saveRegisteredActivityAction()
                            } label: {
                                HStack {
                                    Text(act.title)
                                    Spacer()
                                    Text((act.averageEffect > 0 ? "+" : "") + String(act.averageEffect))
                                        .foregroundColor(effectColor(act.averageEffect))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("აქტივობის დამატება")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { showRegisteredActivityPicker = false } } }
        }
    }
    
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
        activityActions.append(action)
        persistActivityActions(activityActions, key: activityActionsStorageKey)
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
    private func decrementDose() { guard canDecrementDose else { return }; injectionDoseWasManuallyChanged = true; injectionDose = clampDose(injectionDose - doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose) }
    private func incrementDose() { guard canIncrementDose else { return }; injectionDoseWasManuallyChanged = true; injectionDose = clampDose(injectionDose + doseStep, minValue: injectionMinDose, maxValue: injectionMaxDose) }
    private func saveInjection() {
        let clamped = clampDose(injectionDose, minValue: injectionMinDose, maxValue: injectionMaxDose)
        let action = InjectionAction(id: UUID(), date: Date(), period: injectionPeriod, dose: clamped)
        injectionActions.append(action)
        persistInjectionActions(injectionActions, key: injectionStorageKey)
        showInjectionSheet = false
    }
    
    // MARK: - Keyboard
    private var keyboardToolbar: some ToolbarContent { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("დახურვა") { dismissSugarKeyboard() } } }
    private func dismissSugarKeyboard() { sugarFieldFocused = false }
    private func autoDismissSugarKeyboardIfNeeded(sugarLevel: String, dismiss: () -> Void) { let digits = sugarLevel.filter { $0.isNumber }.count; if digits >= 3 { dismiss() } }
    
    // MARK: - NFC Section
    private var nfcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NFC სენსორი").font(.headline)
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
