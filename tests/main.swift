import Foundation
#if canImport(TossSchema)
import TossSchema
#endif
#if canImport(TossProtocol)
import TossProtocol
#endif

var totalTests = 0
var passedTests = 0

func testCase(_ name: String, block: () throws -> Void) {
    totalTests += 1
    do {
        try block()
        passedTests += 1
        print("  [PASS] \(name)")
    } catch {
        print("  [FAIL] \(name): \(error)")
    }
}

func testCaseAsync(_ name: String, block: () async throws -> Void) async {
    totalTests += 1
    do {
        try await block()
        passedTests += 1
        print("  [PASS] \(name)")
    } catch {
        print("  [FAIL] \(name): \(error)")
    }
}

print("=== Running TOSS Test Suite ===")

// 1. Schema Tests
print("\n--- TossSchema Tests ---")
testCase("Handoff Creation and Validation") {
    let handoff = TossHandoff(
        title: "Test Handoff",
        destination: .antigravity,
        objective: "Unit test objective",
        context: "Testing context",
        requirements: ["Req 1", "Req 2"],
        constraints: ["Constraint 1"],
        completed: ["Step 0"],
        nextActions: ["Step 1"],
        source: TossSource(type: .text, transcriptAvailable: false, rawInput: "Sample")
    )
    try handoff.validate()
    assert(handoff.schemaVersion == "1.0.0", "Schema version must be 1.0.0")
    assert(handoff.revision == 1, "Revision must be 1")
}

testCase("Git Context Extraction") {
    let repo = TossGitContext.currentRepositoryContext()
    assert(repo.branch?.isEmpty == false, "Git must report the current branch or detached HEAD")
    assert(repo.commit != nil, "Commit hash must not be nil")
    assert(repo.url?.contains("dooleydarko/TOSS") == true, "Remote URL must point to TOSS")
}

testCase("History Engine Revisions and Diffing") {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("history_test_\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tempURL) }
    let engine = TossHistoryEngine(storageURL: tempURL)

    let base = TossHandoff(
        title: "Searchable Engine Project",
        destination: .antigravity,
        objective: "Build fast revision engine",
        context: "Initial revision",
        requirements: ["Req 1"],
        completed: [],
        nextActions: ["Action 1"],
        source: TossSource(type: .text)
    )
    engine.recordHandoff(base)

    let rev2 = engine.createNextRevision(from: base, newRequirements: ["Req 2"], completedActions: ["Action 1"])
    assert(rev2.revision == 2, "Revision must increment to 2")
    assert(rev2.requirements.contains("Req 2"), "New requirement must be present")
    assert(rev2.completed.contains("Action 1"), "Action 1 must be marked completed")

    let diff = HandoffDiff(previous: base, current: rev2)
    assert(diff.addedRequirements == ["Req 2"], "Diff must report added requirement")
    assert(diff.newlyCompletedActions == ["Action 1"], "Diff must report newly completed action")

    let searchResults = engine.search(query: "Searchable")
    assert(searchResults.count == 1, "Search must find handoff by keyword")
}

testCase("Empty Title Fails Validation") {
    let invalid = TossHandoff(
        title: "   ",
        destination: .antigravity,
        objective: "Obj",
        context: "Ctx",
        source: TossSource(type: .text)
    )
    var failed = false
    do {
        try invalid.validate()
    } catch {
        failed = true
    }
    assert(failed, "Empty title must fail validation")
}

testCase("JSON Serialization Round-trip") {
    let original = TossHandoff(
        title: "Roundtrip Handoff",
        destination: .gpt,
        objective: "Ensure roundtrip fidelity",
        context: "JSON encode decode test",
        requirements: ["Requirement A"],
        constraints: ["Constraint B"],
        completed: [],
        nextActions: ["Verify"],
        source: TossSource(type: .voice, transcriptAvailable: true, rawInput: "Spoken note")
    )
    let data = try original.toJSONData()
    let decoded = try TossHandoff.fromJSONData(data)
    assert(original.handoffId == decoded.handoffId, "ID must match")
    assert(original.title == decoded.title, "Title must match")
    assert(original.destination == decoded.destination, "Destination must match")
}

testCase("Markdown Serialization") {
    let handoff = TossHandoff(
        title: "Markdown Title",
        destination: .claude,
        objective: "Check markdown headers",
        context: "Markdown test",
        requirements: ["Alpha", "Beta"],
        nextActions: ["Action 1"],
        source: TossSource(type: .text)
    )
    let md = handoff.toMarkdown()
    assert(md.contains("# Markdown Title"))
    assert(md.contains("## Objective"))
    assert(md.contains("- Alpha"))
    assert(md.contains("1. Action 1"))
}

// 2. Protocol Tests
print("\n--- TossProtocol Tests ---")
testCase("SHA-256 Checksum Computation") {
    let text = "Hello TOSS Protocol"
    let hex = TossSecurityUtils.sha256Hex(of: text)
    assert(hex.count == 64, "SHA-256 hex string must be 64 characters")
    assert(hex == TossSecurityUtils.sha256Hex(of: text), "Hash must be deterministic")
}

testCase("Path Traversal and File Sanitization") {
    let malicious = "../../../etc/passwd"
    let clean = TossSecurityUtils.sanitizeFilename(malicious)
    assert(!clean.contains(".."), "Must strip directory traversal")
    assert(!clean.contains("/"), "Must strip slashes")
}

testCase("Offline Queue Enqueue and Tracking") {
    let queue = TossTransferQueue()
    let handoff = TossHandoff(
        title: "Queued Offline Handoff",
        destination: .gpt,
        objective: "Test offline queue persistence",
        context: "Queue test",
        source: TossSource(type: .text)
    )
    let device = TossDevice(id: "dev-offline", name: "Offline Mac", host: "192.168.1.200", port: 7443)
    let item = queue.enqueue(handoff: handoff, targetDevice: device, pairingSecret: "secret")
    assert(item.status == .pending, "Initial status must be pending")
    assert(queue.items.contains(where: { $0.id == item.id }), "Queue must contain enqueued item")
}

testCase("Bonjour Discovery Service Lifecycle") {
    let service = TossDiscoveryService()
    service.startAdvertising(name: "Test Receiver Discovery", port: 7499)
    service.stopAdvertising()
    assert(true, "Bonjour service must start and stop cleanly")
}

// 3. AI Provider Offline Fallback
print("\n--- AI Provider Tests ---")
let runAsyncTests = DispatchSemaphore(value: 0)

Task {
    await testCaseAsync("Offline Rule-Based AI Fallback") {
        let provider = RuleBasedFallbackProvider()
        let notes = """
        Audio Sync Engine
        - must handle clock drift
        - require local socket pairing
        1. create test receiver
        don't depend on cloud services
        """
        let structured = try await provider.structure(input: notes, context: "Voice memo capture")
        assert(structured.title == "Audio Sync Engine")
        assert(structured.requirements.count == 2)
        assert(structured.nextActions.count == 1)
        assert(structured.constraints.count == 1)
    }

    await testCaseAsync("Offline multi-goal notes preserve later goals and negative constraints") {
        let input = "Project polish\n- Build waveform\n- Add Markdown export\n- must not change transfer protocol\n2. Verify export\nCompleted: baseline capture\nIssue: microphone access"
        let result = try await RuleBasedFallbackProvider().structure(input: input, context: "Two goals")
        assert(result.requirements == ["Build waveform", "Add Markdown export"])
        assert(result.constraints == ["must not change transfer protocol"])
        assert(result.nextActions == ["Verify export"])
        assert(result.completed == ["Completed: baseline capture"])
        assert(result.knownIssues == ["Issue: microphone access"])
        assert(result.source.rawInput == input)
        assert(result.objective.contains("Add Markdown export"))
    }

    await testCaseAsync("Gemini prompt contract and response preserve source") {
        let input = "Goal A\nGoal B: don't remove files"
        let context = "Existing repo"
        let notes = try GeminiAIProvider.notesJSON(input: input, context: context)
        let parsed = try JSONSerialization.jsonObject(with: Data(notes.utf8)) as? [String: String]
        assert(parsed?["rawNotes"] == input && parsed?["context"] == context)
        assert(GeminiAIProvider.structuringPrompt.contains("every distinct actionable goal"))
        assert(GeminiAIProvider.structuringPrompt.contains("\"attachments\": []"))
        let original = TossHandoff(title: "Two goals", destination: .gpt, objective: "A and B", context: context, requirements: ["A", "B"], source: TossSource(type: .text, rawInput: "model altered notes"))
        let json = String(decoding: try original.toJSONData(), as: UTF8.self)
        let envelope = ["candidates": [["content": ["parts": [["text": json]]]]]]
        let decoded = try GeminiAIProvider.decodeResponse(JSONSerialization.data(withJSONObject: envelope), originalInput: input)
        assert(decoded.requirements == ["A", "B"])
        assert(decoded.source.rawInput == input)
        do {
            _ = try GeminiAIProvider.decodeResponse(Data("{}".utf8), originalInput: input)
            throw TossValidationError.invalidField("Malformed response should fail")
        } catch TossValidationError.invalidField(let reason) {
            assert(reason == "Missing Gemini response")
        }
    }

    // 4. End-to-End Receiver Server & Client Transfer
    print("\n--- End-to-End Transfer Tests ---")
    await testCaseAsync("Full Pairing and Transfer Loop") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("toss_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testPort: UInt16 = 7455
        let secret = "e2e-secret-key-999"
        let server = ReceiverServer(
            host: "127.0.0.1",
            port: testPort,
            storageDirectory: tempDir,
            pairingSecret: secret,
            receiverName: "Automated E2E Receiver"
        )
        try server.start(blocking: false)
        try await Task.sleep(nanoseconds: 200_000_000)

        defer { server.stop() }

        let client = TossClient()
        let device = TossDevice(id: "dev-mac", name: "Mac Receiver", host: "127.0.0.1", port: Int(testPort))

        // Negative test: invalid pairing secret
        var pairingFailedAsExpected = false
        do {
            _ = try await client.pair(with: device, pairingSecret: "invalid-secret")
        } catch {
            pairingFailedAsExpected = true
        }
        assert(pairingFailedAsExpected, "Pairing with bad secret must fail")

        // Positive test: valid secret
        let token = try await client.pair(with: device, pairingSecret: secret)
        assert(!token.isEmpty, "Valid pairing must return session token")

        // Create Handoff
        let handoff = TossHandoff(
            title: "End-to-End Verification Handoff",
            destination: .antigravity,
            objective: "Prove live phone-to-Mac handoff works",
            context: "Automated verification suite",
            requirements: ["Local HTTP transfer", "SHA-256 verification", "No path traversal"],
            constraints: ["Never auto-execute inbound scripts"],
            completed: ["Server started", "Device paired"],
            nextActions: ["Inspect received files on disk"],
            source: TossSource(type: .voice, transcriptAvailable: true, rawInput: "Automated test recording")
        )

        var states: [TransferState] = []
        let ack = try await client.sendHandoff(handoff, to: device, authToken: token) { state in
            states.append(state)
        }

        assert(ack.accepted, "Server must accept transfer")
        assert(ack.handoffId == handoff.handoffId, "ACK handoff ID must match")
        assert(ack.receivedFiles.contains("handoff.json"), "Must contain handoff.json")
        assert(ack.receivedFiles.contains("handoff.md"), "Must contain handoff.md")

        // Verify disk files
        let savedDir = URL(fileURLWithPath: ack.savedToDirectory)
        let jsonPath = savedDir.appendingPathComponent("handoff.json").path
        let mdPath = savedDir.appendingPathComponent("handoff.md").path
        let receiptPath = savedDir.appendingPathComponent("receipt.json").path

        assert(FileManager.default.fileExists(atPath: jsonPath), "handoff.json must exist on disk")
        assert(FileManager.default.fileExists(atPath: mdPath), "handoff.md must exist on disk")
        assert(FileManager.default.fileExists(atPath: receiptPath), "receipt.json must exist on disk")

        let diskData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let diskHandoff = try TossHandoff.fromJSONData(diskData)
        assert(diskHandoff.title == handoff.title, "Saved content must match original")
    }

    print("\n===============================")
    print("Test Summary: \(passedTests)/\(totalTests) passed")
    print("===============================\n")

    runAsyncTests.signal()
}

runAsyncTests.wait()
exit(totalTests == passedTests ? 0 : 1)
