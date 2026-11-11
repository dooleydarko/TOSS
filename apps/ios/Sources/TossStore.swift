import Foundation
import Combine
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

@MainActor
public final class TossStore: ObservableObject {
    @Published public var handoffs: [TossHandoff] = []
    @Published public var pairedDevices: [TossDevice] = []
    @Published public var currentHandoff: TossHandoff?
    @Published public var activeTransferState: TransferState? = nil
    @Published public var lastReceipt: TransferAck? = nil
    @Published public var geminiApiKey: String = ""
    @Published public var selectedModel: String = "gemini-1.5-flash"
    @Published public var preferredDestination: TossDestination = .antigravity

    private let storageKey = "toss_local_handoffs"
    private let devicesKey = "toss_paired_devices"

    public init() {
        loadFromDisk()
        if pairedDevices.isEmpty {
            // Seed a default local Mac receiver for development
            pairedDevices.append(
                TossDevice(
                    id: "local-mac",
                    name: "MacBook Pro Receiver",
                    platform: "macOS",
                    host: "127.0.0.1",
                    port: 7443,
                    isPaired: true
                )
            )
        }
    }

    public func createHandoffFromText(rawText: String, context: String = "") async throws -> TossHandoff {
        let provider: AIProvider
        if !geminiApiKey.isEmpty {
            provider = GeminiAIProvider(apiKey: geminiApiKey, model: selectedModel)
        } else {
            provider = RuleBasedFallbackProvider()
        }

        var structured = try await provider.structure(input: rawText, context: context)
        structured.destination = preferredDestination
        self.currentHandoff = structured
        self.saveHandoff(structured)
        return structured
    }

    public func saveHandoff(_ handoff: TossHandoff) {
        if let index = handoffs.firstIndex(where: { $0.handoffId == handoff.handoffId }) {
            handoffs[index] = handoff
        } else {
            handoffs.insert(handoff, at: 0)
        }
        persistToDisk()
    }

    public func tossCurrentHandoff(to device: TossDevice, pairingSecret: String = "toss-dev-secret-change-in-production") async throws -> TransferAck {
        guard let handoff = currentHandoff else {
            throw TossClientError.transferFailed("No active handoff to send")
        }

        let client = TossClient()
        activeTransferState = .connecting

        // Pair/authenticate session
        let token = try await client.pair(with: device, pairingSecret: pairingSecret)

        activeTransferState = .sending
        let ack = try await client.sendHandoff(handoff, to: device, authToken: token) { [weak self] state in
            DispatchQueue.main.async {
                self?.activeTransferState = state
            }
        }

        lastReceipt = ack
        activeTransferState = .received
        return ack
    }

    private func persistToDisk() {
        if let data = try? JSONEncoder().encode(handoffs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([TossHandoff].self, from: data) {
            self.handoffs = loaded
        }
        if let data = UserDefaults.standard.data(forKey: devicesKey),
           let loaded = try? JSONDecoder().decode([TossDevice].self, from: data) {
            self.pairedDevices = loaded
        }
    }
}
