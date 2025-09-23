import SwiftUI

struct InjectionSheetView: View {
    @Binding var isPresented: Bool
    @Binding var injectionPeriod: InjectionPeriod
    @Binding var injectionDose: Double

    let injectionMinDose: Double
    let injectionMaxDose: Double
    let injectionDailyDose: Double?
    let canIncrementDose: Bool
    let canDecrementDose: Bool
    let decrementDose: () -> Void
    let incrementDose: () -> Void
    let saveAction: () -> Void

    var body: some View {
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
                    doseAdjuster
                    doseInfo
                }
            }
            .navigationTitle("ინექცია")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) { Button("შენახვა") { saveAction() } }
            }
        }
    }

    private var doseAdjuster: some View {
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
    }

    private var doseInfo: some View {
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

// Preview helper
#Preview {
    InjectionSheetView(
        isPresented: .constant(true),
        injectionPeriod: .constant(.daytime),
        injectionDose: .constant(2.0),
        injectionMinDose: 0.5,
        injectionMaxDose: 8.0,
        injectionDailyDose: 16.0,
        canIncrementDose: true,
        canDecrementDose: true,
        decrementDose: {},
        incrementDose: {},
        saveAction: {}
    )
}
