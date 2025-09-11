import SwiftUI

struct GeneralSettingsView: View { // renamed from SettingsView
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("sensitivity") private var sensitivityStorage: String = "medium"
    @AppStorage("target") private var targetStorage: String = "110" // added target

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
                }
                Picker("მგრძნობიარობა", selection: $sensitivityStorage) {
                    ForEach(Sensitivity.allCases) { s in
                        Text(s.rawValue).tag(s.storageValue)
                    }
                }
            }
        }
        .navigationTitle("პარამეტრები") // changed from "General"
        .onAppear { ensureDefaultTarget() }
        .onChange(of: targetStorage) { oldValue, _ in validateTarget(oldValue: oldValue) }
    }

    private func ensureDefaultTarget() {
        if targetStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetStorage = "110"
        }
    }

    private func validateTarget(oldValue: String) {
        let trimmed = targetStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            targetStorage = "110"
            return
        }
        // Accept digits, comma, dot
        let allowed = trimmed.filter { "0123456789,.".contains($0) }
        if allowed != trimmed { targetStorage = allowed }
        let normalized = allowed.replacingOccurrences(of: ",", with: ".")
        if Double(normalized) == nil { // revert if not numeric
            targetStorage = oldValue.isEmpty ? "110" : oldValue
        }
    }

    private func normalizeTarget() {
        validateTarget(oldValue: targetStorage)
    }
}

struct SettingsView: View { // new container listing items
    var body: some View {
        List {
            Section { // first item
                NavigationLink("პარამეტრები") { GeneralSettingsView() } // changed label
            }
            Section { // activities section
                NavigationLink("აქტივობები") { ActivitiesView() }
            }
        }
        .navigationTitle("პარამეტრები")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SettingsView() }
    }
}
