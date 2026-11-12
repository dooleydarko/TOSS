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
    @Published public private(set) var reachableDeviceIDs: Set<String> = []
    @Published public private(set) var pairingInProgress = false
    private let deviceCredentials = TossQueueCredentialStore.keychain(namespace: "trusted-devices-v1")

    private func credentialID(_ device: TossDevice) -> String {
        TossSecurityUtils.sha256Hex(of: device.id + "|" + device.host.lowercased() + "|" + String(device.port))
    }

    public func savedPairingCode(for device: TossDevice) -> String {
        guard device.isPaired else { return "" }
        return deviceCredentials.read(credentialID(device)) ?? ""
    }

    public func pairDevice(_ device: TossDevice, code: String) async throws {
        guard !pairingInProgress else { throw TossClientError.pairingRejected("Pairing already in progress") }
        pairingInProgress = true
        defer { pairingInProgress = false }
        let client = TossClient()
        _ = try await client.pair(with: device, pairingSecret: code)
        try rememberTrust(device, code: code)
    }

    private func rememberTrust(_ device: TossDevice, code: String) throws {
        guard deviceCredentials.write(credentialID(device), code) else {
            throw TossClientError.pairingRejected("Could not save device trust in Keychain")
        }
        var trusted = device
        trusted.isPaired = true
        trusted.lastSeen = Date()
        if let index = pairedDevices.firstIndex(where: { $0.id == device.id }) {
            pairedDevices[index] = trusted
        } else { pairedDevices.append(trusted) }
        reachableDeviceIDs.insert(device.id)
        persistToDisk()
    }

    public func forgetDevice(_ device: TossDevice) {
        guard !isTransferInProgress, !pairingInProgress else { return }
        deviceCredentials.remove(credentialID(device))
        queue.forgetReceiver(device)
        if reachableDeviceIDs.contains(device.id), let index = pairedDevices.firstIndex(where: { $0.id == device.id }) {
            pairedDevices[index].isPaired = false
        } else {
            pairedDevices.removeAll { $0.id == device.id }
        }
        persistToDisk()
    }
    @Published public var currentHandoff: TossHandoff?
    @Published public var activeTransferState: TransferState? = nil
    @Published public var lastReceipt: TransferAck? = nil
    @Published public private(set) var isTransferInProgress = false
    private var revisionSnapshots: [TossHandoff] = []
    @Published public var modelKind: TossModelKind = .offline
    @Published public var modelKey = ""
    @Published public var selectedModel = ""
    @Published public var modelEndpoint = ""
    @Published public private(set) var modelSettingsMessage = ""
    public var modelLabel: String { modelKind == .offline ? modelKind.label : "\(modelKind.label): \(selectedModel)" }
    public func selectModelKind(_ kind: TossModelKind) {
        modelKind = kind
        let defaults = UserDefaults.standard
        modelKey = TossModelKeychain.read(kind)
        selectedModel = defaults.string(forKey: "toss.model.\(kind.rawValue)") ?? kind.defaultModel
        modelEndpoint = defaults.string(forKey: "toss.model.endpoint") ?? ""
        modelSettingsMessage = ""
    }
    public func saveModelSettings() {
        guard TossModelKeychain.write(modelKey, for: modelKind) else {
            modelSettingsMessage = "Could not save key securely."
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(modelKind.rawValue, forKey: "toss.model.kind")
        defaults.set(selectedModel, forKey: "toss.model.\(modelKind.rawValue)")
        defaults.set(modelEndpoint, forKey: "toss.model.endpoint")
        modelSettingsMessage = "Saved on this device."
    }
    @Published public var preferredDestination: TossDestination = .antigravity
    @Published public var isDiscoveryActive: Bool = false
    @Published public var queue = TossTransferQueue()

    private let discoveryService = TossDiscoveryService()
    private let storageKey = "toss_local_handoffs"
    // The legacy list persisted unauthenticated Bonjour discoveries. Do not
    // treat that list as trusted or migrate its flags into this new store.
    private let devicesKey = "toss_trusted_receivers_v1"

    public init() {
        loadFromDisk()
        selectModelKind(TossModelKind(rawValue: UserDefaults.standard.string(forKey: "toss.model.kind") ?? "") ?? .offline)
        #if targetEnvironment(simulator)
        if !pairedDevices.contains(where: { $0.id == "local-mac" }) {
            pairedDevices.append(
                TossDevice(
                    id: "local-mac",
                    name: "MacBook Pro Receiver",
                    platform: "macOS",
                    host: "127.0.0.1",
                    port: 7443,
                    isPaired: false
                )
            )
        }
        #endif
        setupDiscovery()
        queue.triggerQueueProcessing()
    }

    public func startDiscovery() {
        isDiscoveryActive = true
        reachableDeviceIDs.removeAll()
        pairedDevices.removeAll { !$0.isPaired && $0.id != "local-mac" }
        discoveryService.startBrowsing()
    }

    public func stopDiscovery() {
        isDiscoveryActive = false
        reachableDeviceIDs.removeAll()
        discoveryService.stopBrowsing()
    }

    private func setupDiscovery() {
        discoveryService.onDeviceFound = { [weak self] device in
            DispatchQueue.main.async {
                guard let self = self else { return }
                var found = device
                // Bonjour is discovery only, never proof of trust. Only reuse a
                // credential for the identical previously authenticated endpoint.
                if let existing = self.pairedDevices.first(where: { $0.id == device.id && $0.host == device.host && $0.port == device.port }),
                   existing.isPaired, !self.savedPairingCode(for: existing).isEmpty {
                    found.isPaired = true
                }
                self.reachableDeviceIDs.insert(found.id)
                if let index = self.pairedDevices.firstIndex(where: { $0.id == found.id }) {
                    self.pairedDevices[index] = found
                } else {
                    self.pairedDevices.append(found)
                }
                self.persistToDisk()
            }
        }
        discoveryService.onDeviceLost = { [weak self] deviceName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                for device in self.pairedDevices where device.name == deviceName {
                    self.reachableDeviceIDs.remove(device.id)
                }
                self.pairedDevices.removeAll { $0.name == deviceName && !$0.isPaired && $0.id != "local-mac" }
            }
        }
    }

    public func createHandoffFromText(rawText: String, context: String = "", sourceType: TossSource.SourceType = .text) async throws -> TossHandoff {
        let provider: AIProvider
        switch modelKind {
        case .offline: provider = RuleBasedFallbackProvider()
        case .gemini: provider = GeminiAIProvider(apiKey: modelKey, model: selectedModel)
        default: provider = TossRemoteProvider(kind: modelKind, model: selectedModel, key: modelKey, endpoint: modelEndpoint)
        }
        guard provider.isConfigured else { throw TossValidationError.invalidField("Configure your chosen model in Settings, or select Offline.") }

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

    public func tossCurrentHandoff(to device: TossDevice, pairingSecret: String) async throws -> TransferAck {
        guard !pairingSecret.isEmpty else { throw TossClientError.pairingRejected("Enter the receiver pairing secret") }
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
            // Pairing has been authenticated, but a Keychain write failure
            // must not prevent this explicitly approved one-time transfer.
            try? rememberTrust(device, code: pairingSecret)
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
            if let clientError = error as? TossClientError, case .pairingRejected = clientError {
                activeTransferState = .failed(clientError.localizedDescription)
                throw clientError
            }
            print("[TOSS Store] Direct transfer failed; queuing for auto-retry.")
            let queued = queue.enqueue(handoff: handoff, targetDevice: device, pairingSecret: pairingSecret)
            if case .failed(let reason) = queued.status {
                activeTransferState = .failed(reason)
                throw TossClientError.transferFailed(reason)
            }
            activeTransferState = .queued
            throw error
        }
    }

    private func persistToDisk() {
        if let data = try? JSONEncoder().encode(revisionSnapshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(pairedDevices.filter { $0.isPaired && $0.id != "local-mac" }) {
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
            self.pairedDevices = loaded.filter { $0.id != "local-mac" && $0.isPaired }
        }
    }
}
