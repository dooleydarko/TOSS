import Foundation
import CryptoKit
#if canImport(TossSchema)
import TossSchema
#endif

public enum TransferState: Equatable, CustomStringConvertible {
    case queued
    case connecting
    case sending
    case verifying
    case received
    case failed(String)
    case cancelled

    public var description: String {
        switch self {
        case .queued: return "Queued"
        case .connecting: return "Connecting"
        case .sending: return "Sending"
        case .verifying: return "Verifying"
        case .received: return "Received"
        case .failed(let reason): return "Failed: \(reason)"
        case .cancelled: return "Cancelled"
        }
    }
}

public struct TossDevice: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var platform: String
    public var host: String
    public var port: Int
    public var isPaired: Bool
    public var lastSeen: Date

    public init(id: String, name: String, platform: String = "macOS", host: String, port: Int = 7443, isPaired: Bool = false, lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.platform = platform
        self.host = host
        self.port = port
        self.isPaired = isPaired
        self.lastSeen = lastSeen
    }
}

public struct PairingRequest: Codable, Equatable {
    public var deviceId: String
    public var deviceName: String
    public var pairingSecret: String
    public var timestamp: String

    public init(deviceId: String, deviceName: String, pairingSecret: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.pairingSecret = pairingSecret
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

public struct PairingResponse: Codable, Equatable {
    public var accepted: Bool
    public var token: String?
    public var receiverName: String
    public var message: String

    public init(accepted: Bool, token: String? = nil, receiverName: String, message: String) {
        self.accepted = accepted
        self.token = token
        self.receiverName = receiverName
        self.message = message
    }
}

public struct FileManifestItem: Codable, Equatable {
    public var filename: String
    public var sizeBytes: Int
    public var checksumSha256: String

    public init(filename: String, sizeBytes: Int, checksumSha256: String) {
        self.filename = filename
        self.sizeBytes = sizeBytes
        self.checksumSha256 = checksumSha256
    }
}

public struct TransferManifest: Codable, Equatable {
    public var handoffId: String
    public var title: String
    public var schemaVersion: String
    public var files: [FileManifestItem]
    public var timestamp: String

    public init(handoffId: String, title: String, schemaVersion: String, files: [FileManifestItem]) {
        self.handoffId = handoffId
        self.title = title
        self.schemaVersion = schemaVersion
        self.files = files
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

public struct TransferPayload: Codable {
    public var authToken: String
    public var manifest: TransferManifest
    public var markdownContent: String
    public var jsonContent: String

    public init(authToken: String, manifest: TransferManifest, markdownContent: String, jsonContent: String) {
        self.authToken = authToken
        self.manifest = manifest
        self.markdownContent = markdownContent
        self.jsonContent = jsonContent
    }
}

public struct TransferAck: Codable, Equatable {
    public var receiptId: String
    public var handoffId: String
    public var accepted: Bool
    public var receivedFiles: [String]
    public var savedToDirectory: String
    public var receivedAt: String
    public var message: String

    public init(receiptId: String = UUID().uuidString.lowercased(), handoffId: String, accepted: Bool, receivedFiles: [String], savedToDirectory: String, message: String) {
        self.receiptId = receiptId
        self.handoffId = handoffId
        self.accepted = accepted
        self.receivedFiles = receivedFiles
        self.savedToDirectory = savedToDirectory
        self.receivedAt = ISO8601DateFormatter().string(from: Date())
        self.message = message
    }
}

public enum TossSecurityUtils {
    /// Computes lowercase hex SHA-256 of data
    public static func sha256Hex(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Computes lowercase hex SHA-256 of a string
    public static func sha256Hex(of string: String) -> String {
        return sha256Hex(of: Data(string.utf8))
    }

    /// Strictly sanitizes file name to prevent path traversal
    public static func sanitizeFilename(_ raw: String) -> String {
        var clean = raw
            .replacingOccurrences(of: "..", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\0", with: "")

        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        clean = clean.unicodeScalars.filter { allowedChars.contains($0) }.map { String($0) }.joined()

        if clean.isEmpty {
            return "untitled_\(UUID().uuidString.prefix(8))"
        }
        return clean
    }
}
