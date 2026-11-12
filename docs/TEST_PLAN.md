# TOSS Test Plan & Verification Matrix

## Overview
Every functional milestone in TOSS is accompanied by repeatable tests. We do not claim features work without executable evidence.

---

## 1. Automated Test Suites

### Suite A: Schema & Serialization (`TossSchemaTests`)
- **Handoff Creation & Validation:** Verifies required fields (`schemaVersion`, `handoffId`, `projectId`, `title`, `revision`).
- **Negative Validation:** Ensures empty titles or invalid revisions throw appropriate validation errors.
- **Roundtrip Serialization:** Encodes `TossHandoff` to JSON and validates deep equality after decoding.
- **Markdown Export:** Validates formatting of headers, checklists, and quote blocks.

### Suite B: Protocol & Cryptography (`TossProtocolTests`)
- **Checksum Calculation:** Validates deterministic SHA-256 computation over payloads.
- **Path Sanitization:** Confirms malicious inputs (`../../etc/passwd`, null bytes, slashes) are neutralized to prevent directory traversal attacks.

### Suite C: AI Structuring Providers (`AIProviderTests`)
- **Offline Fallback:** Validates that unstructured user notes are correctly parsed into requirements, constraints, and actions without network connectivity or API keys.

### Suite D: End-to-End Transfer (`TossEndToEndTests`)
- **Server Initialization:** Spawns `ReceiverServer` on a test port.
- **Device Pairing:** Validates that unauthorized pairing requests are rejected (401) and valid secrets yield a session token.
- **Payload Transmission:** Validates transfer of `handoff.json` and `handoff.md` with SHA-256 manifest matching.
- **Storage Verification:** Validates physical creation and content accuracy of `handoff.json`, `handoff.md`, and `receipt.json` in the target directory.

---

## 2. Running Tests

```bash
# Compile and run test runner
swiftc \
  packages/handoff-schema/Sources/TossHandoff.swift \
  packages/handoff-schema/Sources/AIProvider.swift \
  packages/transfer-protocol/Sources/TossProtocol.swift \
  packages/transfer-protocol/Sources/TossClient.swift \
  apps/macos-receiver/Sources/ReceiverServer.swift \
  tests/main.swift \
  -o bin/toss-test-runner

./bin/toss-test-runner
```

## 0.1.3 acceptance additions
- Export all formats from iPhone review; compare to same revision on Mac, including UTF-8 and original notes. Replay a pre-text receipt and confirm receipt ID survives.
- Pair on actual Wi-Fi; verify code is required, saved in Keychain, and not granted by Bonjour. Restart receiver, re-pair, retry failed queue with replacement code; forget receiver and verify pending sends are removed while delivered history remains.
- Confirm UI in dark/light/system and microphone permission denied/granted paths. No automatic handoff execution.
