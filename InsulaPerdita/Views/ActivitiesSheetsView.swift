import SwiftUI

// Extracted activity-related sheet views from ContentView for modularity.

struct ActivitySheetView: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var effect: Int?
    @Binding var editingIndex: Int?
    let effectOptions: [Int]
    let canSave: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("დასახელება")) {
                    TextField("დასახელება", text: $title)
                }
                Section(header: Text("საშალო გავლენა")) {
                    ActivityEffectChips(selected: $effect, effectOptions: effectOptions)
                }
            }
            .navigationTitle(editingIndex == nil ? "ახალი აქტივობა" : "რედაქტირება")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("დახურვა") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingIndex == nil ? "შენახვა" : "განახლება") { onSave() }
                        .disabled(!canSave)
                }
            }
        }
    }
}

struct RegisteredActivitiesSheetView: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var effect: Int?
    @Binding var editingIndex: Int?
    @Binding var registeredActivities: [RegisteredActivity]
    let effectOptions: [Int]
    let canSave: Bool
    let onSave: () -> Void
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("დასახელება")) { TextField("დასახელება", text: $title) }
                Section(header: Text("საშალო გავლენა")) { ActivityEffectChips(selected: $effect, effectOptions: effectOptions) }
                Section(header: Text("შენახული აქტივობები")) {
                    if registeredActivities.isEmpty {
                        Text("აქტივობები ჯერ არ არის").foregroundColor(.secondary)
                    } else {
                        ForEach(registeredActivities.indices, id: \.self) { idx in
                            let act = registeredActivities[idx]
                            HStack {
                                Text(act.title)
                                Spacer()
                                Text((act.averageEffect > 0 ? "+" : "") + String(act.averageEffect))
                                    .foregroundColor(effectColor(act.averageEffect))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                title = act.title
                                effect = act.averageEffect
                                editingIndex = idx
                            }
                        }
                        .onDelete { indices in onDelete(indices) }
                    }
                }
            }
            .navigationTitle(editingIndex == nil ? "ახალი აქტივობა" : "რედაქტირება")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingIndex == nil ? "შენახვა" : "განახლება") { onSave() }.disabled(!canSave)
                }
            }
        }
    }
}

struct RegisteredActivityPickerSheetView: View {
    @Binding var isPresented: Bool
    let registeredActivities: [RegisteredActivity]
    @Binding var selectedRegisteredActivityId: UUID?
    let onPick: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                if registeredActivities.isEmpty {
                    Text("ჯერ არ არის რეგისტრირებული აქტივობები").foregroundColor(.secondary)
                } else {
                    ForEach(registeredActivities) { act in
                        Button {
                            selectedRegisteredActivityId = act.id
                            onPick()
                        } label: {
                            HStack {
                                Text(act.title)
                                Spacer()
                                Text((act.averageEffect > 0 ? "+" : "") + String(act.averageEffect))
                                    .foregroundColor(effectColor(act.averageEffect))
                            }
                        }
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { isPresented = false } } }
        }
    }
}

// Reusable chips subview
private struct ActivityEffectChips: View {
    @Binding var selected: Int?
    let effectOptions: [Int]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(effectOptions, id: \.self) { value in
                    let isSel = value == selected
                    Text((value > 0 ? "+" : "") + String(value))
                        .font(.subheadline.monospacedDigit())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isSel ? effectColor(value) : Color(.systemGray5))
                        .foregroundColor(isSel ? .white : effectColor(value))
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) { selected = value }
                        }
                }
            }.padding(.vertical, 4)
        }
    }
}
