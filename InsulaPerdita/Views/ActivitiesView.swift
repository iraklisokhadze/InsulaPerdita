import SwiftUI

struct ActivitiesView: View {
    // Presentation binding (used when shown as sheet). If used in navigation push, pass .constant(true) and set showsCloseButton=false.
    @Binding var isPresented: Bool
    let saveAction: (RegisteredActivity) -> Void
    var showsCloseButton: Bool = true
    @Environment(\.dismiss) private var dismissEnv
    @State private var activities: [RegisteredActivity] = []
    @EnvironmentObject var activityHistory: ActivityHistoryStore
    @State private var showAddSheet = false
    @State private var newTitle: String = ""
    @State private var selectedEffect: Int? = nil
    @State private var didLoad = false
    private let effectOptions: [Int] = activityEffectOptions
    private let storageKey = registeredActivitiesStorageKey

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    if activities.isEmpty {
                        Text("აქტივობები ჯერ არ არის").foregroundColor(.secondary)
                    } else {
                        ForEach(activities) { activity in
                            HStack(alignment: .firstTextBaseline) {
                                Text(activity.title).font(.headline)
                                Spacer()
                                Text(formatEffect(activity.averageEffect))
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(effectColor(activity.averageEffect).opacity(0.15))
                                    .foregroundColor(effectColor(activity.averageEffect))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { addActivityAndClose(activity) }
                        }
                    }
                }
                .listStyle(.plain)
                Button(action: { showAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill").font(.title2)
                        Text("ახალი აქტივობა").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                    .padding([.horizontal, .bottom])
                }
                .accessibilityLabel("ახალი აქტივობა")
            }
            .navigationTitle("აქტივობები")
            .toolbar { if showsCloseButton { ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { isPresented = false } } } }
            .sheet(isPresented: $showAddSheet, onDismiss: resetForm) { addSheet }
            .onAppear { if !didLoad { loadActivities(); didLoad = true } }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("დაფიქსირება")) { TextField("დასახელება", text: $newTitle) }
                Section(header: Text("საშალო გავლენა")) { effectPicker }
            }
            .navigationTitle("ახალი აქტივობა")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("გაუქმება") { showAddSheet = false } }
                ToolbarItem(placement: .confirmationAction) { Button("შენახვა", action: saveNewActivity).disabled(!canSave) }
            }
        }
    }

    private var effectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(effectOptions, id: \.self) { value in
                    let isSelected = value == selectedEffect
                    Text(formatEffect(value))
                        .font(.subheadline.monospacedDigit())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isSelected ? effectColor(value) : Color(.systemGray5))
                        .foregroundColor(isSelected ? .white : effectColor(value))
                        .clipShape(Capsule())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedEffect = value } }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var canSave: Bool { !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedEffect != nil }

    private func saveNewActivity() {
        guard canSave, let effect = selectedEffect else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newActivity = RegisteredActivity(id: UUID(), title: trimmed, averageEffect: effect)
        activities.append(newActivity)
        persistActivities()
        showAddSheet = false
    }

    private func resetForm() { newTitle = ""; selectedEffect = nil }

    private func addActivityAndClose(_ activity: RegisteredActivity) {
        saveAction(activity)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        if showsCloseButton { isPresented = false } else { dismissEnv() }
    }

    private func persistActivities() {
        if let data = try? JSONEncoder().encode(activities) { UserDefaults.standard.set(data, forKey: storageKey) }
    }
    private func loadActivities() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([RegisteredActivity].self, from: data) { activities = decoded }
    }
    private func formatEffect(_ value: Int) -> String { (value > 0 ? "+" : "") + String(value) }
    private func effectColor(_ value: Int) -> Color { value == 0 ? .gray : (value > 0 ? .green : .red) }
}

#Preview { ActivitiesView(isPresented: .constant(true), saveAction: { _ in }) }
