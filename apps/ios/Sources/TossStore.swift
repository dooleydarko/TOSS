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
    @Published public private(set) var isTransferInProgress = false
    private var revisionSnapshots: [TossHandoff] = []
    @Published public var geminiApiKey: String = ""
    @Published public var selectedModel: String = "gemini-1.5-flash"
    @Published public var preferredDestination: TossDestination = .antigravity
    @Published public var isDiscoveryActive: Bool = false
    @Published public var queue = TossTransferQueue()

    private let discoveryService = TossDiscoveryService()
    private let storageKey = "toss_local_handoffs"
    private let devicesKey = "toss_paired_devices"

    public init() {
        loadFromDisk()
        if pairedDevices.isEmpty {
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
        setupDiscovery()
    }

    public func startDiscovery() {
        isDiscoveryActive = true
        discoveryService.startBrowsing()
    }

    public func stopDiscovery() {
        isDiscoveryActive = false
        discoveryService.stopBrowsing()
    }

    private func setupDiscovery() {
        discoveryService.onDeviceFound = { [weak self] device in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let index = self.pairedDevices.firstIndex(where: { $0.id == device.id || $0.name == device.name }) {
                    self.pairedDevices[index] = device
                } else {
                    self.pairedDevices.append(device)
                }
                self.persistToDisk()
            }
        }
        discoveryService.onDeviceLost = { [weak self] deviceName in
            DispatchQueue.main.async {
                self?.pairedDevices.removeAll(where: { $0.name == deviceName && $0.id != "local-mac" })
            }
        }
    }

    public func createHandoffFromText(rawText: String, context: String = "", sourceType: TossSource.SourceType = .text) async throws -> TossHandoff {
        let provider: AIProvider
        if !geminiApiKey.isEmpty {
            provider = GeminiAIProvider(apiKey: geminiApiKey, model: selectedModel)
        } else {
            provider = RuleBasedFallbackProvider()
        }

        var structured = try await provider.structure(input: rawText, context: context)
        structured.destination = preferredDestination
        structured.source = TossSource(type: sourceType, transcriptAvailable: sourceType == .voice, rawInput: rawText)
        self.currentHandoff = structured
        self.saveHandoff(structured)
        return structured
    }

    public func saveHandoff(_ handoff: TossHandoff) {
        revisionSnapshots = TossReviewRevision.upsert(handoff, into: revisionSnapshots)
        handoffs = TossReviewRevision.latest(in: revisionSnapshots)
        persistToDisk()
    }

    public func saveReviewedHandoff(_ draft: TossHandoff, from original: TossHandoff) throws {
        guard !isTransferInProgress,
              currentHandoff?.handoffId == original.handoffId,
              let latest = handoffs.first(where: { $0.handoffId == original.handoffId }) else {
            throw TossValidationError.invalidField("The current handoff is no longer available for editing.")
        }
        let updated = try TossReviewRevision.edited(draft, from: original, latestRevision: latest.revision)
        currentHandoff = updated
        saveHandoff(updated)
    }

    public func tossCurrentHandoff(to device: TossDevice, pairingSecret: String = "toss-dev-secret-change-in-production") async throws -> TransferAck {
        guard let handoff = currentHandoff else {
            throw TossClientError.transferFailed("No active handoff to send")
        }

        guard !isTransferInProgress else {
            throw TossClientError.transferFailed("A handoff is already being sent")
        }
        isTransferInProgress = true
        defer { isTransferInProgress = false }
        lastReceipt = nil
        let client = TossClient()
        activeTransferState = .connecting

        do {
            let token = try await client.pair(with: device, pairingSecret: pairingSecret)
            activeTransferState = .sending
            let ack = try await client.sendHandoff(handoff, to: device, authToken: token)
            guard ack.accepted, ack.handoffId == handoff.handoffId,
                  !ack.receiptId.isEmpty, Set(ack.receivedFiles).isSuperset(of: ["handoff.json", "handoff.md"]) else {
                throw TossClientError.transferFailed("Receiver did not acknowledge the expected handoff")
            }
            lastReceipt = ack
            activeTransferState = .received
            return ack
        } catch {
            print("[TOSS Store] Direct transfer failed (\(error.localizedDescription)). Queuing for auto-retry...")
            _ = queue.enqueue(handoff: handoff, targetDevice: device, pairingSecret: pairingSecret)
            activeTransferState = .queued
            throw error
        }
    }

    private func persistToDisk() {
        if let data = try? JSONEncoder().encode(revisionSnapshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([TossHandoff].self, from: data) {
            self.revisionSnapshots = loaded
            self.handoffs = TossReviewRevision.latest(in: loaded)
        }
        if let data = UserDefaults.standard.data(forKey: devicesKey),
           let loaded = try? JSONDecoder().decode([TossDevice].self, from: data) {
            self.pairedDevices = loaded
        }
    }
}
