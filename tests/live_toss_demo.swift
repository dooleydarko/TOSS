import Foundation
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

@main
struct LiveTossDemo {
    static func main() async throws {
        print("1. Initializing TOSS client...")
        let client = TossClient()
        let device = TossDevice(
            id: "local-mac",
            name: "ABCD’s MacBook Pro",
            host: "127.0.0.1",
            port: 7443
        )

        print("2. Pairing with Mac receiver at \(device.host):\(device.port)...")
        let secret = "toss-dev-secret-change-in-production"
        let token = try await client.pair(with: device, pairingSecret: secret)
        print("   ✓ Secure pairing successful!")

        print("3. Preparing structured handoff package...")
        let handoff = TossHandoff(
            title: "TOSS Live Demo — Voice to Code Pipeline",
            destination: .antigravity,
            objective: "Demonstrate live end-to-end handoff transfer to macOS receiver",
            context: "Live interactive test performed in Antigravity session.",
            requirements: [
                "Capture raw notes from iPhone interface",
                "Structure automatically into schema 1.0.0",
                "Stream SHA-256 verified payload over local network",
                "Generate verifiable receipt on destination Mac"
            ],
            constraints: [
                "Never execute received scripts automatically",
                "Prevent directory traversal attacks"
            ],
            completed: [
                "Receiver initialized on port 7443",
                "Pairing handshake authenticated with shared secret"
            ],
            nextActions: [
                "Inspect generated handoff.json and handoff.md in received folder",
                "Connect remote repository and transition to Phase 2"
            ],
            source: TossSource(
                type: .voice,
                transcriptAvailable: true,
                rawInput: "Let's test tossing a sample handoff to the live receiver right now!"
            )
        )

        print("4. Tossing handoff: '\(handoff.title)'...")
        let ack = try await client.sendHandoff(handoff, to: device, authToken: token) { state in
            print("   [Transfer State] -> \(state.description)")
        }

        print("\n================ RECEIPT ACKNOWLEDGEMENT ================")
        print("Receipt ID:       \(ack.receiptId)")
        print("Handoff ID:       \(ack.handoffId)")
        print("Status:           \(ack.accepted ? "ACCEPTED" : "REJECTED")")
        print("Received Files:   \(ack.receivedFiles.joined(separator: ", "))")
        print("Saved Directory:  \(ack.savedToDirectory)")
        print("Message:          \(ack.message)")
        print("=========================================================\n")
    }
}
