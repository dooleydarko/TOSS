import XCTest
@testable import TossSchema
@testable import TossProtocol
@testable import TossReceiver

final class TossEndToEndTests: XCTestCase {
    var tempDir: URL!
    var server: ReceiverServer!
    let testPort: UInt16 = 7449
    let testSecret = "unit-test-secret-123"

    override func setUpWithError() throws {
        let unique = UUID().uuidString
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("toss_test_\(unique)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        server = ReceiverServer(
            host: "127.0.0.1",
            port: testPort,
            storageDirectory: tempDir,
            pairingSecret: testSecret,
            receiverName: "Test Mac Receiver"
        )
        try server.start(blocking: false)
        Thread.sleep(forTimeInterval: 0.2)
    }

    override func tearDownWithError() throws {
        server.stop()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCompletePairAndTransferLoop() async throws {
        let client = TossClient()
        let device = TossDevice(id: "dev-1", name: "Test Receiver", host: "127.0.0.1", port: Int(testPort))

        // 1. Test pairing with invalid secret fails
        do {
            _ = try await client.pair(with: device, pairingSecret: "wrong-secret")
            XCTFail("Pairing with invalid secret should have failed")
        } catch {
            // Expected
        }

        // 2. Test pairing with valid secret succeeds
        let token = try await client.pair(with: device, pairingSecret: testSecret)
        XCTAssertFalse(token.isEmpty)

        // 3. Create handoff
        let handoff = TossHandoff(
            title: "Automated Integration Test Handoff",
            destination: .antigravity,
            objective: "Verify end-to-end phone to Mac transfer pipeline",
            context: "Integration test run",
            requirements: ["TCP Socket transport", "SHA-256 verification", "Safe directory write"],
            constraints: ["No path traversal", "Strict schema enforcement"],
            completed: ["Server initialized", "Client paired"],
            nextActions: ["Verify receipt on disk"],
            source: TossSource(type: .text, transcriptAvailable: false, rawInput: "Run E2E test")
        )

        // 4. Send handoff
        var reportedStates: [TransferState] = []
        let ack = try await client.sendHandoff(handoff, to: device, authToken: token) { state in
            reportedStates.append(state)
        }

        // 5. Verify ACK
        XCTAssertTrue(ack.accepted)
        XCTAssertEqual(ack.handoffId, handoff.handoffId)
        XCTAssertTrue(ack.receivedFiles.contains("handoff.json"))
        XCTAssertTrue(ack.receivedFiles.contains("handoff.md"))

        // 6. Verify files on disk
        let savedDirURL = URL(fileURLWithPath: ack.savedToDirectory)
        let jsonFileURL = savedDirURL.appendingPathComponent("handoff.json")
        let mdFileURL = savedDirURL.appendingPathComponent("handoff.md")
        let receiptFileURL = savedDirURL.appendingPathComponent("receipt.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mdFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: receiptFileURL.path))

        // 7. Verify file contents
        let savedData = try Data(contentsOf: jsonFileURL)
        let parsed = try TossHandoff.fromJSONData(savedData)
        XCTAssertEqual(parsed.title, handoff.title)
        XCTAssertEqual(parsed.handoffId, handoff.handoffId)
    }
}
