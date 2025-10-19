import SwiftUI

enum SuccessKind: Equatable {
    case injection(dose: Double, period: InjectionPeriod)
    case activity(title: String, effect: Int)
    case glucose(value: Double)
}

struct SuccessBannerView: View {
    let kind: SuccessKind
    let sugarLevelColor: Color
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(subtitle).font(.caption2).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            Button { withAnimation { dismiss() } } label: {
                Image(systemName: "xmark").font(.caption2).padding(6)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .shadow(radius: 4, y: 2)
    }

    private var icon: String {
        switch kind {
        case .injection: return "syringe"
        case .activity(_, let effect): return effect > 0 ? "arrow.up.circle.fill" : (effect < 0 ? "arrow.down.circle.fill" : "circle.fill")
        case .glucose: return "drop"
        }
    }
    private var tint: Color {
        switch kind {
        case .injection(_, let period): return period == .daytime ? .orange : .indigo
        case .activity(_, let effect): return effectColor(effect)
        case .glucose: return sugarLevelColor
        }
    }
    private var title: String {
        switch kind {
        case .injection(let dose, _): return "ინექცია შენახულია: " + formatNumber(dose) + " ერთ"
        case .activity(let title, _): return "აქტივობა დამატებულია: " + title
        case .glucose(let value): return "შენახულია: " + formatNumber(value) + " მმოლ/ლ"
        }
    }
    private var subtitle: String {
        switch kind {
        case .injection(_, let period): return period.display
        case .activity(_, let effect): return (effect > 0 ? "+" : "") + String(effect)
        case .glucose: return formatDate(Date())
        }
    }
}
