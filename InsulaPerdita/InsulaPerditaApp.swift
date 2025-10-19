import SwiftUI

@main
struct InsulaPerditaApp: App {
    @StateObject private var activityHistory = ActivityHistoryStore()
    @StateObject private var nfcManager = NFCManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(activityHistory)
                .environmentObject(nfcManager)
        }
    }
}
