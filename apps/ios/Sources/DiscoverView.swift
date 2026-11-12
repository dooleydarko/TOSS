import SwiftUI

@MainActor
struct DiscoverView: View {
    @EnvironmentObject var store: TossStore
    @State private var query = ""
    private var entries: [TossStarter] {
        TossStarter.library.filter { query.isEmpty || "\($0.title) \($0.category) \($0.notes)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Start with an idea").font(.largeTitle.bold())
                    Text("Original TOSS starters, with links to related open-source planning resources.").foregroundColor(.secondary)
                    ForEach(entries) { starter in
                        NavigationLink(destination: StarterDetail(starter: starter)) {
                            TossCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(starter.category.uppercased()).font(.caption.bold()).tracking(2)
                                    Text(starter.title).font(.title2.bold())
                                    Text(starter.notes).font(.subheadline).foregroundColor(.secondary).lineLimit(3)
                                }.foregroundColor(TossDesign.ink)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }.background(TossDesign.canvas).searchable(text: $query).navigationTitle("Discover")
        }
    }
}
@MainActor
private struct StarterDetail: View {
    @EnvironmentObject var store: TossStore
    let starter: TossStarter
    @State private var notes: String
    @State private var review = false
    @State private var error = ""
    init(starter: TossStarter) { self.starter = starter; _notes = State(initialValue: starter.notes) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(starter.title).font(.largeTitle.bold())
                TextEditor(text: $notes).frame(minHeight: 220)
                if let url = URL(string: starter.reference) { Link("Related planning repository", destination: url) }
                Button("Use this starter") {
                    do {
                        guard !store.isTransferInProgress else { return }
                        let handoff = try starter.handoff(customNotes: notes, destination: store.preferredDestination)
                        store.currentHandoff = handoff
                        store.saveHandoff(handoff)
                        review = true
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(TossPrimaryButton()).disabled(store.isTransferInProgress)
                if !error.isEmpty { Text(error).foregroundColor(.red) }
                NavigationLink(destination: ReviewView(), isActive: $review) { EmptyView() }
            }.padding(20)
        }.background(TossDesign.canvas)
    }
}
