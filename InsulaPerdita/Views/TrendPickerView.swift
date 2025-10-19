import SwiftUI

struct TrendPickerView: View {
    @Binding var selectedTrend: Trend
    let dismissKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ტრენდი")
            HStack(spacing: 12) {
                ForEach(Trend.allCases) { trend in
                    Button { selectedTrend = trend; dismissKeyboard() } label: {
                        Image(systemName: trend.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(selectedTrend == trend ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTrend == trend ? Color.accentColor : Color.clear, lineWidth: 2))
                            .foregroundColor(selectedTrend == trend ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
