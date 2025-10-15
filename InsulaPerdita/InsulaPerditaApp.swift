import SwiftUI

@main
struct InsulaPerditaApp: App {
    @StateObject private var activityHistoryStore = ActivityHistoryStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityHistoryStore)
        }
    }
}
