import SwiftUI

struct NFCSectionView: View {
    @ObservedObject var nfcManager: NFCManager
    let formatNumber: (Double) -> String

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
    }
}

#Preview {
    NFCSectionView(nfcManager: NFCManager(), formatNumber: { String(format: "%.1f", $0) })
        .padding()
}
