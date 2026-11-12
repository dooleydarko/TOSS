import SwiftUI
import AVFoundation
import Combine
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

// MARK: - Capture View
@MainActor
public struct CaptureView: View {
    @EnvironmentObject var store: TossStore
    @State private var inputText: String = ""
    @State private var contextText: String = ""
    @State private var isProcessing: Bool = false
    @State private var navigateToReview: Bool = false
    @StateObject private var voice = VoiceCapture()
    @State private var dictationBase = ""
    @State private var hasVoiceInput = false
    @State private var processingError: String?
    @Environment(\.scenePhase) private var scenePhase

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
                            .disabled(voice.isBusy || isProcessing)
                    }

                    HStack {
                        Button(action: toggleRecording) {
                            HStack {
                                Image(systemName: voice.state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                                    .foregroundColor(voice.state == .recording ? .red : .blue)
                                Text(voice.state == .recording ? "Stop Recording" : "Voice Dictate")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isProcessing || voice.state == .authorizing || voice.state == .finishing)
                        Spacer()
                        if !inputText.isEmpty {
                            Button("Clear") { inputText = ""; hasVoiceInput = false }
                                .buttonStyle(.borderless)
                                .foregroundColor(.secondary)
                                .disabled(voice.isBusy || isProcessing)
                        }
                    }
                    if voice.state == .recording {
                        MicrophoneWaveform(levels: voice.levels)
                        Label("Recording • speak now", systemImage: "waveform")
                            .font(.caption).foregroundColor(.red)
                    } else if voice.state == .authorizing || voice.state == .finishing {
                        HStack {
                            ProgressView()
                            Text(voice.state == .authorizing ? "Requesting access…" : "Finishing transcript…")
                        }.font(.caption)
                    }
                    if let message = voice.errorMessage {
                        Text(message).font(.caption).foregroundColor(.secondary)
                    }
                    Text("Dictation uses on-device speech recognition when available; otherwise Apple may process audio on its servers.")
                        .font(.caption).foregroundColor(.secondary)
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
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || voice.isBusy)
                    if let error = processingError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }

                NavigationLink(
                    destination: ReviewView(),
                    isActive: $navigateToReview,
                    label: { EmptyView() }
                )
            }
            .navigationTitle("TOSS Capture")
        }
        .onChange(of: voice.transcript) { text in
            guard !text.isEmpty else { return }
            inputText = dictationBase.isEmpty ? text : dictationBase + "\n" + text
            hasVoiceInput = true
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { voice.cancel() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               AVAudioSession.InterruptionType(rawValue: value) == .began {
                voice.interrupted()
            }
        }
        .onDisappear { voice.cancel() }
    }

    private func toggleRecording() {
        if voice.state == .recording {
            voice.stop()
        } else if voice.state == .idle {
            dictationBase = inputText
            Task { await voice.start() }
        }
    }

    private func processAndStructure() {
        isProcessing = true
        processingError = nil
        Task {
            do {
                _ = try await store.createHandoffFromText(rawText: inputText, context: contextText, sourceType: hasVoiceInput ? .voice : .text)
                isProcessing = false
                navigateToReview = true
            } catch {
                isProcessing = false
                processingError = error.localizedDescription
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

// MARK: - Toss View (Swipe & Send with Spring Physics)
public struct TossView: View {
    @EnvironmentObject var store: TossStore
    @State private var dragOffset: CGSize = .zero
    @State private var isSending: Bool = false
    @State private var statusMessage: String = "Ready to Toss"
    @State private var tossSuccessful: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Target Receiver Banner
            if let targetDevice = store.pairedDevices.first {
                HStack {
                    Image(systemName: "laptopcomputer")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(targetDevice.name)
                            .font(.headline)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("\(targetDevice.host):\(targetDevice.port) • Local Wi-Fi")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if store.isDiscoveryActive {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(14)
                .padding(.horizontal)

                Spacer()

                // Swipeable Card with Spring Physics & Rotation
                if let handoff = store.currentHandoff {
                    VStack(spacing: 14) {
                        Image(systemName: tossSuccessful ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(tossSuccessful ? .green : .blue)
                            .scaleEffect(tossSuccessful ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: tossSuccessful)

                        Text(handoff.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Swipe up to toss to your Mac")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Text("Rev \(handoff.revision)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(6)
                            Text(handoff.destination.rawValue.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                    .frame(width: 300, height: 230)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(min(0.25, 0.08 + abs(dragOffset.height) / 600)), radius: 14, x: 0, y: 8)
                    .offset(x: dragOffset.width * 0.4, y: dragOffset.height)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 14.0))
                    .scaleEffect(max(0.86, 1.0 - abs(dragOffset.height) / 900.0))
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.72), value: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if gesture.translation.height < 0 {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                if gesture.translation.height < -120 {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        dragOffset = CGSize(width: gesture.translation.width, height: -650)
                                    }
                                    triggerSend(device: targetDevice)
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                }

                Spacer()

                // Status & Receipt Indicator
                VStack(spacing: 6) {
                    if let state = store.activeTransferState {
                        Text(state.description)
                            .font(.subheadline)
                            .fontWeight(.medium)
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
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .disabled(isSending)
                .padding(.bottom, 16)

            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching for local Mac receivers via Bonjour...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .navigationTitle("Toss to Mac")
        .onAppear {
            store.startDiscovery()
        }
    }

    private func triggerSend(device: TossDevice) {
        isSending = true
        Task {
            do {
                _ = try await store.tossCurrentHandoff(to: device)
                tossSuccessful = true
                isSending = false
            } catch {
                isSending = false
                withAnimation(.spring()) {
                    dragOffset = .zero
                }
            }
        }
    }
}

// MARK: - Queue & Sync View
public struct QueueView: View {
    @EnvironmentObject var store: TossStore

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                if store.queue.items.isEmpty {
                    Text("No queued transfers. All handoffs delivered!")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.queue.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.handoff.title)
                                .font(.headline)
                            HStack {
                                Text("Target: \(item.targetDevice.name)")
                                Spacer()
                                statusBadge(for: item.status)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Offline Queue")
            .toolbar {
                Button("Retry All") {
                    store.queue.retryFailedItems()
                }
            }
        }
    }

    private func statusBadge(for status: QueueStatus) -> some View {
        switch status {
        case .pending:
            return Text("Pending").foregroundColor(.orange)
        case .retrying(let n):
            return Text("Retry #\(n)").foregroundColor(.blue)
        case .completed:
            return Text("Delivered").foregroundColor(.green)
        case .failed:
            return Text("Failed").foregroundColor(.red)
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

                    Text("Without an API key, handoff structuring uses the built-in offline rule-based formatter.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Privacy & Security")) {
                    Text("Dictation prefers on-device speech recognition; Apple may process audio when local recognition is unavailable. TOSS does not save audio files. Project notes are sent to Gemini only when you configure an AI key and initiate structuring.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Main Tab Container
@MainActor
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
            QueueView()
                .tabItem {
                    Label("Queue", systemImage: "arrow.triangle.2.circlepath")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(store)
    }
}
