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

// Network exposure is an explicit development-only decision. The current
// protocol is HTTP, not TLS; never use it on an untrusted network.
let isLAN = host != "127.0.0.1"
if isLAN && (secret == "toss-dev-secret-change-in-production" || secret.utf8.count < 16) {
    fputs("LAN mode requires a custom pairing secret of at least 16 bytes. Use TOSS_PAIRING_SECRET.\n", stderr)
    exit(2)
}
if isLAN {
    fputs("WARNING: Development LAN mode uses unencrypted HTTP. Use only a trusted private network and non-sensitive test notes.\n", stderr)
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
// Keep the main run loop alive so NetService can actually advertise.
// DispatchSource handles shutdown outside an async-signal-unsafe handler.
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
for source in [interrupt, terminate] {
    source.setEventHandler {
        discovery.stopAdvertising()
        server.stop()
        exit(0)
    }
    source.resume()
}

do {
    try server.start(blocking: false)
    if isLAN { discovery.startAdvertising(name: receiverName, port: Int32(port)) }
    RunLoop.main.run()
} catch {
    print("[TOSS Receiver Error] \(error)")
    exit(1)
}
