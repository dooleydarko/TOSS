import Foundation
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class ReceiverServer {
    public let host: String
    public let port: UInt16
    public let storageDirectory: URL
    public let pairingSecret: String
    public let receiverName: String

    private var validSessionTokens: [String: Date] = [:]
    private let sessionLock = NSLock()
    private let sessionLifetime: TimeInterval
    private let connectionSlots = DispatchSemaphore(value: 16)
    private let maxHeaderBytes = 16 * 1024
    private let maxBodyBytes = 10 * 1024 * 1024
    private let transferLock = NSLock()
    private let replayLock = NSLock()
    private var pairingRequests: [String: Date] = [:]
    private var serverSocket: Int32 = -1
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "com.toss.receiver.server", attributes: .concurrent)

    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 7443,
        storageDirectory: URL,
        pairingSecret: String = "toss-dev-secret-change-in-production",
        receiverName: String = Host.current().localizedName ?? "Mac Receiver",
        sessionLifetime: TimeInterval = 3600
    ) {
        self.host = host
        self.port = port
        self.storageDirectory = storageDirectory
        self.pairingSecret = pairingSecret
        self.receiverName = receiverName
        self.sessionLifetime = max(0, sessionLifetime)
    }

    public func start(blocking: Bool = false) throws {
        guard host == "127.0.0.1" || TossSecureTransport.isLANCode(pairingSecret) else {
            throw ReceiverError.bindFailed("LAN requires a random 256-bit pairing code")
        }
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw ReceiverError.socketFailed("Failed to create socket")
        }

        var opt: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            close(serverSocket)
            serverSocket = -1
            throw ReceiverError.bindFailed("Invalid IPv4 bind address")
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            close(serverSocket)
            throw ReceiverError.bindFailed("Failed to bind socket on \(host):\(port)")
        }

        guard listen(serverSocket, 128) >= 0 else {
            close(serverSocket)
            throw ReceiverError.listenFailed("Failed to listen on socket")
        }

        isRunning = true
        print("[TOSS Receiver] Listening on http://\(host):\(port)")
        print("[TOSS Receiver] Destination storage: \(storageDirectory.path)")

        if blocking {
            runAcceptLoop()
        } else {
            queue.async { [weak self] in
                self?.runAcceptLoop()
            }
        }
    }

    public func stop() {
        isRunning = false
        sessionLock.lock()
        validSessionTokens.removeAll()
        sessionLock.unlock()
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        print("[TOSS Receiver] Stopped.")
    }

    private func runAcceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else {
                if !isRunning { break }
                continue
            }

            guard connectionSlots.wait(timeout: .now()) == .success else {
                close(clientSocket)
                continue
            }
            DispatchQueue.global(qos: .userInitiated).async {
                defer { self.connectionSlots.signal() }
                self.handleClient(clientSocket: clientSocket)
            }
        }
    }

    private func handleClient(clientSocket: Int32) {
        defer { close(clientSocket) }

        #if canImport(Darwin)
        var noSignal: Int32 = 1
        setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        #endif
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(clientSocket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        var buffer = [UInt8](repeating: 0, count: 8192)
        var received = Data()
        let boundary = Data("\r\n\r\n".utf8)
        while received.range(of: boundary) == nil {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                sendResponse(clientSocket: clientSocket, status: 408, body: "Request timeout")
                return
            }
            let n = read(clientSocket, &buffer, buffer.count)
            guard n > 0 else { return }
            received.append(buffer, count: n)
            if received.count > maxHeaderBytes && received.range(of: boundary) == nil {
                sendResponse(clientSocket: clientSocket, status: 431, body: "Headers too large")
                return
            }
        }
        guard let range = received.range(of: boundary), range.lowerBound <= maxHeaderBytes else {
            sendResponse(clientSocket: clientSocket, status: 431, body: "Headers too large")
            return
        }
        guard let header = String(data: received.prefix(range.lowerBound), encoding: .utf8) else {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid header encoding")
            return
        }
        let lines = header.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count == 3, parts[2] == "HTTP/1.1" || parts[2] == "HTTP/1.0" else {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid HTTP request line")
            return
        }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])
        var length: Int?
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else {
                sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid header")
                return
            }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if key == "transfer-encoding" {
                sendResponse(clientSocket: clientSocket, status: 400, body: "Transfer-Encoding unsupported")
                return
            }
            if key == "content-length" {
                guard length == nil, !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
                      let parsed = Int(value) else {
                    sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid Content-Length")
                    return
                }
                guard parsed <= maxBodyBytes else {
                    sendResponse(clientSocket: clientSocket, status: 413, body: "Payload too large")
                    return
                }
                length = parsed
            }
        }
        guard method != "POST" || length != nil else {
            sendResponse(clientSocket: clientSocket, status: 411, body: "Content-Length required")
            return
        }
        let contentLength = length ?? 0
        var body = Data(received.suffix(from: range.upperBound))
        guard body.count <= contentLength else {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Unexpected request bytes")
            return
        }
        while body.count < contentLength {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                sendResponse(clientSocket: clientSocket, status: 408, body: "Request timeout")
                return
            }
            let remaining = min(buffer.count, contentLength - body.count)
            let n = read(clientSocket, &buffer, remaining)
            guard n > 0 else {
                sendResponse(clientSocket: clientSocket, status: 400, body: "Incomplete request body")
                return
            }
            body.append(buffer, count: n)
        }
        processRoute(method: method, path: path, body: body, clientSocket: clientSocket)
    }

    private func secretsMatch(_ provided: String) -> Bool {
        // Compare fixed-length digests without early exit.
        let a = Array(TossSecurityUtils.sha256Hex(of: provided).utf8)
        let b = Array(TossSecurityUtils.sha256Hex(of: pairingSecret).utf8)
        var difference: UInt8 = 0
        for i in a.indices { difference |= a[i] ^ b[i] }
        return difference == 0
    }

    private func issueSession() -> String? {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        let now = Date()
        validSessionTokens = validSessionTokens.filter { $0.value > now }
        guard validSessionTokens.count < 1024 else { return nil }
        let token = UUID().uuidString.lowercased()
        validSessionTokens[token] = now.addingTimeInterval(sessionLifetime)
        return token
    }

    private func validSession(_ token: String) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard let expiration = validSessionTokens[token], expiration > Date() else {
            validSessionTokens.removeValue(forKey: token)
            return false
        }
        return true
    }

    private func processRoute(method: String, path: String, body: Data, clientSocket: Int32) {
        switch (method, path) {
        case ("GET", "/health"):
            let responseObj: [String: Any] = [
                "status": "healthy",
                "receiver": receiverName,
                "version": TossHandoff.currentSchemaVersion
            ]
            sendJSONResponse(clientSocket: clientSocket, status: 200, object: responseObj)

        case ("POST", TossSecureTransport.pairPath), ("POST", TossSecureTransport.transferPath):
            handleSecureRoute(path: path, body: body, clientSocket: clientSocket)

        // Legacy raw protocol is limited to explicit loopback developer tests.
        case ("POST", "/pair") where host == "127.0.0.1":
            handlePairing(body: body, clientSocket: clientSocket)

        case ("POST", "/transfer") where host == "127.0.0.1":
            handleTransfer(body: body, clientSocket: clientSocket)

        default:
            sendResponse(clientSocket: clientSocket, status: 404, body: "Not Found")
        }
    }

    private struct SecureReply {
        let path: String
        let request: Data
    }

    private func acceptPairingRequest(_ request: Data) -> Bool {
        let fingerprint = TossSecurityUtils.sha256Hex(of: request)
        replayLock.lock(); defer { replayLock.unlock() }
        let now = Date()
        pairingRequests = pairingRequests.filter { $0.value > now }
        guard pairingRequests[fingerprint] == nil, pairingRequests.count < 4096 else { return false }
        // A request can be timestamped 120 seconds in the future.
        pairingRequests[fingerprint] = now.addingTimeInterval(241)
        return true
    }

    private func handleSecureRoute(path: String, body: Data, clientSocket: Int32) {
        do {
            let decoded = try TossSecureTransport.openRequest(body, secret: pairingSecret, path: path)
            let reply = SecureReply(path: path, request: body)
            if path == TossSecureTransport.pairPath {
                guard acceptPairingRequest(body) else {
                    sendResponse(clientSocket: clientSocket, status: 409, body: "Duplicate pairing request")
                    return
                }
                handlePairing(body: decoded, clientSocket: clientSocket, secure: reply)
            } else {
                handleTransfer(body: decoded, clientSocket: clientSocket, secure: reply)
            }
        } catch {
            sendResponse(clientSocket: clientSocket, status: 401, body: "Secure request rejected")
        }
    }

    private func handlePairing(body: Data, clientSocket: Int32, secure: SecureReply? = nil) {
        do {
            let decoder = JSONDecoder()
            let req = try decoder.decode(PairingRequest.self, from: body)
            if secretsMatch(req.pairingSecret) {
                guard let sessionToken = issueSession() else {
                    sendResponse(clientSocket: clientSocket, status: 503, body: "Session capacity reached", secure: secure)
                    return
                }
                let resp = PairingResponse(accepted: true, token: sessionToken, receiverName: receiverName, message: "Paired successfully")
                let respData = try JSONEncoder().encode(resp)
                sendDataResponse(clientSocket: clientSocket, status: 200, contentType: "application/json", data: respData, secure: secure)
                print("[TOSS Receiver] Device paired: \(req.deviceName) (\(req.deviceId))")
            } else {
                let resp = PairingResponse(accepted: false, receiverName: receiverName, message: "Invalid pairing secret")
                let respData = try JSONEncoder().encode(resp)
                sendDataResponse(clientSocket: clientSocket, status: 401, contentType: "application/json", data: respData, secure: secure)
            }
        } catch {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid pairing request payload: \(error.localizedDescription)", secure: secure)
        }
    }

    private func handleTransfer(body: Data, clientSocket: Int32, secure: SecureReply? = nil) {
        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(TransferPayload.self, from: body)

            // Validate session token
            guard validSession(payload.authToken) else {
                sendResponse(clientSocket: clientSocket, status: 401, body: "Unauthorized: Invalid or expired session token", secure: secure)
                return
            }

            // Validate JSON against Schema
            guard let jsonData = payload.jsonContent.data(using: .utf8) else {
                sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid JSON encoding", secure: secure)
                return
            }
            let handoff = try TossHandoff.fromJSONData(jsonData)

            guard handoff.schemaVersion == TossHandoff.currentSchemaVersion,
                  payload.manifest.schemaVersion == handoff.schemaVersion,
                  payload.manifest.handoffId == handoff.handoffId,
                  payload.manifest.title == handoff.title,
                  UUID(uuidString: handoff.handoffId) != nil,
                  UUID(uuidString: handoff.projectId) != nil,
                  payload.manifest.files.count == 2,
                  Set(payload.manifest.files.map(\.filename)) == Set(["handoff.json", "handoff.md"]) else {
                sendResponse(clientSocket: clientSocket, status: 422, body: "Invalid transfer manifest", secure: secure)
                return
            }
            // Check manifest checksums and sizes
            for fileItem in payload.manifest.files {
                let expected = fileItem.checksumSha256
                if fileItem.filename == "handoff.json" {
                    let actual = TossSecurityUtils.sha256Hex(of: payload.jsonContent)
                    if actual != expected || fileItem.sizeBytes != jsonData.count {
                        sendResponse(clientSocket: clientSocket, status: 422, body: "Checksum mismatch for handoff.json", secure: secure)
                        return
                    }
                } else if fileItem.filename == "handoff.md" {
                    let actual = TossSecurityUtils.sha256Hex(of: payload.markdownContent)
                    if actual != expected || fileItem.sizeBytes != payload.markdownContent.utf8.count {
                        sendResponse(clientSocket: clientSocket, status: 422, body: "Checksum mismatch for handoff.md", secure: secure)
                        return
                    }
                }
            }

            // Sanitize folder name
            let safeTitle = TossSecurityUtils.sanitizeFilename(handoff.title)
            let safeDate = TossSecurityUtils.sanitizeFilename(String(handoff.createdAt.prefix(10)))
            let revisionSuffix = handoff.revision > 1 ? "_r\(handoff.revision)" : ""
            let folderName = "\(safeDate)_\(safeTitle)_\(handoff.handoffId.prefix(8))\(revisionSuffix)"
            let targetDir = storageDirectory.appendingPathComponent(folderName, isDirectory: true)

            transferLock.lock()
            defer { transferLock.unlock() }
            let fm = FileManager.default
            if let attrs = try? fm.attributesOfItem(atPath: targetDir.path), attrs[.type] as? FileAttributeType != .typeDirectory {
                sendResponse(clientSocket: clientSocket, status: 422, body: "Unsafe destination", secure: secure)
                return
            }
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            guard targetDir.resolvingSymlinksInPath().deletingLastPathComponent().path == storageDirectory.resolvingSymlinksInPath().path else {
                sendResponse(clientSocket: clientSocket, status: 422, body: "Unsafe destination", secure: secure)
                return
            }

            let jsonURL = targetDir.appendingPathComponent("handoff.json")
            let mdURL = targetDir.appendingPathComponent("handoff.md")
            let receiptURL = targetDir.appendingPathComponent("receipt.json")
            let textURL = targetDir.appendingPathComponent("handoff.txt")

            for url in [jsonURL, mdURL, textURL, receiptURL] {
                if let attrs = try? fm.attributesOfItem(atPath: url.path), attrs[.type] as? FileAttributeType != .typeRegular {
                    sendResponse(clientSocket: clientSocket, status: 422, body: "Unsafe destination file", secure: secure)
                    return
                }
            }
            if fm.fileExists(atPath: receiptURL.path) {
                guard var oldReceipt = try? JSONDecoder().decode(TransferAck.self, from: Data(contentsOf: receiptURL)),
                      oldReceipt.handoffId == handoff.handoffId,
                      (try? Data(contentsOf: jsonURL)) == jsonData,
                      (try? Data(contentsOf: mdURL)) == Data(payload.markdownContent.utf8) else {
                    sendResponse(clientSocket: clientSocket, status: 409, body: "Existing receipt conflicts with payload", secure: secure)
                    return
                }
                let textData = Data(handoff.toPlainText().utf8)
                if fm.fileExists(atPath: textURL.path) {
                    guard (try? Data(contentsOf: textURL)) == textData else {
                        sendResponse(clientSocket: clientSocket, status: 409, body: "Existing plain text conflicts with payload", secure: secure)
                        return
                    }
                } else {
                    try textData.write(to: textURL, options: .atomic)
                }
                if !oldReceipt.receivedFiles.contains("handoff.txt") {
                    oldReceipt.receivedFiles.append("handoff.txt")
                    try JSONEncoder().encode(oldReceipt).write(to: receiptURL, options: .atomic)
                }
                sendDataResponse(clientSocket: clientSocket, status: 200, contentType: "application/json", data: try JSONEncoder().encode(oldReceipt), secure: secure)
                return
            }
            try payload.jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)
            try payload.markdownContent.write(to: mdURL, atomically: true, encoding: .utf8)
            try handoff.toPlainText().write(to: textURL, atomically: true, encoding: .utf8)

            let ack = TransferAck(
                handoffId: handoff.handoffId,
                accepted: true,
                receivedFiles: ["handoff.json", "handoff.md", "handoff.txt"],
                savedToDirectory: targetDir.path,
                message: "Handoff successfully received, verified, and saved."
            )

            let ackData = try JSONEncoder().encode(ack)
            try ackData.write(to: receiptURL, options: .atomic)

            print("[TOSS Receiver] Successfully received handoff '\(handoff.title)' to \(targetDir.path)")
            sendDataResponse(clientSocket: clientSocket, status: 200, contentType: "application/json", data: ackData, secure: secure)

        } catch {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Transfer processing failed: \(error.localizedDescription)", secure: secure)
        }
    }

    private func sendResponse(clientSocket: Int32, status: Int, body: String, secure: SecureReply? = nil) {
        let data = body.data(using: .utf8) ?? Data()
        sendDataResponse(clientSocket: clientSocket, status: status, contentType: "text/plain", data: data, secure: secure)
    }

    private func sendJSONResponse(clientSocket: Int32, status: Int, object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
            sendDataResponse(clientSocket: clientSocket, status: status, contentType: "application/json", data: data)
        } else {
            sendResponse(clientSocket: clientSocket, status: 500, body: "JSON serialization failed")
        }
    }

    private func sendDataResponse(clientSocket: Int32, status: Int, contentType: String, data: Data, secure: SecureReply? = nil) {
        if let secure = secure {
            guard let sealed = try? TossSecureTransport.sealResponse(data, secret: pairingSecret,
                path: secure.path, request: secure.request, status: status) else { return }
            sendDataResponse(clientSocket: clientSocket, status: status, contentType: TossSecureTransport.contentType, data: sealed)
            return
        }
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 408: statusText = "Request Timeout"
        case 409: statusText = "Conflict"
        case 411: statusText = "Length Required"
        case 413: statusText = "Payload Too Large"
        case 431: statusText = "Request Header Fields Too Large"
        case 503: statusText = "Service Unavailable"
        case 422: statusText = "Unprocessable Entity"
        default: statusText = "Server Error"
        }

        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(data.count)\r\n"
        header += "Connection: close\r\n\r\n"

        var response = Data(header.utf8)
        response.append(data)
        response.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                #if canImport(Darwin)
                let n = send(clientSocket, base.advanced(by: offset), bytes.count - offset, 0)
                #else
                let n = send(clientSocket, base.advanced(by: offset), bytes.count - offset, Int32(MSG_NOSIGNAL))
                #endif
                guard n > 0 else { return }
                offset += n
            }
        }
    }
}

public enum ReceiverError: Error {
    case socketFailed(String)
    case bindFailed(String)
    case listenFailed(String)
}
