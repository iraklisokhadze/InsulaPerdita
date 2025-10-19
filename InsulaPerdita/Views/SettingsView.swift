import SwiftUI

struct GeneralSettingsView: View { // renamed from SettingsView
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("sensitivity") private var sensitivityStorage: String = "medium"
    @AppStorage("target") private var targetStorage: String = "110" // added target
    @AppStorage("nightDose") private var nightDose: Int = 10 // ღამის ნემსის დოზა (1-99)
    @State private var lastValidTarget: String = "110" // track last valid numeric target
    @AppStorage("isAutoScanOnProximityEnabled") private var isAutoScanOnProximityEnabled: Bool = false // NFC auto-scan setting
    @EnvironmentObject private var nfcManager: NFCManager // added

    var body: some View {
        Form {
            Section(header: Text("ძირითადი")) {
                HStack {
                    Text("წონა")
                    Spacer()
                    TextField("კგ", text: $weight)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 160)
                        .onChange(of: weight) { oldValue, newValue in
                            Logger.shared.log(.settingChanged, parameters: ["setting": "weight", "old": oldValue, "value": newValue])
                        }
                }
                // Night dose integer stepper (no keyboard)
                Stepper(value: $nightDose, in: 1...99) {
                    HStack {
                        Text("ღამის ნემსის დოზა")
                        Spacer()
                        Text("\(nightDose)")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel("ღამის ნემსის დოზა")
                .onChange(of: nightDose) { oldValue, newValue in
                    Logger.shared.log(.settingChanged, parameters: ["setting": "nightDose", "old": "\(oldValue)", "value": "\(newValue)"])
                    if newValue < 1 { nightDose = 1 }
                    if newValue > 99 { nightDose = 99 }
                }
                // Target input
                HStack {
                    Text("სამიზნე")
                    Spacer()
                    TextField("მმოლ/ლ", text: $targetStorage)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 160)
                        .onSubmit { normalizeTarget() }
                        .onChange(of: targetStorage) { _, newValue in
                            Logger.shared.log(.settingChanged, parameters: ["setting": "target", "value": newValue])
                            validateTarget()
                        }
                }
                Picker("მგრძნობიარობა", selection: $sensitivityStorage) {
                    ForEach(Sensitivity.allCases) { s in
                        Text(s.rawValue).tag(s.storageValue)
                    }
                }
                .onChange(of: sensitivityStorage) { oldValue, newValue in
                    Logger.shared.log(.settingChanged, parameters: ["setting": "sensitivity", "old": oldValue, "value": newValue])
                }
            }

            Section(header: Text("NFC")) {
                Toggle("ავტომატური სკანირება", isOn: $isAutoScanOnProximityEnabled)
                    .onChange(of: isAutoScanOnProximityEnabled) { oldValue, newValue in
                        Logger.shared.log(.settingChanged, parameters: ["setting": "isAutoScanOnProximityEnabled", "old": "\(oldValue)", "value": "\(newValue)"])
                        // propagate explicitly to NFCManager (breaks previous feedback loop)
                        nfcManager.setAutoScanEnabled(newValue)
                    }
                Text("როდესაც ჩართულია, სენსორთან iPhone-ის მიახლოებისას სკანირება ავტომატურად დაიწყება.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                NavigationLink("სკანის ლოგები") { ScanLogsView() }
                NavigationLink("კალიბრაცია") { CalibrationView() } // NEW: direct calibration access inside NFC section
            }
        }
        .navigationTitle("პარამეტრები")
        .onAppear {
            ensureDefaultTarget(); normalizeNightDose(); lastValidTarget = sanitizedNumericString(targetStorage) ?? lastValidTarget
            // ensure manager matches persisted value (idempotent)
            nfcManager.setAutoScanEnabled(isAutoScanOnProximityEnabled)
        }
    }

    private func ensureDefaultTarget() {
        if targetStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetStorage = "110"
        }
    }

    private func validateTarget() {
        let trimmed = targetStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            targetStorage = lastValidTarget
            return
        }
        // Accept digits, comma, dot (filter out others)
        let allowed = trimmed.filter { "0123456789,.".contains($0) }
        if allowed != trimmed { targetStorage = allowed }
        if let numeric = sanitizedNumericString(allowed) {
            lastValidTarget = numeric // remember sanitized numeric string
        } else {
            // revert to last valid
            targetStorage = lastValidTarget
        }
    }

    private func sanitizedNumericString(_ input: String) -> String? {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        if Double(normalized) != nil { return input } // keep user formatting (comma vs dot) if numeric
        return nil
    }

    private func normalizeTarget() { validateTarget() }

    private func normalizeNightDose() {
        if nightDose < 1 || nightDose > 99 { nightDose = min(max(nightDose, 1), 99) }
    }
}

private struct ActivitiesWrapper: View { // supplies required params for ActivitiesView when navigated
    @EnvironmentObject var activityHistory: ActivityHistoryStore
    var body: some View {
        ActivitiesView(isPresented: .constant(true), saveAction: { activity, chosenDate in
            let action = ActivityAction(id: UUID(), date: chosenDate, activityId: activity.id)
            activityHistory.add(action)
        }, showsCloseButton: false)
    }
}

struct SettingsView: View { // new container listing items
    var body: some View {
        List {
            Section { // first item
                NavigationLink("პარამეტრები") { GeneralSettingsView() } // changed label
                NavigationLink("კალიბრაცია") { CalibrationView() } // NEW: calibration link at root settings
            }
            Section { // activities section
                NavigationLink("აქტივობები") { ActivitiesWrapper() }
            }
            Section { // logs quick access
                NavigationLink("NFC ლოგები") { ScanLogsView() }
            }
        }
        .navigationTitle("პარამეტრები")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SettingsView() }
            .environmentObject(ActivityHistoryStore())
            .environmentObject(NFCManager()) // provide manager for toggle usage
    }
}
