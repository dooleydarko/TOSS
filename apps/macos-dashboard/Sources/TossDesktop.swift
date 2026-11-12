import SwiftUI
import AppKit
import Combine

@main
struct TossDesktop: App {
    @AppStorage("toss.appearance") private var appearance = "Dark"
    var body: some Scene {
        WindowGroup {
            DesktopInbox().frame(minWidth: 700, minHeight: 460)
                .preferredColorScheme(appearance == "System" ? nil : (appearance == "Light" ? .light : .dark))
        }
    }
}

private struct InboxEntry: Identifiable {
    let url: URL
    let handoff: TossHandoff
    var id: URL { url }
}
private struct DesktopInbox: View {
    @AppStorage("toss.desktop.inbox") private var folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/TOSS/received").path
    @State private var entries: [InboxEntry] = []
    @State private var selected: URL?
    @State private var query = ""
    @State private var status = ""
    @AppStorage("toss.appearance") private var appearance = "Dark"
    @Environment(\.colorScheme) private var scheme
    private var canvas: Color { scheme == .dark ? Color(red: 0.047, green: 0.055, blue: 0.063) : Color(nsColor: .controlBackgroundColor) }
    private var surface: Color { scheme == .dark ? Color(red: 0.094, green: 0.106, blue: 0.118) : Color(nsColor: .windowBackgroundColor) }
    private var accent: Color { scheme == .dark ? Color(red: 0.737, green: 0.91, blue: 0.855) : Color(red: 0.09, green: 0.36, blue: 0.29) }
    private var filtered: [InboxEntry] {
        entries.filter { query.isEmpty || "\($0.handoff.title) \($0.handoff.objective)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TOSS").font(.caption.bold()).tracking(3).foregroundColor(accent)
                    Spacer()
                    Picker("Theme", selection: $appearance) {
                        Text("Dark").tag("Dark")
                        Text("Light").tag("Light")
                        Text("System").tag("System")
                    }.labelsHidden().frame(width: 110)
                }
                Text("Your handoffs").font(.largeTitle.bold())
                Button("Choose receiver folder", action: choose)
                TextField("Search handoffs", text: $query)
                List(selection: $selected) {
                    ForEach(filtered) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.handoff.title).font(.headline)
                            Text("Revision \(entry.handoff.revision)").font(.caption).foregroundColor(.secondary)
                        }.tag(entry.id)
                    }
                }
                Button("Refresh", action: refresh)
                Text(status).font(.caption).foregroundColor(.secondary)
            }.padding(16).frame(width: 300)
                .background(surface).clipShape(RoundedRectangle(cornerRadius: 24))
            VStack(alignment: .leading, spacing: 12) {
                if let entry = entries.first(where: { $0.id == selected }) {
                    Text(entry.handoff.title).font(.largeTitle.bold())
                    ScrollView { Text(entry.handoff.toMarkdown()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    HStack {
                        Button("Copy Markdown") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.handoff.toMarkdown(), forType: .string) }
                        Button("Open files") { NSWorkspace.shared.open(entry.url.deletingLastPathComponent()) }
                    }
                } else {
                    Text("Choose a received handoff").font(.title2.bold())
                    Text("This inbox reads the existing receiver's storage folder. Start the receiver separately using the documented command.").foregroundColor(.secondary)
                }
                Spacer()
            }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(surface).clipShape(RoundedRectangle(cornerRadius: 24))
        }.padding(20).background(canvas.ignoresSafeArea())
        .tint(accent)
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in refresh() }
    }
    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { folder = url.path; refresh() }
    }
    private func refresh() {
        guard !folder.isEmpty else { status = "Select the receiver storage folder."; return }
        let root = URL(fileURLWithPath: folder, isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else {
            status = "Folder unavailable."; return
        }
        var found: [InboxEntry] = []
        var scanned = 0
        for case let url as URL in walker {
            scanned += 1
            if scanned > 10000 { break }
            guard url.lastPathComponent == "handoff.json",
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 10_000_000,
                  let data = try? Data(contentsOf: url), let handoff = try? TossHandoff.fromJSONData(data) else { continue }
            found.append(InboxEntry(url: url, handoff: handoff))
        }
        entries = found.sorted { $0.handoff.updatedAt > $1.handoff.updatedAt }
        status = "\(entries.count) received handoffs" + (scanned > 10000 ? " (scan limit reached)" : "")
    }
}
