import SwiftUI
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

// MARK: - Capture View
public struct CaptureView: View {
    @EnvironmentObject var store: TossStore
    @State private var inputText: String = ""
    @State private var contextText: String = ""
    @State private var isProcessing: Bool = false
    @State private var navigateToReview: Bool = false
    @State private var isRecording: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Capture Idea or Instruction")) {
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Type your instructions or describe your feature here...")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $inputText)
                            .frame(minHeight: 120)
                    }

                    HStack {
                        Button(action: toggleRecording) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .foregroundColor(isRecording ? .red : .blue)
                                Text(isRecording ? "Stop Recording" : "Voice Dictate")
                            }
                        }
                        Spacer()
                        if !inputText.isEmpty {
                            Button("Clear") { inputText = "" }
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Optional Context / Project")) {
                    TextField("E.g. Target module, repository, or issue #", text: $contextText)
                }

                Section {
                    Button(action: processAndStructure) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Structuring with AI...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("Create Structured Handoff")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }

                NavigationLink(
                    destination: ReviewView(),
                    isActive: $navigateToReview,
                    label: { EmptyView() }
                )
            }
            .navigationTitle("TOSS Capture")
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            // Simulated voice input for MVP demo
            inputText = "I want an iPhone app called TOSS. Users can record an idea, have AI structure a clean handoff, then swipe it over to their Mac so Antigravity can build it."
        }
    }

    private func processAndStructure() {
        isProcessing = true
        Task {
            do {
                _ = try await store.createHandoffFromText(rawText: inputText, context: contextText)
                isProcessing = false
                navigateToReview = true
            } catch {
                isProcessing = false
            }
        }
    }
}

// MARK: - Review View
public struct ReviewView: View {
    @EnvironmentObject var store: TossStore
    @State private var selectedSegment = 0
    @State private var navigateToToss = false

    public init() {}

    public var body: some View {
        VStack {
            if let handoff = store.currentHandoff {
                Picker("View Mode", selection: $selectedSegment) {
                    Text("Overview").tag(0)
                    Text("Markdown").tag(1)
                    Text("JSON Schema").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedSegment == 0 {
                            overviewCard(handoff)
                        } else if selectedSegment == 1 {
                            markdownPreview(handoff)
                        } else {
                            jsonPreview(handoff)
                        }
                    }
                    .padding()
                }

                Divider()

                NavigationLink(
                    destination: TossView(),
                    isActive: $navigateToToss,
                    label: {
                        Button(action: { navigateToToss = true }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Proceed to Toss / Send")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                )
                .padding(.bottom, 8)
            } else {
                Text("No active handoff created.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Review Handoff")
    }

    private func overviewCard(_ handoff: TossHandoff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(handoff.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Label("Rev \(handoff.revision)", systemImage: "clock.arrow.circlepath")
                Spacer()
                Label(handoff.destination.rawValue.capitalized, systemImage: "cpu")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()

            Text("Objective").font(.headline)
            Text(handoff.objective)

            Text("Requirements").font(.headline)
            ForEach(handoff.requirements, id: \.self) { req in
                Text("• \(req)")
            }

            Text("Next Actions").font(.headline)
            ForEach(Array(handoff.nextActions.enumerated()), id: \.offset) { index, action in
                Text("\(index + 1). \(action)")
            }
        }
    }

    private func markdownPreview(_ handoff: TossHandoff) -> some View {
        Text(handoff.toMarkdown())
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }

    private func jsonPreview(_ handoff: TossHandoff) -> some View {
        let jsonStr = (try? String(data: handoff.toJSONData(), encoding: .utf8)) ?? "{}"
        return Text(jsonStr)
            .font(.system(.footnote, design: .monospaced))
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Toss View (Swipe & Send)
public struct TossView: View {
    @EnvironmentObject var store: TossStore
    @State private var dragOffset: CGSize = .zero
    @State private var isSending: Bool = false
    @State private var statusMessage: String = "Ready to Toss"

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            if let targetDevice = store.pairedDevices.first {
                HStack {
                    Image(systemName: "laptopcomputer")
                        .font(.title)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(targetDevice.name)
                            .font(.headline)
                        Text("\(targetDevice.host):\(targetDevice.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Swipeable Card
                if let handoff = store.currentHandoff {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text(handoff.title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Swipe up or press Send to Toss")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 280, height: 200)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 8)
                    .offset(y: dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if gesture.translation.height < 0 {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                if gesture.translation.height < -120 {
                                    triggerSend(device: targetDevice)
                                } else {
                                    withAnimation { dragOffset = .zero }
                                }
                            }
                    )
                }

                Spacer()

                // Status Indicator
                VStack(spacing: 8) {
                    if let state = store.activeTransferState {
                        Text(state.description)
                            .font(.subheadline)
                            .foregroundColor(state == .received ? .green : .blue)
                    }
                    if let receipt = store.lastReceipt {
                        Label("Receipt: \(receipt.receiptId.prefix(8))", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // Explicit Accessible Button
                Button(action: { triggerSend(device: targetDevice) }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Handoff to Mac")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .disabled(isSending)
                .padding(.bottom, 16)

            } else {
                Text("No paired Mac receiver found.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Toss to Mac")
    }

    private func triggerSend(device: TossDevice) {
        isSending = true
        Task {
            do {
                _ = try await store.tossCurrentHandoff(to: device)
                withAnimation { dragOffset = CGSize(width: 0, height: -600) }
                isSending = false
            } catch {
                isSending = false
                withAnimation { dragOffset = .zero }
            }
        }
    }
}

// MARK: - History View
public struct HistoryView: View {
    @EnvironmentObject var store: TossStore
    @State private var searchText = ""

    public init() {}

    var filteredHandoffs: [TossHandoff] {
        if searchText.isEmpty {
            return store.handoffs
        }
        return store.handoffs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.objective.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationView {
            List(filteredHandoffs) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        Text("Rev \(item.revision)")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    Text(item.objective)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    HStack {
                        Text(item.createdAt.prefix(10))
                        Spacer()
                        Text(item.destination.rawValue)
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Handoff History")
        }
    }
}

// MARK: - Settings View
public struct SettingsView: View {
    @EnvironmentObject var store: TossStore

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Structuring Provider")) {
                    Picker("Destination Target", selection: $store.preferredDestination) {
                        ForEach(TossDestination.allCases, id: \.self) { dest in
                            Text(dest.rawValue.capitalized).tag(dest)
                        }
                    }

                    SecureField("Gemini API Key (Optional)", text: $store.geminiApiKey)
                    TextField("Model", text: $store.selectedModel)

                    Text("Without an API key, TOSS operates 100% offline using the built-in local rule-based structurer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Privacy & Security")) {
                    Text("No voice recordings or project instructions are uploaded to cloud servers unless an AI key is explicitly configured and user initiates structuring.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Main Tab Container
public struct TossAppView: View {
    @StateObject var store = TossStore()

    public init() {}

    public var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "plus.circle.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(store)
    }
}
