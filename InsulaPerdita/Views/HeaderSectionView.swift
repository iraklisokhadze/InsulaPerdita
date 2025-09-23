import SwiftUI

struct HeaderSectionView: View {
    let targetDisplayText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(targetDisplayText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HeaderSectionView(targetDisplayText: "სამიზნე: 110 მმოლ/ლ")
        .padding()
}
