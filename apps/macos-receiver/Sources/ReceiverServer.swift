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

    private var validSessionTokens: Set<String> = []
    private var serverSocket: Int32 = -1
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "com.toss.receiver.server", attributes: .concurrent)

    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 7443,
        storageDirectory: URL,
        pairingSecret: String = "toss-dev-secret-change-in-production",
        receiverName: String = Host.current().localizedName ?? "Mac Receiver"
    ) {
        self.host = host
        self.port = port
        self.storageDirectory = storageDirectory
        self.pairingSecret = pairingSecret
        self.receiverName = receiverName
    }

    public func start(blocking: Bool = false) throws {
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
        inet_pton(AF_INET, host, &addr.sin_addr)

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

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientSocket: clientSocket)
            }
        }
    }

    private func handleClient(clientSocket: Int32) {
        defer { close(clientSocket) }

        var buffer = [UInt8](repeating: 0, count: 65536)
        var receivedData = Data()

        // Read initial header chunk
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else { return }
        receivedData.append(buffer, count: bytesRead)

        // Find header boundary \r\n\r\n
        let boundary = "\r\n\r\n".data(using: .utf8)!
        while !receivedData.contains(boundary) && isRunning {
            let nextRead = read(clientSocket, &buffer, buffer.count)
            guard nextRead > 0 else { break }
            receivedData.append(buffer, count: nextRead)
        }

        guard let range = receivedData.range(of: boundary) else {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Bad Request: Malformed HTTP")
            return
        }

        let headerData = receivedData.subdata(in: 0..<range.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Bad Request: Invalid encoding")
            return
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let reqParts = requestLine.components(separatedBy: " ")
        guard reqParts.count >= 2 else { return }
        let method = reqParts[0].uppercased()
        let path = reqParts[1]

        var contentLength = 0
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            }
        }

        var bodyData = receivedData.subdata(in: range.upperBound..<receivedData.count)
        while bodyData.count < contentLength {
            let nextRead = read(clientSocket, &buffer, buffer.count)
            guard nextRead > 0 else { break }
            bodyData.append(buffer, count: nextRead)
        }

        processRoute(method: method, path: path, body: bodyData, clientSocket: clientSocket)
    }

    private func processRoute(method: String, path: String, body: Data, clientSocket: Int32) {
        switch (method, path) {
        case ("GET", "/health"):
            let responseObj: [String: Any] = [
                "status": "healthy",
                "receiver": receiverName,
                "version": TossHandoff.currentSchemaVersion,
                "storagePath": storageDirectory.path
            ]
            sendJSONResponse(clientSocket: clientSocket, status: 200, object: responseObj)

        case ("POST", "/pair"):
            handlePairing(body: body, clientSocket: clientSocket)

        case ("POST", "/transfer"):
            handleTransfer(body: body, clientSocket: clientSocket)

        default:
            sendResponse(clientSocket: clientSocket, status: 404, body: "Not Found")
        }
    }

    private func handlePairing(body: Data, clientSocket: Int32) {
        do {
            let decoder = JSONDecoder()
            let req = try decoder.decode(PairingRequest.self, from: body)
            if req.pairingSecret == self.pairingSecret {
                let sessionToken = UUID().uuidString.lowercased()
                validSessionTokens.insert(sessionToken)
                let resp = PairingResponse(accepted: true, token: sessionToken, receiverName: receiverName, message: "Paired successfully")
                let respData = try JSONEncoder().encode(resp)
                sendDataResponse(clientSocket: clientSocket, status: 200, contentType: "application/json", data: respData)
                print("[TOSS Receiver] Device paired: \(req.deviceName) (\(req.deviceId))")
            } else {
                let resp = PairingResponse(accepted: false, receiverName: receiverName, message: "Invalid pairing secret")
                let respData = try JSONEncoder().encode(resp)
                sendDataResponse(clientSocket: clientSocket, status: 401, contentType: "application/json", data: respData)
            }
        } catch {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid pairing request payload: \(error.localizedDescription)")
        }
    }

    private func handleTransfer(body: Data, clientSocket: Int32) {
        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(TransferPayload.self, from: body)

            // Validate session token
            guard validSessionTokens.contains(payload.authToken) else {
                sendResponse(clientSocket: clientSocket, status: 401, body: "Unauthorized: Invalid or expired session token")
                return
            }

            // Validate JSON against Schema
            guard let jsonData = payload.jsonContent.data(using: .utf8) else {
                sendResponse(clientSocket: clientSocket, status: 400, body: "Invalid JSON encoding")
                return
            }
            let handoff = try TossHandoff.fromJSONData(jsonData)

            // Check manifest checksums
            for fileItem in payload.manifest.files {
                let expected = fileItem.checksumSha256
                if fileItem.filename == "handoff.json" {
                    let actual = TossSecurityUtils.sha256Hex(of: payload.jsonContent)
                    if actual != expected {
                        sendResponse(clientSocket: clientSocket, status: 422, body: "Checksum mismatch for handoff.json")
                        return
                    }
                } else if fileItem.filename == "handoff.md" {
                    let actual = TossSecurityUtils.sha256Hex(of: payload.markdownContent)
                    if actual != expected {
                        sendResponse(clientSocket: clientSocket, status: 422, body: "Checksum mismatch for handoff.md")
                        return
                    }
                }
            }

            // Sanitize folder name
            let safeTitle = TossSecurityUtils.sanitizeFilename(handoff.title)
            let folderName = "\(handoff.createdAt.prefix(10))_\(safeTitle)_\(handoff.handoffId.prefix(8))"
            let targetDir = storageDirectory.appendingPathComponent(folderName, isDirectory: true)

            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

            let jsonURL = targetDir.appendingPathComponent("handoff.json")
            let mdURL = targetDir.appendingPathComponent("handoff.md")
            let receiptURL = targetDir.appendingPathComponent("receipt.json")

            try payload.jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)
            try payload.markdownContent.write(to: mdURL, atomically: true, encoding: .utf8)

            let ack = TransferAck(
                handoffId: handoff.handoffId,
                accepted: true,
                receivedFiles: ["handoff.json", "handoff.md"],
                savedToDirectory: targetDir.path,
                message: "Handoff successfully received, verified, and saved."
            )

            let ackData = try JSONEncoder().encode(ack)
            try ackData.write(to: receiptURL)

            print("[TOSS Receiver] Successfully received handoff '\(handoff.title)' to \(targetDir.path)")
            sendDataResponse(clientSocket: clientSocket, status: 200, contentType: "application/json", data: ackData)

        } catch {
            sendResponse(clientSocket: clientSocket, status: 400, body: "Transfer processing failed: \(error.localizedDescription)")
        }
    }

    private func sendResponse(clientSocket: Int32, status: Int, body: String) {
        let data = body.data(using: .utf8) ?? Data()
        sendDataResponse(clientSocket: clientSocket, status: status, contentType: "text/plain", data: data)
    }

    private func sendJSONResponse(clientSocket: Int32, status: Int, object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
            sendDataResponse(clientSocket: clientSocket, status: status, contentType: "application/json", data: data)
        } else {
            sendResponse(clientSocket: clientSocket, status: 500, body: "JSON serialization failed")
        }
    }

    private func sendDataResponse(clientSocket: Int32, status: Int, contentType: String, data: Data) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 422: statusText = "Unprocessable Entity"
        default: statusText = "Server Error"
        }

        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(data.count)\r\n"
        header += "Connection: close\r\n\r\n"

        if let headerData = header.data(using: .utf8) {
            _ = headerData.withUnsafeBytes { write(clientSocket, $0.baseAddress, headerData.count) }
        }
        _ = data.withUnsafeBytes { write(clientSocket, $0.baseAddress, data.count) }
    }
}

public enum ReceiverError: Error {
    case socketFailed(String)
    case bindFailed(String)
    case listenFailed(String)
}
