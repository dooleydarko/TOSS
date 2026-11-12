import Foundation
import Combine
import Security
#if canImport(TossSchema)
import TossSchema
#endif

public enum QueueStatus: Codable, Equatable {
    case pending
    case retrying(attempts: Int)
    case completed(receiptId: String)
    case failed(reason: String)

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed: return true
        default: return false
        }
    }
}

public struct QueuedTransfer: Codable, Identifiable, Equatable {
    public var id: String
    public var handoff: TossHandoff
    public var targetDevice: TossDevice
    public var pairingSecret: String
    public var status: QueueStatus
    public var queuedAt: Date
    public var lastAttemptAt: Date?
    public var attempts: Int
    public var maxAttempts: Int

    public init(
        id: String = UUID().uuidString.lowercased(),
        handoff: TossHandoff,
        targetDevice: TossDevice,
        pairingSecret: String = "toss-dev-secret-change-in-production",
        maxAttempts: Int = 5
    ) {
        self.id = id
        self.handoff = handoff
        self.targetDevice = targetDevice
        self.pairingSecret = pairingSecret
        self.status = .pending
        self.queuedAt = Date()
        self.lastAttemptAt = nil
        self.attempts = 0
        self.maxAttempts = maxAttempts
    }
}

/// Queue credentials are stored separately from the Codable queue snapshot.
public struct TossQueueCredentialStore {
    public let read: (String) -> String?
    public let write: (String, String) -> Bool
    public let remove: (String) -> Void

    public init(read: @escaping (String) -> String?, write: @escaping (String, String) -> Bool,
                remove: @escaping (String) -> Void) {
        self.read = read
        self.write = write
        self.remove = remove
    }

    public static func keychain(namespace: String) -> Self {
        let service = "com.dooleydarko.toss.queue." + namespace
        func query(_ id: String) -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: service, kSecAttrAccount as String: id]
        }
        return Self(read: { id in
            var request = query(id)
            request[kSecReturnData as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }, write: { id, secret in
            let request = query(id)
            let data = Data(secret.utf8)
            let status = SecItemUpdate(request as CFDictionary,
                                       [kSecValueData as String: data] as CFDictionary)
            if status == errSecSuccess { return true }
            guard status == errSecItemNotFound else { return false }
            var add = request
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }, remove: { id in
            _ = SecItemDelete(query(id) as CFDictionary)
        })
    }
}

public final class TossTransferQueue: ObservableObject {
    @Published public private(set) var items: [QueuedTransfer] = []
    private let defaults: UserDefaults
    private let queueKey: String
    private let credentials: TossQueueCredentialStore
    private let retryBase: TimeInterval
    private let send: (QueuedTransfer) async throws -> String
    private var isProcessing = false
    private var wakeTask: Task<Void, Never>?

    // All mutable queue state belongs to the main thread. Network operations
    // suspend without holding a lock; publish and persist updates by stable ID.
    public init(defaults: UserDefaults = .standard,
                queueKey: String = "toss_queued_transfers",
                retryBase: TimeInterval = 2,
                credentials: TossQueueCredentialStore? = nil,
                send: ((QueuedTransfer) async throws -> String)? = nil) {
        self.defaults = defaults
        self.queueKey = queueKey
        self.credentials = credentials ?? .keychain(namespace: queueKey)
        self.retryBase = max(0.01, retryBase)
        self.send = send ?? { item in
            let client = TossClient()
            let token = try await client.pair(with: item.targetDevice, pairingSecret: item.pairingSecret)
            let ack = try await client.sendHandoff(item.handoff, to: item.targetDevice, authToken: token)
            return ack.receiptId
        }
        if let data = defaults.data(forKey: queueKey),
           let loaded = try? JSONDecoder().decode([QueuedTransfer].self, from: data) {
            // Migrate legacy plaintext snapshots before writing a redacted copy.
            // A failed migration is visible and never causes an unauthenticated send.
            items = loaded.map { item in
                var restored = item
                if case .completed = restored.status {
                    self.credentials.remove(restored.id)
                    restored.pairingSecret = ""
                } else if !restored.pairingSecret.isEmpty {
                    if !self.credentials.write(restored.id, restored.pairingSecret) {
                        restored.status = .failed(reason: "Could not migrate pairing credential securely. Retry or send again.")
                    }
                } else {
                    restored.pairingSecret = self.credentials.read(restored.id) ?? ""
                }
                return restored
            }
            persistToDisk()
        }
    }

    @discardableResult
    public func enqueue(handoff: TossHandoff, targetDevice: TossDevice, pairingSecret: String) -> QueuedTransfer {
        precondition(Thread.isMainThread)
        if let existing = items.first(where: {
            !$0.status.isTerminal && $0.handoff.handoffId == handoff.handoffId &&
            $0.handoff.revision == handoff.revision && $0.targetDevice.id == targetDevice.id
        }) {
            triggerQueueProcessing()
            return existing
        }
        var item = QueuedTransfer(handoff: handoff, targetDevice: targetDevice, pairingSecret: pairingSecret)
        if pairingSecret.isEmpty || !credentials.write(item.id, pairingSecret) {
            item.status = .failed(reason: "Pairing credential could not be saved securely. Retry or send again.")
        }
        items.insert(item, at: 0)
        persistToDisk()
        triggerQueueProcessing()
        return item
    }

    public func retryFailedItems() {
        precondition(Thread.isMainThread)
        for i in items.indices {
            if case .failed = items[i].status {
                items[i].status = .pending
                items[i].attempts = 0
                items[i].lastAttemptAt = nil
            }
        }
        persistToDisk()
        triggerQueueProcessing()
    }

    public func triggerQueueProcessing() {
        precondition(Thread.isMainThread)
        guard !isProcessing else { return }
        wakeTask?.cancel()
        wakeTask = nil
        isProcessing = true
        Task { @MainActor [weak self] in
            await self?.processNextBatch()
        }
    }

    private func readyAt(_ item: QueuedTransfer) -> Date {
        guard let last = item.lastAttemptAt, item.attempts > 0 else { return .distantPast }
        let delay = min(60, retryBase * pow(2, Double(min(10, item.attempts - 1))))
        return last.addingTimeInterval(delay)
    }

    @MainActor
    private func processNextBatch() async {
        while true {
            let pending = items.filter { !$0.status.isTerminal }.sorted { $0.queuedAt < $1.queuedAt }
            guard let item = pending.first(where: { readyAt($0) <= Date() }) else {
                isProcessing = false
                if let next = pending.map({ readyAt($0) }).min() {
                    let delay = max(0.01, next.timeIntervalSinceNow)
                    wakeTask = Task { @MainActor [weak self] in
                        do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                        catch { return }
                        guard !Task.isCancelled else { return }
                        self?.wakeTask = nil
                        self?.triggerQueueProcessing()
                    }
                }
                return
            }
            var attempt = item
            if attempt.attempts >= attempt.maxAttempts {
                attempt.status = .failed(reason: "Retry limit reached; retry manually if needed.")
                updateItem(attempt)
                continue
            }
            let secret = attempt.pairingSecret.isEmpty ? credentials.read(attempt.id) ?? "" : attempt.pairingSecret
            guard !secret.isEmpty, credentials.write(attempt.id, secret) else {
                attempt.status = .failed(reason: "Pairing credential unavailable. Unlock the device and retry or send again.")
                updateItem(attempt)
                continue
            }
            attempt.pairingSecret = secret
            attempt.attempts += 1
            attempt.lastAttemptAt = Date()
            updateItem(attempt)
            do {
                let receipt = try await send(attempt)
                guard !receipt.isEmpty else { throw TossClientError.transferFailed("Missing receipt") }
                attempt.status = .completed(receiptId: receipt)
                credentials.remove(attempt.id)
                attempt.pairingSecret = ""
            } catch {
                attempt.lastAttemptAt = Date()
                if attempt.attempts >= attempt.maxAttempts {
                    attempt.status = .failed(reason: "Max retry limit reached: \(error.localizedDescription)")
                } else {
                    attempt.status = .retrying(attempts: attempt.attempts)
                }
            }
            updateItem(attempt)
        }
    }

    private func updateItem(_ item: QueuedTransfer) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        persistToDisk()
    }

    private func persistToDisk() {
        let redacted = items.map { item -> QueuedTransfer in
            var snapshot = item
            snapshot.pairingSecret = ""
            return snapshot
        }
        if let data = try? JSONEncoder().encode(redacted) {
            defaults.set(data, forKey: queueKey)
        }
    }
}
