import Foundation
#if canImport(TossSchema)
import TossSchema
#endif

public final class TossClient {
    public init() {}

    /// Initiates pairing handshake with a receiver
    public func pair(with device: TossDevice, pairingSecret: String) async throws -> String {
        guard let url = URL(string: "http://\(device.host):\(device.port)/pair") else {
            throw TossClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let pairReq = PairingRequest(
            deviceId: UUID().uuidString.lowercased(),
            deviceName: "iPhone Client",
            pairingSecret: pairingSecret
        )
        request.httpBody = try JSONEncoder().encode(pairReq)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TossClientError.networkError("Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TossClientError.pairingRejected(errorMsg)
        }

        let pairResp = try JSONDecoder().decode(PairingResponse.self, from: data)
        guard pairResp.accepted, let token = pairResp.token else {
            throw TossClientError.pairingRejected(pairResp.message)
        }

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

        guard let url = URL(string: "http://\(device.host):\(device.port)/transfer") else {
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        progressHandler?(.verifying)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            let err = TossClientError.networkError("Invalid HTTP response")
            progressHandler?(.failed(err.localizedDescription))
            throw err
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            let err = TossClientError.transferFailed(errorMsg)
            progressHandler?(.failed(err.localizedDescription))
            throw err
        }

        let ack = try JSONDecoder().decode(TransferAck.self, from: data)
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
