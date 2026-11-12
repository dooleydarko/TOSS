import AVFoundation
import Speech
import SwiftUI

/// One microphone tap feeds both speech recognition and live RMS metering.
/// All UI state and lifecycle changes are isolated to the main actor.
@MainActor
final class VoiceCapture: ObservableObject {
    enum State: Equatable { case idle, authorizing, recording, finishing }
    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var levels = Array(repeating: Float.zero, count: 30)
    @Published private(set) var errorMessage: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var tapInstalled = false
    private var sessionActive = false
    private var generation = UUID()
    private var finishTimeout: Task<Void, Never>?

    var isBusy: Bool { state != .idle }

    func start() async {
        guard state == .idle else { return }
        let id = UUID()
        generation = id
        transcript = ""
        levels = Array(repeating: 0, count: 30)
        errorMessage = nil
        state = .authorizing

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard generation == id else { return }
        guard microphoneAllowed else {
            finishWithError("Microphone access is disabled. Enable it in Settings or type your notes.")
            return
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard generation == id else { return }
        guard speechStatus == .authorized else {
            finishWithError("Speech recognition access is disabled. Enable it in Settings or type your notes.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            finishWithError("Speech recognition is unavailable. Try again or type your notes.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            sessionActive = true
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                finishWithError("No usable microphone input was found.")
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Prefer local recognition; some devices/locales require Apple's service.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request
            self.recognizer = recognizer
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                let message = error?.localizedDescription
                DispatchQueue.main.async {
                    guard let self = self, self.generation == id else { return }
                    if let text = text, !text.isEmpty { self.transcript = text }
                    if isFinal {
                        self.cleanUp()
                    } else if let message = message {
                        self.finishWithError("Dictation ended: \(message). Your captured text is retained.")
                    }
                }
            }

            node.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.normalizedLevel(buffer)
                DispatchQueue.main.async {
                    guard let self = self, self.generation == id, self.state == .recording else { return }
                    self.levels.removeFirst()
                    self.levels.append(level)
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            state = .recording
        } catch {
            finishWithError("Could not start recording: \(error.localizedDescription)")
        }
    }

    /// Stop capturing immediately, then allow the recognizer to deliver its final result.
    func stop() {
        guard state == .recording else { return }
        state = .finishing
        stopInput()
        request?.endAudio()
        let id = generation
        finishTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, let self = self, self.generation == id else { return }
            self.cleanUp()
        }
    }

    func cancel() {
        guard isBusy else { return }
        cleanUp()
    }

    func interrupted() {
        guard isBusy else { return }
        finishWithError("Recording was interrupted. Your captured text is retained.")
    }

    private func finishWithError(_ message: String) {
        errorMessage = message
        cleanUp()
    }

    private func stopInput() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }

    private func cleanUp() {
        generation = UUID() // Ignore late callbacks from previous sessions.
        finishTimeout?.cancel()
        finishTimeout = nil
        stopInput()
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        recognizer = nil
        levels = Array(repeating: 0, count: 30)
        state = .idle
    }

    nonisolated private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        let stride = buffer.stride
        for index in 0..<count {
            let value = samples[0][index * stride]
            sum += value * value
        }
        let rms = sqrt(sum / Float(count))
        guard rms.isFinite, rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(1, max(0, (decibels + 60) / 60))
    }
}

struct MicrophoneWaveform: View {
    let levels: [Float]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4 + CGFloat(levels[index]) * 36)
            }
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }
}
