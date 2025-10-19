import SwiftUI

struct RecommendedDoseSectionView: View {
    let weightValue: Double?
    let sugarLevelValue: Double?
    let recommendedDose: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if weightValue == nil {
                Text("წონა არ არის დაყენებული პარამეტრებში")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            } else if sugarLevelValue == nil || (sugarLevelValue ?? 0) <= 0 {
                Text("შეიყვანეთ მნიშვნელობები")
                    .foregroundColor(.secondary)
            } else if let dose = recommendedDose {
                Text("რეკომენდირებული დოზა: \(formatNumber(dose)) ერთეული")
                    .font(.headline)
                    .fontWeight(.semibold)
            } else {
                Text("შეიყვანეთ მნიშვნელობები")
                    .foregroundColor(.secondary)
            }
        }
    }
}
