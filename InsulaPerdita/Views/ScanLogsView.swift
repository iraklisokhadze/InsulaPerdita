import SwiftUI

struct ScanLogsView: View {
    @State private var logs: [URL] = []
    @State private var selectedLog: URL? = nil
    @State private var logText: String? = nil
    @State private var showShare: Bool = false
    @State private var isPurging = false
    @State private var sheetItem: SheetItem? = nil

    var body: some View {
        List(selection: $selectedLog) {
            Section(header: Text("შენახული NFC სკანები")) {
                if logs.isEmpty {
                    Text("ჯერჯერობით არ არის შენახული სკანები")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(logs, id: \.self) { url in
                        Button(action: { load(url) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent.replacingOccurrences(of: "scan_", with: ""))
                                        .font(.caption.monospaced())
                                    if let size = fileSize(url) { Text(size).font(.caption2).foregroundColor(.secondary) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) { delete(url) } label: { Label("წაშლა", systemImage: "trash") }
                            Button { share(url) } label: { Label("გაზიარება", systemImage: "square.and.arrow.up") }
                        }
                    }
                }
            }
        }
        .task { refresh() }
        .navigationTitle("NFC ლოგები")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showShare) {
            if let selected = selectedLog { ShareSheet(activityItems: [selected]) }
        }
        .sheet(item: $sheetItem) { item in
            NavigationStack {
                ScrollView { Text(item.text).font(.caption.monospaced()).padding() }
                    .navigationTitle(item.title)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("დახურვა") { sheetItem = nil; logText = nil } } }
            }
        }
    }

    private struct SheetItem: Identifiable { let id: URL; let title: String; let text: String }

    private func refresh() { logs = ScanLogStore.listScanLogs() }
    private func load(_ url: URL) {
        selectedLog = url
        logText = ScanLogStore.loadLog(url: url)
        sheetItem = SheetItem(id: url, title: url.lastPathComponent, text: logText ?? "დატვირთვა ვერ მოხერხდა")
    }
    private func delete(_ url: URL) { ScanLogStore.deleteLog(url: url); refresh() }
    private func share(_ url: URL) { selectedLog = url; showShare = true }

    private func fileSize(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path()), let bytes = attrs[.size] as? Int else { return nil }
        if bytes < 1024 { return "\(bytes)b" }
        if bytes < 1024*1024 { return String(format: "%.1fKB", Double(bytes)/1024.0) }
        return String(format: "%.1fMB", Double(bytes)/(1024.0*1024.0))
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("განახლება", action: refresh)
                Button(role: .destructive) {
                    isPurging = true
                    ScanLogStore.purgeAll(); refresh(); isPurging = false
                } label: { Label("ყველას წაშლა", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if !logs.isEmpty, let url = selectedLog { Button(action: { share(url) }) { Image(systemName: "square.and.arrow.up") } }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if let txt = logText { Button("გაზიარება ტექსტი") { UIPasteboard.general.string = txt } }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ScanLogsView_Previews: PreviewProvider { static var previews: some View { NavigationStack { ScanLogsView() } } }
