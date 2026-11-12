import Foundation
#if canImport(TossSchema)
import TossSchema
#endif

public final class TossClient {
    private let sessionLock = NSLock()
    private var sessionSecrets: [String: (secret: String, host: String, port: Int)] = [:]
    public init() {}

    private func remember(token: String, secret: String, device: TossDevice) {
        sessionLock.lock(); defer { sessionLock.unlock() }
        if sessionSecrets.count >= 128 { sessionSecrets.removeAll() }
        sessionSecrets[token] = (secret, device.host, device.port)
    }

    private func secret(for token: String, device: TossDevice) -> String? {
        sessionLock.lock(); defer { sessionLock.unlock() }
        guard let entry = sessionSecrets[token], entry.host == device.host, entry.port == device.port else { return nil }
        return entry.secret
    }

    /// Initiates pairing handshake with a receiver
    public func pair(with device: TossDevice, pairingSecret: String) async throws -> String {
        guard let url = URL(string: "http://\(device.host):\(device.port)" + TossSecureTransport.pairPath) else {
            throw TossClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(TossSecureTransport.contentType, forHTTPHeaderField: "Content-Type")

        let pairReq = PairingRequest(
            deviceId: UUID().uuidString.lowercased(),
            deviceName: "iPhone Client",
            pairingSecret: pairingSecret
        )
        let sealed = try TossSecureTransport.sealRequest(JSONEncoder().encode(pairReq), secret: pairingSecret, path: TossSecureTransport.pairPath)
        request.httpBody = sealed

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TossClientError.networkError("Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw TossClientError.pairingRejected("Receiver rejected secure pairing (HTTP \(httpResponse.statusCode))")
        }

        let decoded = try TossSecureTransport.openResponse(data, secret: pairingSecret, path: TossSecureTransport.pairPath, request: sealed, status: httpResponse.statusCode)
        let pairResp = try JSONDecoder().decode(PairingResponse.self, from: decoded)
        guard pairResp.accepted, let token = pairResp.token else {
            throw TossClientError.pairingRejected(pairResp.message)
        }

        remember(token: token, secret: pairingSecret, device: device)
        return token
    }

    /// Sends a validated handoff payload to paired receiver
    public func sendHandoff(
        _ handoff: TossHandoff,
        to device: TossDevice,
        authToken: String,
        progressHandler: ((TransferState) -> Void)? = nil
    ) async throws -> TransferAck {
        progressHandler?(.connecting)

        guard let secret = secret(for: authToken, device: device) else {
            throw TossClientError.pairingRejected("Pair securely with this receiver first")
        }
        guard let url = URL(string: "http://\(device.host):\(device.port)" + TossSecureTransport.transferPath) else {
            progressHandler?(.failed("Invalid device URL"))
            throw TossClientError.invalidURL
        }

        progressHandler?(.sending)

        try handoff.validate()
        let jsonData = try handoff.toJSONData()
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw TossClientError.serializationFailed
        }
        let markdownString = handoff.toMarkdown()

        let jsonChecksum = TossSecurityUtils.sha256Hex(of: jsonString)
        let mdChecksum = TossSecurityUtils.sha256Hex(of: markdownString)

        let manifest = TransferManifest(
            handoffId: handoff.handoffId,
            title: handoff.title,
            schemaVersion: handoff.schemaVersion,
            files: [
                FileManifestItem(filename: "handoff.json", sizeBytes: jsonData.count, checksumSha256: jsonChecksum),
                FileManifestItem(filename: "handoff.md", sizeBytes: markdownString.utf8.count, checksumSha256: mdChecksum)
            ]
        )

        let payload = TransferPayload(
            authToken: authToken,
            manifest: manifest,
            markdownContent: markdownString,
            jsonContent: jsonString
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(TossSecureTransport.contentType, forHTTPHeaderField: "Content-Type")
        let sealed = try TossSecureTransport.sealRequest(JSONEncoder().encode(payload), secret: secret, path: TossSecureTransport.transferPath)
        request.httpBody = sealed

        progressHandler?(.verifying)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            let err = TossClientError.networkError("Invalid HTTP response")
            progressHandler?(.failed(err.localizedDescription))
            throw err
        }

        guard httpResponse.statusCode == 200 else {
            let err = TossClientError.transferFailed("Receiver rejected secure transfer (HTTP \(httpResponse.statusCode))")
            progressHandler?(.failed(err.localizedDescription))
            throw err
        }

        let decoded = try TossSecureTransport.openResponse(data, secret: secret, path: TossSecureTransport.transferPath, request: sealed, status: httpResponse.statusCode)
        let ack = try JSONDecoder().decode(TransferAck.self, from: decoded)
        guard ack.accepted, ack.handoffId == handoff.handoffId, !ack.receiptId.isEmpty,
              Set(ack.receivedFiles).isSuperset(of: ["handoff.json", "handoff.md"]) else {
            let error = TossClientError.transferFailed("Missing or invalid receiver acknowledgment")
            progressHandler?(.failed(error.localizedDescription))
            throw error
        }
        progressHandler?(.received)
        return ack
    }
}

public enum TossClientError: Error, LocalizedError {
    case invalidURL
    case pairingRejected(String)
    case transferFailed(String)
    case serializationFailed
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid destination URL"
        case .pairingRejected(let r): return "Pairing rejected: \(r)"
        case .transferFailed(let r): return "Transfer failed: \(r)"
        case .serializationFailed: return "Failed to serialize handoff package"
        case .networkError(let r): return "Network error: \(r)"
        }
    }
}
