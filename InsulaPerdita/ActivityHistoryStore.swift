import Foundation
import Combine

class ActivityHistoryStore: ObservableObject {
    @Published var activityActions: [ActivityAction] = []
    private let storageKey = "activityActions.v1"

    init() {
        load()
    }

    func add(_ action: ActivityAction) {
        activityActions.append(action)
        persist()
    }

    func persist() {
        do {
            let data = try JSONEncoder().encode(activityActions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("ActivityHistoryStore: persist failed: \(error)")
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            activityActions = try JSONDecoder().decode([ActivityAction].self, from: data)
        } catch {
            print("ActivityHistoryStore: load failed: \(error)")
        }
    }
}
