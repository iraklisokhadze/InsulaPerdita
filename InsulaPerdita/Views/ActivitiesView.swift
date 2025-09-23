import SwiftUI

struct ActivitiesView: View {
    // Use shared RegisteredActivity model instead of local Activity
    @State private var activities: [RegisteredActivity] = []
    
    // Sheet / form state
    @State private var showAddSheet = false
    @State private var newTitle: String = ""
    @State private var selectedEffect: Int? = nil
    @State private var editingIndex: Int? = nil
    @State private var didLoad = false
    
    private let effectOptions: [Int] = activityEffectOptions
    // Use global storage key so ActivitiesView feeds pre-registered list used elsewhere
    private let storageKey = registeredActivitiesStorageKey
    
    var body: some View {
        List {
            if activities.isEmpty {
                Text("აქტივობები ჯერ არ არის").foregroundColor(.secondary)
            } else {
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
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
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(index: index) }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteActivities)
            }
        }
        .navigationTitle("აქტივობები")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddSheet, onDismiss: resetForm) { addSheet }
        .onAppear { if !didLoad { loadActivities(); didLoad = true } }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { beginAdd() }) { Image(systemName: "plus") }
                .accessibilityLabel("ახალი აქტივობა")
        }
    }
    
    private var addSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("დაფიქსირება")) {
                    TextField("დასახელება", text: $newTitle)
                }
                Section(header: Text("საშალო გავლენა")) { effectPicker }
            }
            .navigationTitle(editingIndex == nil ? "ახალი აქტივობა" : "რედაქტირება")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("გაუქმება") { showAddSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingIndex == nil ? "შენახვა" : "განახლება", action: saveActivity)
                        .disabled(!canSave)
                }
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
    
    // MARK: - Actions
    private func beginAdd() { resetForm(); showAddSheet = true }
    private func beginEdit(index: Int) {
        guard activities.indices.contains(index) else { return }
        let a = activities[index]
        newTitle = a.title
        selectedEffect = a.averageEffect
        editingIndex = index
        showAddSheet = true
    }
    private func saveActivity() {
        guard canSave, let effect = selectedEffect else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = editingIndex, activities.indices.contains(idx) {
            activities[idx].title = trimmed
            activities[idx].averageEffect = effect
        } else {
            activities.append(RegisteredActivity(id: UUID(), title: trimmed, averageEffect: effect))
        }
        persistActivities()
        showAddSheet = false
    }
    private func deleteActivities(at offsets: IndexSet) { activities.remove(atOffsets: offsets); persistActivities() }
    private func resetForm() { newTitle = ""; selectedEffect = nil; editingIndex = nil }
    
    // MARK: - Persistence
    private func persistActivities() {
        do {
            let data = try JSONEncoder().encode(activities)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch { /* silent */ }
    }
    private func loadActivities() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([RegisteredActivity].self, from: data) { activities = decoded }
    }
    
    // MARK: - Helpers
    private func formatEffect(_ value: Int) -> String { (value > 0 ? "+" : "") + String(value) }
    private func effectColor(_ value: Int) -> Color { value == 0 ? .gray : (value > 0 ? .green : .red) }
}

#Preview { NavigationStack { ActivitiesView() } }
