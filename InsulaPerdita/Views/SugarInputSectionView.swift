import SwiftUI

struct SugarInputSectionView: View {
    @Binding var sugarLevel: String
    let sugarLevelValue: Double?
    let sugarLevelColor: Color
    let acceptAction: (Double) -> Void
    @FocusState var sugarFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("შაქრის დონე")
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        TextField("მმოლ/ლ", text: $sugarLevel)
                            .keyboardType(.decimalPad)
                            .focused($sugarFieldFocused)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                            .frame(width: geo.size.width * 0.9, alignment: .leading)
                            .foregroundColor(sugarLevelColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(sugarLevel.isEmpty ? Color.secondary.opacity(0.3) : sugarLevelColor, lineWidth: 1)
                            )
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(height: 52)
                    if let val = sugarLevelValue, val > 0 {
                        Button { acceptAction(val) } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                                .accessibilityLabel("შენახვა")
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
}
