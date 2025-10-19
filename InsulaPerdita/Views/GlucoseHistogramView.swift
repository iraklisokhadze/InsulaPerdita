import SwiftUI
import Charts
#if DEBUG
import os.log
#endif

// Custom diamond shape for activity markers
private struct Diamond: ChartSymbolShape {
    let perceptualUnitRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var lineWidth: CGFloat?

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        let midY = rect.midY
        p.move(to: CGPoint(x: midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: midY))
        p.addLine(to: CGPoint(x: midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: midY))
        p.closeSubpath()
        
        // If lineWidth is provided, return the stroked path, otherwise the filled path.
        // Note: The `.stroke` modifier returns a different type, which is why we do it here.
        if let lineWidth = lineWidth { return p.strokedPath(.init(lineWidth: lineWidth)) }
        return p
    }
}

#if DEBUG
private enum HistogramLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "InsulaPerdita"
    static let general = OSLog(subsystem: subsystem, category: "Histogram")
    static func d(_ message: String) { os_log("[Histogram] %{public}@", log: general, type: .debug, message) }
}
#endif

// View displaying glucose readings over time with action overlays and a simple distribution histogram.
struct GlucoseHistogramView: View {
    // Plot data models moved up so stored properties can reference them
    private struct InjectionPlot: Identifiable { let id: UUID; let date: Date; let y: Double; let dose: Double }
    private struct ActivityPlot: Identifiable { let id: UUID; let date: Date; let y: Double; let title: String }

    @EnvironmentObject var activityHistory: ActivityHistoryStore

    // Raw data loaded once
    @State private var allReadings: [GlucoseReadingAction] = []
    @State private var allInjections: [InjectionAction] = []
    @State private var allRegisteredActivities: [RegisteredActivity] = []
    @State private var allActivities: [Activity] = []

    // Data filtered and prepared for plotting
    @State private var plotReadings: [GlucoseReadingAction] = []
    @State private var plotInjections: [InjectionPlot] = []
    @State private var plotActivities: [ActivityPlot] = []

    // Reentrancy / thrash detection
    @State private var lastAppearAt: Date? = nil
    @State private var rapidAppearCount: Int = 0
    @State private var showChart: Bool = true

    // Added lifecycle/load management state
    @AppStorage("histDidInitialLoad") private var didInitialLoadFlag: Bool = false
    @AppStorage("histLastLoadAtInterval") private var lastLoadAtInterval: Double = 0 // unix time
    private var lastLoadAtDate: Date { lastLoadAtInterval > 0 ? Date(timeIntervalSince1970: lastLoadAtInterval) : .distantPast }
    private let minReloadInterval: TimeInterval = 30 // seconds cooldown for light reload

    // Time range selection (seconds)
    private struct TimeRange: Identifiable, Equatable { let id = UUID(); let title: String; let interval: TimeInterval }
    private let ranges: [TimeRange] = [
        TimeRange(title: "6ს", interval: 6 * 3600),
        TimeRange(title: "12ს", interval: 12 * 3600),
        TimeRange(title: "24ს", interval: 24 * 3600),
        TimeRange(title: "3დღე", interval: 3 * 24 * 3600),
        TimeRange(title: "7დღე", interval: 7 * 24 * 3600)
    ]
    @State private var selectedRange: TimeRange = TimeRange(title: "24ს", interval: 24 * 3600)

    @State private var now: Date = Date()

    // Refresh timer to keep 'now' moving and allow dynamic filtering (every 60s)
    private let refreshInterval: TimeInterval = 60
    @State private var activeTimer: DispatchSourceTimer? = nil // timer state (restored)

    // Added toolbar content (was missing)
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("ექსპორტი", action: exportCSV)
                Button("დათვალიერება", action: { /* placeholder for future details view */ })
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            rangePicker
            if plotReadings.isEmpty {
                Text("არ არის ჩანაწერები ამ შუალედში")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if showChart {
                    chartSection
                } else {
                    // Diagnostic fallback when chart disabled
                    VStack(spacing: 12) {
                        Text("დიაგნოსტიკა: გრაფიკი დროებით გამორთულია უცნაური სწრაფი რელოდების გამო")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        Button("გრაფიკის ჩართვა") { enableChartManually() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 260)
                }
                distributionSection
            }
        }
        .padding()
        .navigationTitle("გრაფიკი")
        .toolbar { toolbarContent }
        .onAppear { handleAppearOptimized() }
        .onDisappear { handleDisappearOptimized() }
        .onChange(of: selectedRange) { _, _ in updatePlotData(context: "selectedRangeChanged") }
        .onChange(of: now) { _, _ in updatePlotData(context: "nowTick") }
    }

    private func handleAppearOptimized() {
        #if DEBUG
        HistogramLog.d("onAppear – optimized entry didInitialLoad=\(didInitialLoadFlag) lastLoadAt=\(lastLoadAtDate)")
        #endif
        // Always advance 'now' first so time-bound filtering reflects current time.
        now = Date()
        if !didInitialLoadFlag {
            performInitialLoad()
        } else {
            let delta = Date().timeIntervalSince(lastLoadAtDate)
            #if DEBUG
            HistogramLog.d("cooldown check delta=\(String(format: "%.2f", delta)) threshold=\(minReloadInterval)")
            #endif
            if delta > minReloadInterval {
                loadAllData(light: true)
                updatePlotData(context: "cooldownReload")
            } else {
                updatePlotData(context: "resumeNoReload")
            }
        }
        startTimerIfNeeded()
    }

    private func handleDisappearOptimized() {
        #if DEBUG
        HistogramLog.d("onDisappear – optimized")
        #endif
        stopTimer()
    }

    private func performInitialLoad() {
        didInitialLoadFlag = true
        loadAllData(light: false)
        updatePlotData(context: "initial")
    }

    // Modified loadAllData with light parameter and memory logging
    private func loadAllData(light: Bool) {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent(); HistogramLog.d("loadAllData(begin) light=\(light)")
        #endif
        if !light {
            allInjections = loadInjectionActions(key: injectionStorageKey).filter { $0.deletedAt == nil }
            allRegisteredActivities = loadRegisteredActivities(key: registeredActivitiesStorageKey)
            allActivities = loadActivities(key: activitiesStorageKey)
        }
        allReadings = loadGlucoseReadings(key: glucoseReadingsStorageKey).filter { $0.deletedAt == nil }.sorted { $0.date < $1.date }
        lastLoadAtInterval = Date().timeIntervalSince1970
        #if DEBUG
        let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        HistogramLog.d("loadAllData(end) readings=\(allReadings.count) injections=\(allInjections.count) activities=\(activityHistory.activityActions.count) rawActivities=\(allActivities.count) took=\(String(format: "%.2f", dt))ms mem=\(memoryUsageString())")
        #endif
    }

    // Timer helpers guarded
    private func startTimerIfNeeded() {
        guard activeTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + refreshInterval, repeating: refreshInterval)
        timer.setEventHandler {
            now = Date()
            #if DEBUG
            HistogramLog.d("timer tick – now updated")
            #endif
            updatePlotData(context: "timerTick")
        }
        timer.resume()
        activeTimer = timer
        #if DEBUG
        HistogramLog.d("startTimerIfNeeded – scheduled every \(refreshInterval)s")
        #endif
    }
    private func stopTimer() {
        activeTimer?.cancel()
        activeTimer = nil
        #if DEBUG
        HistogramLog.d("stopTimer – cancelled")
        #endif
    }

    private func reloadData() {
        #if DEBUG
        HistogramLog.d("reloadData triggered manual")
        #endif
        loadAllData(light: false)
        now = Date()
        updatePlotData(context: "manualReload")
    }

    // MARK: - Range Picker (restored)
    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ranges) { r in
                    Button(action: {
                        #if DEBUG
                        HistogramLog.d("Range tapped -> \(r.title)")
                        #endif
                        selectedRange = r
                    }) {
                        Text(r.title)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedRange.id == r.id ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Button(action: reloadData) {
                    Image(systemName: "arrow.clockwise")
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                        .accessibilityLabel("განახლება")
                }
            }.padding(.horizontal,4)
        }
    }
    // MARK: - Chart Section (restored minimal)
    private var chartSection: some View {
        Group {
            if showChart {
                if #available(iOS 16.0, macOS 13.0, *) {
                    Chart {
                        ForEach(plotReadings) { r in
                            LineMark(x: .value("Time", r.date), y: .value("Glucose", r.value))
                                .foregroundStyle(.blue)
                        }
                        ForEach(plotInjections.prefix(10)) { inj in
                            PointMark(x: .value("Time", inj.date), y: .value("Glucose", inj.y))
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                .foregroundStyle(.orange)
                        }
                        ForEach(plotActivities.prefix(10)) { act in
                            PointMark(x: .value("Time", act.date), y: .value("Glucose", act.y))
                                .symbol(Diamond(lineWidth: 2))
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(minHeight: 260)
                } else {
                    Text("Chart არ არის ხელმისაწვდომი")
                        .foregroundColor(.secondary)
                        .frame(minHeight: 260)
                }
            }
        }
    }
    // MARK: - Distribution Section (restored)
    private struct DistributionBucket: Identifiable { let id = UUID(); let bucket: String; let count: Int; let color: Color }
    private func sugarDistribution(for readings: [GlucoseReadingAction]) -> [DistributionBucket] {
        guard !readings.isEmpty else { return [DistributionBucket(bucket: "—", count: 0, color: .gray)] }
        var low = 0, mid = 0, high = 0
        for r in readings { if r.value < 4 { low += 1 } else if r.value <= 10 { mid += 1 } else { high += 1 } }
        return [
            DistributionBucket(bucket: "დაბალი", count: low, color: .red.opacity(0.7)),
            DistributionBucket(bucket: "შუალედი", count: mid, color: .green.opacity(0.7)),
            DistributionBucket(bucket: "მაღალი", count: high, color: .yellow.opacity(0.7))
        ]
    }
    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("განაწილება").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 12) {
                    ForEach(sugarDistribution(for: plotReadings)) { item in
                        VStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color)
                                .frame(width: 24, height: max(10, CGFloat(item.count) * 6))
                            Text(item.bucket).font(.caption2)
                            Text("\(item.count)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }.padding(.vertical,4)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    // MARK: - Update Plot Data (restored)
    private func updatePlotData(context: String) {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent(); HistogramLog.d("updatePlotData(begin) context=\(context) range=\(selectedRange.title)")
        #endif
        let lowerBound = now.addingTimeInterval(-selectedRange.interval)
        let current = allReadings.filter { $0.date >= lowerBound }
        plotReadings = current
        let injFiltered = allInjections.filter { $0.date >= lowerBound }
        plotInjections = injFiltered.compactMap { inj in
            guard let y = nearestGlucoseValue(in: current, before: inj.date) else { return nil }
            return InjectionPlot(id: inj.id, date: inj.date, y: y, dose: inj.dose)
        }
        let acts = activityHistory.activityActions.filter { $0.deletedAt == nil && $0.date >= lowerBound }
        plotActivities = acts.compactMap { act in
            guard let y = nearestGlucoseValue(in: current, before: act.date) else { return nil }
            return ActivityPlot(id: act.id, date: act.date, y: y, title: activityTitle(act.activityId))
        }
        #if DEBUG
        let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        HistogramLog.d("updatePlotData(end) context=\(context) readings=\(plotReadings.count) injections=\(plotInjections.count) activities=\(plotActivities.count) took=\(String(format: "%.2f", dt))ms")
        #endif
    }
    // MARK: - Helpers (restored)
    private func nearestGlucoseValue(in readings: [GlucoseReadingAction], before date: Date) -> Double? {
        readings.last(where: { $0.date <= date })?.value ?? readings.first?.value
    }
    private func activityTitle(_ id: UUID) -> String {
        if let r = allRegisteredActivities.first(where: { $0.id == id }) { return r.title }
        if let a = allActivities.first(where: { $0.id == id }) { return a.title }
        return "აქტ" // fallback
    }
    private func memoryUsageString() -> String {
        var info = task_vm_info_data_t(); var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size)/4
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        if kr == KERN_SUCCESS { return String(format: "%.1fMB", Double(info.phys_footprint)/1024/1024) }
        return "n/a"
    }
    private func enableChartManually() {
        rapidAppearCount = 0; showChart = true
        #if DEBUG
        HistogramLog.d("enableChartManually – chart re-enabled")
        #endif
    }
    private func exportCSV() {
        let header = "type,date,value,extra"
        var rows: [String] = [header]
        let df = ISO8601DateFormatter()
        for g in allReadings { rows.append("glucose,\(df.string(from: g.date)),\(g.value),") }
        for inj in allInjections { rows.append("injection,\(df.string(from: inj.date)),,dose=\(inj.dose)") }
        for act in activityHistory.activityActions { rows.append("activity,\(df.string(from: act.date)),,id=\(act.activityId.uuidString)") }
        let csv = rows.joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = csv
        #endif
        #if DEBUG
        HistogramLog.d("exportCSV rows=\(rows.count)")
        #endif
    }
}

#Preview { NavigationStack { GlucoseHistogramView() }.environmentObject(ActivityHistoryStore()) }
