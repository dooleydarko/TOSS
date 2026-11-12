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
    @State private var showHistory = false

    private var recordingStatus: String {
        if isProcessing { return "Creating your handoff…" }
        switch voice.state {
        case .idle: return "Tap to speak"
        case .authorizing: return "Requesting access…"
        case .recording: return "Listening • tap to stop"
        case .finishing: return "Finishing transcript…"
        }
    }
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TOSS").font(.caption.weight(.heavy)).tracking(3)
                            Text("What are we building?")
                                .font(.largeTitle.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button { showHistory = true } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(TossDesign.surface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Previous handoffs")
                        .disabled(voice.isBusy || isProcessing)
                    }
                    .foregroundColor(TossDesign.ink)
                    Button { showHistory = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your handoffs").font(.headline)
                                Text(store.handoffs.first?.title ?? "Your saved projects will appear here")
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(TossDesign.ink)
                        .background(TossDesign.surface)
                        .clipShape(RoundedRectangle(cornerRadius: TossDesign.cardRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(voice.isBusy || isProcessing)

                    TossCard {
                        VStack(spacing: 8) {
                            Text("Capture an idea").font(.title2.weight(.bold))
                            Text("Speak naturally or type your instructions.")
                                .font(.subheadline).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            TossRecordingOrb(recording: voice.state == .recording,
                                             busy: voice.isBusy, processing: isProcessing,
                                             action: toggleRecording)
                            Text(recordingStatus).font(.subheadline.weight(.semibold))
                                .foregroundColor(voice.state == .recording ? .red : .secondary)
                            if let message = voice.errorMessage {
                                Text(message).font(.caption).foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Your words").font(.headline)
                                    Spacer()
                                    if !inputText.isEmpty {
                                        Button("Clear") { inputText = ""; hasVoiceInput = false }
                                            .font(.subheadline)
                                            .disabled(voice.isBusy || isProcessing)
                                    }
                                }
                                TextEditor(text: $inputText)
                                    .frame(minHeight: 135)
                                    .disabled(voice.isBusy || isProcessing)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.18)))
                                    .accessibilityLabel("Editable transcript")
                                    .accessibilityIdentifier("capture.transcript")
                                if inputText.isEmpty {
                                    Text("Your spoken words will appear here.")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                            Text("Dictation prefers on-device recognition. Apple may process audio when local recognition is unavailable.")
                                .font(.caption).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    TossCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project context").font(.headline)
                            TextField("Repository, project or issue (optional)", text: $contextText)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isProcessing)
                            Label(store.modelLabel,
                                  systemImage: "cpu")
                                .font(.caption).foregroundColor(.secondary)
                            Text("Change AI settings in the Settings tab.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Button(action: processAndStructure) {
                        HStack {
                            if isProcessing { ProgressView().tint(.white) }
                            else { Image(systemName: "sparkles") }
                            Text(isProcessing ? "Creating handoff…" : "Create handoff")
                        }
                    }
                    .buttonStyle(TossPrimaryButton())
                    .accessibilityIdentifier("capture.create")
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || voice.isBusy)
                    if let error = processingError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    NavigationLink(destination: ReviewView(), isActive: $navigateToReview) { EmptyView() }
                        .accessibilityHidden(true)
                }
                .padding(20)
            }
            .background(TossDesign.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
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
@MainActor
public struct ReviewView: View {
    @EnvironmentObject var store: TossStore
    @State private var selectedSegment = 0
    @State private var navigateToToss = false
    @State private var editing = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            if let handoff = store.currentHandoff {
                Picker("View mode", selection: $selectedSegment) {
                    Text("Overview").tag(0)
                    Text("Markdown").tag(1)
                    Text("JSON").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedSegment == 0 {
                            TossCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(handoff.title).font(.title2.weight(.bold))
                                    Text("Revision \(handoff.revision)  •  \(handoff.destination.rawValue.capitalized)")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text(handoff.objective).font(.body)
                                }
                            }
                            detail("Context", text: handoff.context)
                            detail("Requirements", items: handoff.requirements)
                            detail("Constraints", items: handoff.constraints)
                            detail("Completed", items: handoff.completed)
                            detail("Next actions", items: handoff.nextActions)
                            detail("Known issues", items: handoff.knownIssues)
                            if let raw = handoff.source.rawInput { detail("Original notes", text: raw) }
                        } else {
                            TossCard {
                                Text(selectedSegment == 1 ? handoff.toMarkdown() : (try? String(decoding: handoff.toJSONData(), as: UTF8.self)) ?? "{}")
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
                Button { navigateToToss = true } label: {
                    Label("Ready to toss", systemImage: "arrow.up")
                }
                .buttonStyle(TossPrimaryButton())
                .accessibilityIdentifier("review.ready")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                NavigationLink(destination: TossView(), isActive: $navigateToToss) { EmptyView() }
                    .accessibilityHidden(true)
            } else {
                Text("No active handoff").foregroundColor(.secondary)
            }
        }
        .background(TossDesign.canvas.ignoresSafeArea())
        .navigationBarHidden(false)
        .navigationTitle("Review handoff")
        .toolbar {
            if store.currentHandoff != nil {
                Button("Edit") { editing = true }
                    .accessibilityIdentifier("review.edit")
                    .disabled(store.isTransferInProgress)
            }
        }
        .sheet(isPresented: $editing) {
            if let handoff = store.currentHandoff {
                HandoffEditView(original: handoff)
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder private func detail(_ title: String, text: String) -> some View {
        if !text.isEmpty {
            TossCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    Text(text).font(.body).textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder private func detail(_ title: String, items: [String]) -> some View {
        if !items.isEmpty {
            TossCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Text("• \(item)").font(.body)
                    }
                }
            }
        }
    }
}

@MainActor
private struct HandoffEditView: View {
    @EnvironmentObject var store: TossStore
    @Environment(\.dismiss) private var dismiss
    let original: TossHandoff
    @State private var draft: TossHandoff
    @State private var error: String?

    init(original: TossHandoff) {
        self.original = original
        _draft = State(initialValue: original)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TossCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Title").font(.headline)
                            TextField("Handoff title", text: $draft.title)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("review.edit.title")
                            Picker("Destination", selection: $draft.destination) {
                                ForEach(TossDestination.allCases, id: \.self) { value in
                                    Text(value.rawValue.capitalized).tag(value)
                                }
                            }
                        }
                    }
                    editor("Objective", text: $draft.objective)
                    editor("Context", text: $draft.context)
                    listEditor("Requirements", values: $draft.requirements)
                    listEditor("Constraints", values: $draft.constraints)
                    listEditor("Completed", values: $draft.completed)
                    listEditor("Next actions", values: $draft.nextActions)
                    listEditor("Known issues", values: $draft.knownIssues)
                    Text("Saving creates a new revision when changes are made. Original notes are preserved.")
                        .font(.caption).foregroundColor(.secondary)
                    if let error = error { Text(error).font(.caption).foregroundColor(.red) }
                    Button("Save changes", action: save)
                        .buttonStyle(TossPrimaryButton())
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .background(TossDesign.canvas.ignoresSafeArea())
            .navigationTitle("Edit handoff")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func editor(_ title: String, text: Binding<String>) -> some View {
        TossCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .accessibilityLabel(title)
            }
        }
    }

    private func listEditor(_ title: String, values: Binding<[String]>) -> some View {
        TossCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                ForEach(values.wrappedValue.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        TextEditor(text: Binding(get: {
                            values.wrappedValue.indices.contains(index) ? values.wrappedValue[index] : ""
                        }, set: { newValue in
                            if values.wrappedValue.indices.contains(index) { values.wrappedValue[index] = newValue }
                        }))
                        .frame(minHeight: 52)
                        .accessibilityLabel("\(title) item \(index + 1)")
                        Button {
                            if values.wrappedValue.indices.contains(index) { values.wrappedValue.remove(at: index) }
                        } label: {
                            Image(systemName: "minus.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove \(title) item \(index + 1)")
                    }
                }
                Button { values.wrappedValue.append("") } label: {
                    Label("Add item", systemImage: "plus.circle")
                }
            }
        }
    }

    private func save() {
        do {
            try store.saveReviewedHandoff(draft, from: original)
            dismiss()
        } catch {
            self.error = String(describing: error)
        }
    }
}

// MARK: - Toss View
@MainActor
public struct TossView: View {
    @EnvironmentObject var store: TossStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var chosenDeviceID: String?
    @State private var outcome: Outcome = .ready

    private enum Outcome: Equatable {
        case ready, sending, received(TransferAck), queued, failed(String)
    }

    public init() {}

    private var devices: [TossDevice] {
        #if targetEnvironment(simulator)
        return store.pairedDevices
        #else
        return store.pairedDevices.filter { $0.id != "local-mac" && $0.host != "127.0.0.1" && $0.host != "localhost" }
        #endif
    }

    private var target: TossDevice? {
        if let chosenDeviceID = chosenDeviceID {
            return devices.first { $0.id == chosenDeviceID }
        }
        return devices.count == 1 ? devices.first : nil
    }

    private var canSend: Bool {
        guard outcome == .ready, !store.isTransferInProgress, target != nil, let handoff = store.currentHandoff else { return false }
        return !store.queue.items.contains { $0.handoff.handoffId == handoff.handoffId && $0.handoff.revision == handoff.revision && !$0.status.isTerminal }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let handoff = store.currentHandoff {
                    TossCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Send to").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                            if devices.isEmpty {
                                Label("Looking for a Mac receiver", systemImage: "laptopcomputer")
                                    .font(.headline)
                                Text("Open the TOSS receiver on your Mac and connect to the same network.")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Button("Search again") { store.startDiscovery() }
                            } else {
                                Picker("Mac receiver", selection: $chosenDeviceID) {
                                    Text("Choose a receiver").tag(String?.none)
                                    ForEach(devices) { device in
                                        Text(device.name).tag(Optional(device.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(outcome != .ready)
                                if let target = target {
                                    Text("\(target.host):\(target.port)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    VStack(spacing: 10) {
                        Text(handoff.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        Text("Revision \(handoff.revision) · \(handoff.destination.rawValue.capitalized)")
                            .font(.subheadline).foregroundColor(.secondary)
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [.white, Color.blue.opacity(0.9), .purple],
                                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 142))
                                .frame(width: 196, height: 196)
                                .shadow(color: .purple.opacity(0.26), radius: 22, y: 8)
                            Image(systemName: ballIcon)
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 3)
                        }
                        .frame(width: 220, height: 220)
                        .offset(x: dragOffset.width * 0.4, y: dragOffset.height)
                        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset.width) / 14))
                        .contentShape(Rectangle())
                        .gesture(DragGesture()
                            .onChanged { gesture in
                                guard canSend, !reduceMotion else { return }
                                if gesture.translation.height < 0 { dragOffset = gesture.translation }
                            }
                            .onEnded { gesture in
                                if canSend && gesture.translation.height < -120 {
                                    send()
                                } else {
                                    resetBall()
                                }
                            })
                        .accessibilityLabel("Handoff ball")
                        .accessibilityIdentifier("toss.ball")
                        .accessibilityHint("Swipe up or use the Send handoff button")
                        .accessibilityAddTraits(.isImage)

                        Text(statusTitle).font(.headline).multilineTextAlignment(.center)
                        if case .received(let receipt) = outcome {
                            Text("Receipt: \(receipt.receiptId.prefix(8))")
                                .font(.caption).foregroundColor(.secondary)
                        } else if case .failed(let reason) = outcome {
                            Text(reason).font(.caption).foregroundColor(.secondary)
                        } else if case .queued = outcome {
                            Text("Open Queue to check delivery. This is not a receipt.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)

                    Button(action: send) {
                        Label("Send handoff", systemImage: "arrow.up")
                    }
                    .buttonStyle(TossPrimaryButton())
                    .disabled(!canSend)
                    if case .failed = outcome {
                        Button("Try again") { outcome = .ready }
                    }
                } else {
                    Text("No handoff ready to send.").foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .background(TossDesign.canvas.ignoresSafeArea())
        .navigationTitle("Toss")
        .navigationBarBackButtonHidden(outcome == .sending)
        .onAppear {
            store.startDiscovery()
            if chosenDeviceID == nil && devices.count == 1 { chosenDeviceID = devices.first?.id }
            if let handoff = store.currentHandoff,
               store.queue.items.contains(where: { $0.handoff.handoffId == handoff.handoffId && $0.handoff.revision == handoff.revision && !$0.status.isTerminal }) {
                outcome = .queued
            }
        }
        .onChange(of: devices) { available in
            if let id = chosenDeviceID, !available.contains(where: { $0.id == id }) { chosenDeviceID = nil }
            if chosenDeviceID == nil && available.count == 1 { chosenDeviceID = available.first?.id }
        }
    }

    private var ballIcon: String {
        switch outcome {
        case .ready: return "arrow.up"
        case .sending: return "paperplane.fill"
        case .received: return "checkmark"
        case .queued: return "clock"
        case .failed: return "exclamationmark"
        }
    }

    private var statusTitle: String {
        switch outcome {
        case .ready: return target == nil ? "Choose a receiver to toss" : "Swipe up to toss"
        case .sending: return "Sending…"
        case .received: return "Received by your Mac"
        case .queued: return "Saved to offline queue"
        case .failed: return "Could not send"
        }
    }

    private func resetBall() {
        if reduceMotion { dragOffset = .zero }
        else { withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { dragOffset = .zero } }
    }

    private func send() {
        guard canSend, let device = target else { return }
        outcome = .sending
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { dragOffset = CGSize(width: dragOffset.width, height: -450) }
        }
        Task {
            do {
                let ack = try await store.tossCurrentHandoff(to: device)
                outcome = .received(ack)
            } catch {
                outcome = store.activeTransferState == .queued ? .queued : .failed(error.localizedDescription)
            }
            resetBall()
        }
    }
}

// MARK: - Queue & Sync View
public struct QueueView: View {
    @EnvironmentObject var store: TossStore

    public init() {}

    public var body: some View { QueueList(queue: store.queue) }
}

private struct QueueList: View {
    @ObservedObject var queue: TossTransferQueue

    var body: some View {
        NavigationView {
            List {
                if queue.items.isEmpty {
                    Text("No queued transfers.")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(queue.items) { item in
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
                    queue.retryFailedItems()
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
                NavigationLink(destination: HistoryReviewEntry(handoff: item)) {
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
            }
            .searchable(text: $searchText)
            .navigationTitle("Handoff History")
        }
    }
}

@MainActor
private struct HistoryReviewEntry: View {
    @EnvironmentObject var store: TossStore
    let handoff: TossHandoff
    var body: some View {
        ReviewView().onAppear {
            if !store.isTransferInProgress {
                store.currentHandoff = store.handoffs.first(where: { $0.handoffId == handoff.handoffId }) ?? handoff
            }
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

                    Picker("Provider", selection: Binding(get: { store.modelKind }, set: { store.selectModelKind($0) })) {
                        ForEach(TossModelKind.allCases) { kind in Text(kind.label).tag(kind) }
                    }
                    if store.modelKind != .offline {
                        SecureField("API key", text: $store.modelKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                        TextField("Exact API model ID", text: $store.selectedModel)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if store.modelKind == .compatible {
                            TextField("HTTPS chat completions URL", text: $store.modelEndpoint)
                                .keyboardType(.URL).autocapitalization(.none)
                        }
                        Text("API access and quotas are separate from chat subscriptions. OpenRouter free models are rate limited.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Button("Save model settings") { store.saveModelSettings() }
                    Text(store.modelSettingsMessage).font(.caption).foregroundColor(.secondary)
                }

                Section(header: Text("Privacy & Security")) {
                    Text("Dictation prefers on-device speech recognition; Apple may process audio when local recognition is unavailable. TOSS does not save audio files. When you create a handoff with a remote model, your notes and context are sent to that selected provider. Offline formatting sends no notes to a model. API keys are stored in the device Keychain.")
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
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "square.grid.2x2") }
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
