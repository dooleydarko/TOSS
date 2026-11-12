import Foundation
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

public final class TossTransferQueue: ObservableObject {
    @Published public private(set) var items: [QueuedTransfer] = []
    private let client = TossClient()
    private let queueKey = "toss_queued_transfers"
    private var isProcessing = false
    private let lock = NSLock()

    public init() {
        loadFromDisk()
    }

    public func enqueue(handoff: TossHandoff, targetDevice: TossDevice, pairingSecret: String) -> QueuedTransfer {
        let item = QueuedTransfer(handoff: handoff, targetDevice: targetDevice, pairingSecret: pairingSecret)
        lock.lock()
        items.insert(item, at: 0)
        persistToDisk()
        lock.unlock()
        triggerQueueProcessing()
        return item
    }

    public func retryFailedItems() {
        lock.lock()
        for i in 0..<items.count {
            if case .failed = items[i].status {
                items[i].status = .pending
                items[i].attempts = 0
            }
        }
        persistToDisk()
        lock.unlock()
        triggerQueueProcessing()
    }

    public func triggerQueueProcessing() {
        guard !isProcessing else { return }
        isProcessing = true

        Task { [weak self] in
            await self?.processNextBatch()
        }
    }

    private func processNextBatch() async {
        defer { isProcessing = false }

        for index in items.indices {
            var item = items[index]
            guard !item.status.isTerminal else { continue }

            item.attempts += 1
            item.lastAttemptAt = Date()

            do {
                // Attempt pairing & transfer
                let token = try await client.pair(with: item.targetDevice, pairingSecret: item.pairingSecret)
                let ack = try await client.sendHandoff(item.handoff, to: item.targetDevice, authToken: token)

                item.status = .completed(receiptId: ack.receiptId)
                updateItem(at: index, with: item)
                print("[TOSS Queue] Successfully transferred '\(item.handoff.title)' (Receipt: \(ack.receiptId))")

            } catch {
                if item.attempts >= item.maxAttempts {
                    item.status = .failed(reason: "Max retry limit reached: \(error.localizedDescription)")
                    print("[TOSS Queue] Failed to transfer '\(item.handoff.title)': \(error.localizedDescription)")
                } else {
                    item.status = .retrying(attempts: item.attempts)
                    print("[TOSS Queue] Will retry '\(item.handoff.title)' (Attempt \(item.attempts)/\(item.maxAttempts))")
                }
                updateItem(at: index, with: item)
            }
        }
    }

    private func updateItem(at index: Int, with item: QueuedTransfer) {
        lock.lock()
        if items.indices.contains(index) {
            items[index] = item
            persistToDisk()
        }
        lock.unlock()
    }

    private func persistToDisk() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let loaded = try? JSONDecoder().decode([QueuedTransfer].self, from: data) {
            self.items = loaded
        }
    }
}
