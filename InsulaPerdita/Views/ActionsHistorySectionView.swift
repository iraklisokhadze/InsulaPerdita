import SwiftUI

struct ActionsHistorySectionView: View {
    @Binding var injectionActions: [InjectionAction]
    @Binding var activities: [Activity]
    @Binding var activityActions: [ActivityAction]
    @Binding var registeredActivities: [RegisteredActivity]
    @Binding var glucoseReadings: [GlucoseReadingAction]
    @Binding var showDeleteConfirm: Bool
    @Binding var pendingDeleteId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let combined = buildUnifiedActions()
            if !combined.isEmpty {
                Text("ისტორია").font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(combined) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .foregroundColor(item.isDeleted ? .gray : item.tint)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.primaryLine)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .strikethrough(item.isDeleted, color: .gray)
                                    if item.isDeleted {
                                        Text("(წაშლილია)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Text(item.secondaryLine)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if item.isDeleted {
                                Button("აღდგენა") { restoreUnified(id: item.id) }
                                    .font(.caption)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .opacity(item.isDeleted ? 0.45 : 1.0)
                        .contextMenu {
                            if item.isDeleted {
                                Button { restoreUnified(id: item.id) } label: { Label("აღდგენა", systemImage: "arrow.uturn.backward") }
                            } else {
                                Button(role: .destructive) { requestDeletion(item.id) } label: { Label("წაშლა", systemImage: "trash") }
                            }
                        }
                        .onLongPressGesture { if !item.isDeleted { requestDeletion(item.id) } }
                    }
                }
            }
        }
        .confirmationDialog("ნამდვილად გსურთ ჩანაწერის წაშლა?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("წაშლა", role: .destructive) { performDeletion() }
            Button("გაუქმება", role: .cancel) { pendingDeleteId = nil }
        }
    }

    // MARK: - Build unified actions
    private func buildUnifiedActions() -> [UnifiedAction] {
        var unified: [UnifiedAction] = []
        unified.reserveCapacity(injectionActions.count + activities.count + activityActions.count + glucoseReadings.count)
        for inj in injectionActions { // include deleted
            unified.append(UnifiedAction(
                id: "inj-" + inj.id.uuidString,
                date: inj.date,
                icon: "syringe",
                tint: inj.period == .daytime ? .orange : .indigo,
                primaryLine: "ინექცია • " + formatNumber(inj.dose) + " ერთ",
                secondaryLine: inj.period.display + " • " + formatDate(inj.date),
                isDeleted: inj.deletedAt != nil
            ))
        }
        for reading in glucoseReadings {
            unified.append(UnifiedAction(
                id: "gluc-" + reading.id.uuidString,
                date: reading.date,
                icon: "drop",
                tint: .blue,
                primaryLine: "შაქარი • " + formatNumber(reading.value) + " მმოლ/ლ",
                secondaryLine: formatDate(reading.date),
                isDeleted: reading.deletedAt != nil
            ))
        }
        for act in activities { // legacy ad-hoc
            let date = act.createdAt ?? Date.distantPast
            let tint = effectColor(act.averageEffect)
            let effectString = (act.averageEffect > 0 ? "+" : "") + String(act.averageEffect)
            unified.append(UnifiedAction(
                id: "act-" + act.id.uuidString,
                date: date,
                icon: act.averageEffect > 0 ? "arrow.up.circle" : (act.averageEffect < 0 ? "arrow.down.circle" : "circle"),
                tint: tint,
                primaryLine: act.title + " • " + effectString,
                secondaryLine: formatDate(date),
                isDeleted: act.deletedAt != nil
            ))
        }
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
                    secondaryLine: formatDate(action.date),
                    isDeleted: action.deletedAt != nil
                ))
            }
        }
        return unified.sorted { $0.date > $1.date }
    }

    // MARK: - Deletion Lifecycle
    private func requestDeletion(_ id: String) { pendingDeleteId = id; showDeleteConfirm = true }

    private func performDeletion() {
        guard let id = pendingDeleteId else { return }
        defer { pendingDeleteId = nil }
        let now = Date()
        if id.hasPrefix("inj-") {
            let uuidString = String(id.dropFirst(4))
            if let uuid = UUID(uuidString: uuidString), let idx = injectionActions.firstIndex(where: { $0.id == uuid }) {
                if injectionActions[idx].deletedAt == nil { injectionActions[idx].deletedAt = now }
                persistInjectionActions(injectionActions, key: injectionStorageKey)
            }
        } else if id.hasPrefix("gluc-") {
            let uuidString = String(id.dropFirst(5))
            if let uuid = UUID(uuidString: uuidString), let idx = glucoseReadings.firstIndex(where: { $0.id == uuid }) {
                if glucoseReadings[idx].deletedAt == nil { glucoseReadings[idx].deletedAt = now }
                persistGlucoseReadings(glucoseReadings, key: glucoseReadingsStorageKey)
            }
        } else if id.hasPrefix("regact-") {
            let uuidString = String(id.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString), let idx = activityActions.firstIndex(where: { $0.id == uuid }) {
                if activityActions[idx].deletedAt == nil { activityActions[idx].deletedAt = now }
                persistActivityActions(activityActions, key: activityActionsStorageKey)
            }
        } else if id.hasPrefix("act-") {
            let uuidString = String(id.dropFirst(4))
            if let uuid = UUID(uuidString: uuidString), let idx = activities.firstIndex(where: { $0.id == uuid }) {
                if activities[idx].deletedAt == nil { activities[idx].deletedAt = now }
                persistActivities(activities, key: activitiesStorageKey)
            }
        }
    }

    private func restoreUnified(id: String) {
        if id.hasPrefix("inj-") {
            let uuidString = String(id.dropFirst(4))
            if let uuid = UUID(uuidString: uuidString), let idx = injectionActions.firstIndex(where: { $0.id == uuid }) {
                injectionActions[idx].deletedAt = nil
                persistInjectionActions(injectionActions, key: injectionStorageKey)
            }
        } else if id.hasPrefix("gluc-") {
            let uuidString = String(id.dropFirst(5))
            if let uuid = UUID(uuidString: uuidString), let idx = glucoseReadings.firstIndex(where: { $0.id == uuid }) {
                glucoseReadings[idx].deletedAt = nil
                persistGlucoseReadings(glucoseReadings, key: glucoseReadingsStorageKey)
            }
        } else if id.hasPrefix("regact-") {
            let uuidString = String(id.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString), let idx = activityActions.firstIndex(where: { $0.id == uuid }) {
                activityActions[idx].deletedAt = nil
                persistActivityActions(activityActions, key: activityActionsStorageKey)
            }
        } else if id.hasPrefix("act-") {
            let uuidString = String(id.dropFirst(4))
            if let uuid = UUID(uuidString: uuidString), let idx = activities.firstIndex(where: { $0.id == uuid }) {
                activities[idx].deletedAt = nil
                persistActivities(activities, key: activitiesStorageKey)
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper((sampleInjections(), sampleActivities(), sampleActivityActions(), sampleRegisteredActivities(), sampleGlucoseReadings())) { injBinding, actsBinding, actActionsBinding, regActsBinding, glucBinding in
        ActionsHistorySectionView(
            injectionActions: injBinding,
            activities: actsBinding,
            activityActions: actActionsBinding,
            registeredActivities: regActsBinding,
            glucoseReadings: glucBinding,
            showDeleteConfirm: .constant(false),
            pendingDeleteId: .constant(nil)
        )
        .padding()
    }
}

// MARK: - Preview Helpers (lightweight sample data)
private func sampleInjections() -> [InjectionAction] {
    [InjectionAction(id: UUID(), date: Date().addingTimeInterval(-600), period: .daytime, dose: 2.0)]
}
private func sampleActivities() -> [Activity] {
    [Activity(id: UUID(), title: "სეირნობა", averageEffect: -50, createdAt: Date())]
}
private func sampleActivityActions() -> [ActivityAction] {
    []
}
private func sampleRegisteredActivities() -> [RegisteredActivity] {
    [RegisteredActivity(id: UUID(), title: "ვარჯიში", averageEffect: -100)]
}
private func sampleGlucoseReadings() -> [GlucoseReadingAction] {
    [GlucoseReadingAction(id: UUID(), date: Date().addingTimeInterval(-300), value: 7.2)]
}

// Generic stateful wrapper for previews
struct StatefulPreviewWrapper<A, B, C, D, E, Content: View>: View { // updated for 5 bindings
    @State var a: A
    @State var b: B
    @State var c: C
    @State var d: D
    @State var e: E
    let content: (Binding<A>, Binding<B>, Binding<C>, Binding<D>, Binding<E>) -> Content
    init(_ values: (A, B, C, D, E), content: @escaping (Binding<A>, Binding<B>, Binding<C>, Binding<D>, Binding<E>) -> Content) {
        _a = State(initialValue: values.0)
        _b = State(initialValue: values.1)
        _c = State(initialValue: values.2)
        _d = State(initialValue: values.3)
        _e = State(initialValue: values.4)
        self.content = content
    }
    var body: some View { content($a, $b, $c, $d, $e) }
}
