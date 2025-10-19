import SwiftUI

struct NFCSectionView: View {
    @ObservedObject var nfcManager: NFCManager
    let formatNumber: (Double) -> String
    let onNewReading: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NFC სენსორი").font(.headline)
            HStack {
                Button {
                    nfcManager.startScan()
                } label: {
                    HStack {
                        Image(systemName: nfcManager.isScanning ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                        Text(nfcManager.isScanning ? "სკანირება..." : "სკანირება")
                    }
                }
                .disabled(nfcManager.isScanning)
            }
            if let r = nfcManager.lastReading {
                Text("ბოლო სენსორი: \(formatNumber(r.glucose ?? 0)) მმოლ/ლ")
                    .font(.subheadline)
            }
            if let e = nfcManager.errorMessage {
                Text(e).font(.caption).foregroundColor(.red)
            }
        }
        .onChange(of: nfcManager.lastReading) { _, newValue in
            if let g = newValue?.glucose { onNewReading(g) }
        }
    }
}

#Preview {
    NFCSectionView(nfcManager: NFCManager(), formatNumber: { String(format: "%.1f", $0) }, onNewReading: { _ in })
        .padding()
}
