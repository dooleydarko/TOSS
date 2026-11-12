import Foundation
import CryptoKit

/// Versioned application-layer encryption for TOSS's bounded HTTP transport.
/// A fresh, out-of-band 256-bit random pairing code is required for LAN use.
public enum TossSecureTransport {
    public static let pairPath = "/v2/pair"
    public static let transferPath = "/v2/transfer"
    public static let contentType = "application/octet-stream"

    public static func isLANCode(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func key(_ secret: String, direction: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(secret.utf8)),
            salt: Data("TOSS secure transport v2".utf8), info: Data(direction.utf8), outputByteCount: 32)
    }

    private struct Request: Codable {
        var timestamp: Date
        var body: Data
    }

    public static func sealRequest(_ body: Data, secret: String, path: String, now: Date = Date()) throws -> Data {
        let frame = try JSONEncoder().encode(Request(timestamp: now, body: body))
        return try seal(frame, secret: secret, direction: "request", aad: "POST " + path)
    }

    public static func openRequest(_ sealed: Data, secret: String, path: String, now: Date = Date()) throws -> Data {
        let frame = try JSONDecoder().decode(Request.self, from: open(sealed, secret: secret, direction: "request", aad: "POST " + path))
        guard abs(frame.timestamp.timeIntervalSince(now)) <= 120 else { throw TossSecureError.staleRequest }
        return frame.body
    }

    public static func sealResponse(_ body: Data, secret: String, path: String, request: Data, status: Int) throws -> Data {
        try seal(body, secret: secret, direction: "response", aad: responseAAD(path, request, status))
    }

    public static func openResponse(_ sealed: Data, secret: String, path: String, request: Data, status: Int) throws -> Data {
        try open(sealed, secret: secret, direction: "response", aad: responseAAD(path, request, status))
    }

    private static func responseAAD(_ path: String, _ request: Data, _ status: Int) -> String {
        path + "|" + TossSecurityUtils.sha256Hex(of: request) + "|" + String(status)
    }

    private static func seal(_ data: Data, secret: String, direction: String, aad: String) throws -> Data {
        guard !secret.isEmpty, let combined = try AES.GCM.seal(data, using: key(secret, direction: direction),
            authenticating: Data(aad.utf8)).combined else { throw TossSecureError.invalidEnvelope }
        return combined
    }

    private static func open(_ data: Data, secret: String, direction: String, aad: String) throws -> Data {
        guard !secret.isEmpty else { throw TossSecureError.invalidEnvelope }
        return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key(secret, direction: direction),
            authenticating: Data(aad.utf8))
    }
}

public enum TossSecureError: Error {
    case invalidEnvelope, staleRequest
}
