import Foundation
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

let args = CommandLine.arguments

var port: UInt16 = 7443
var host = "127.0.0.1"
var storageDir = FileManager.default.currentDirectoryPath + "/received"
var secret = ProcessInfo.processInfo.environment["TOSS_PAIRING_SECRET"] ?? "toss-dev-secret-change-in-production"

var i = 1
while i < args.count {
    switch args[i] {
    case "--port":
        if i + 1 < args.count, let p = UInt16(args[i + 1]) {
            port = p
            i += 1
        }
    case "--host":
        if i + 1 < args.count {
            host = args[i + 1]
            i += 1
        }
    case "--storage":
        if i + 1 < args.count {
            storageDir = args[i + 1]
            i += 1
        }
    case "--secret":
        if i + 1 < args.count {
            secret = args[i + 1]
            i += 1
        }
    default:
        break
    }
    i += 1
}

let storageURL = URL(fileURLWithPath: storageDir)
let receiverName = Host.current().localizedName ?? "Mac Receiver"
let server = ReceiverServer(
    host: host,
    port: port,
    storageDirectory: storageURL,
    pairingSecret: secret,
    receiverName: receiverName
)

let discovery = TossDiscoveryService()
discovery.startAdvertising(name: receiverName, port: Int32(port))

signal(SIGINT) { _ in
    print("\n[TOSS Receiver] Terminating on SIGINT...")
    discovery.stopAdvertising()
    exit(0)
}

do {
    try server.start(blocking: true)
} catch {
    print("[TOSS Receiver Error] \(error)")
    exit(1)
}
