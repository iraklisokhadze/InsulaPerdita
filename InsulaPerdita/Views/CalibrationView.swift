import SwiftUI

struct CalibrationView: View {
    @StateObject private var viewModel = CalibrationViewModel()
    @State private var showingHelp = false

    var body: some View {
        Form {
            // Status Section
            Section(header: Text("Calibration Status")) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(viewModel.calibration.isCalibrated ? "Calibrated" : "Not Calibrated")
                        .foregroundColor(viewModel.calibration.isCalibrated ? .green : .orange)
                }
                if viewModel.calibration.isCalibrated {
                    HStack { Text("Slope"); Spacer(); Text(String(format: "%.4f", viewModel.calibration.slope)) }
                    HStack { Text("Intercept"); Spacer(); Text(String(format: "%.2f", viewModel.calibration.intercept)) }
                    Button("Reset Calibration") { viewModel.resetCalibration() }
                        .foregroundColor(.red)
                }
            }

            // Reference Points Section
            Section(header: Text("Reference Points"), footer: referenceFooter) {
                if viewModel.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if viewModel.calibrationPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.lastLoadError ?? "No scans loaded yet.")
                            .foregroundColor(.secondary)
                        Button("Reload") { viewModel.refreshPoints() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    ForEach(viewModel.calibrationPoints) { point in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.scan.timestamp, style: .time)
                                    .font(.caption)
                                Text("Raw: \(point.raw)")
                                    .font(.caption2)
                                    .foregroundColor(point.raw == 0 ? .red : .secondary)
                                if point.raw == 0 { Text("raw missing") .font(.caption2).foregroundColor(.red) }
                            }
                            Spacer()
                            TextField("mg/dL", text: binding(for: point))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .accessibilityLabel("Official value for scan at \(point.scan.timestamp.formatted())")
                        }
                    }
                    Button("Reload Recent Scans") { viewModel.refreshPoints() }
                        .disabled(viewModel.isLoading)
                }
            }

            // Action Section
            Section {
                Button("Calculate and Save Calibration") { viewModel.calculateAndSave() }
                    .disabled(viewModel.calibrationPoints.filter { Double($0.officialValue) != nil }.count < 2)
            }
        }
        .navigationTitle("Calibration")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingHelp = true }) { Image(systemName: "questionmark.circle") }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Refresh") { viewModel.refreshPoints() }
                    .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showingHelp) { CalibrationHelpView() }
        .onAppear { viewModel.loadRecentScans() }
        .refreshable { viewModel.refreshPoints() }
    }

    private var referenceFooter: some View {
        Text("Provide at least two points (official reader mg/dL). The raw value comes from NFC scan meta.")
    }

    // Binding helper to mutate the array element
    private func binding(for point: CalibrationPoint) -> Binding<String> {
        guard let index = viewModel.calibrationPoints.firstIndex(where: { $0.id == point.id }) else {
            return .constant("")
        }
        return Binding<String>(
            get: { viewModel.calibrationPoints[index].officialValue },
            set: { viewModel.calibrationPoints[index].officialValue = $0 }
        )
    }
}

struct CalibrationHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Calibration Works")
                        .font(.title)

                    Text("The sensor provides a 'raw' value that needs to be converted to a familiar glucose value (mg/dL). This conversion requires calibration, which is unique to each sensor.")

                    Text("Instructions:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Scan your sensor with this app and your official reader at the same time.", systemImage: "1.circle")
                        Label("On the calibration screen, you will see a list of recent scans with their 'raw' values.", systemImage: "2.circle")
                        Label("In the text field next to a scan, enter the glucose value (in mg/dL) shown on your official reader for that same scan.", systemImage: "3.circle")
                        Label("Repeat this for at least one more scan to provide a second reference point.", systemImage: "4.circle")
                        Label("Tap 'Calculate and Save Calibration'. The app will use these points to better interpret sensor readings.", systemImage: "5.circle")
                    }

                    Text("For best results, provide reference points from different glucose levels (e.g., one low and one high).")
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Calibration Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
    
#Preview("Calibration") {
    NavigationStack { CalibrationView() }
}

#Preview("Calibration Help") {
    CalibrationHelpView()
}
