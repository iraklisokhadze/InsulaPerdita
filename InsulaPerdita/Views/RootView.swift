import SwiftUI

struct RootView: View {
    @EnvironmentObject private var activityHistory: ActivityHistoryStore
    @State private var selectedTab: Int = 0
    @State private var lastTabChangeAt: Date = .distantPast
    @State private var rapidChangeCount: Int = 0
    @State private var suppressedChanges: Int = 0
    private let rapidInterval: TimeInterval = 0.25 // threshold between changes considered rapid
    private let rapidBurstThreshold: Int = 8 // number of rapid changes before we start ignoring

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HubView().navigationBarTitleDisplayMode(.inline) }
                .tabItem { Label("მთავარი", systemImage: "house") }
                .tag(0)
            NavigationStack { GlucoseHistogramView().navigationBarTitleDisplayMode(.inline) }
                .tabItem { Label("გრაფიკი", systemImage: "chart.xyaxis.line") }
                .tag(1)
        }
        .onChange(of: selectedTab) { _, newValue in
            handleTabChange(newValue)
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                if suppressedChanges > 0 { Text("Suppressed: \(suppressedChanges)").font(.caption2).padding(6).background(Color.orange.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 8)) }
                if rapidChangeCount > 0 { Text("Rapid: \(rapidChangeCount)").font(.caption2).padding(6).background(Color.red.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 8)) }
            }.padding(.trailing,8).padding(.bottom,4)
        }
        #endif
    }

    private func handleTabChange(_ newValue: Int) {
        let now = Date()
        let delta = now.timeIntervalSince(lastTabChangeAt)
        if delta < rapidInterval {
            rapidChangeCount += 1
            if rapidChangeCount > rapidBurstThreshold { // ignore ultra-rapid toggles beyond threshold
                suppressedChanges += 1
                // Do not revert or force any tab; simply ignore logging after threshold
                return
            }
            #if DEBUG
            Logger.shared.log(.tabChangeSuppressed, parameters: ["deltaMs": Int(delta*1000), "rapidCount": rapidChangeCount])
            #endif
        } else {
            rapidChangeCount = 0
        }
        lastTabChangeAt = now
        #if DEBUG
        Logger.shared.log(.tabChanged, parameters: ["tab": (newValue == 0 ? "Hub" : "Histogram"), "rapidCount": rapidChangeCount])
        if rapidChangeCount >= rapidBurstThreshold { Logger.shared.log(.tabChangeSuppressed, parameters: ["reason":"burst","count": rapidChangeCount]) }
        #endif
    }
}

#Preview { RootView().environmentObject(ActivityHistoryStore()) }
