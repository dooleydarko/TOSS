# TOSS — AI Handoff

> Turn spoken or typed thoughts on iPhone into structured, versioned AI handoffs, and toss them directly to your paired Mac.

---

## What is TOSS?

**TOSS** is an iPhone-first application designed to capture raw ideas, structure them into standardized, versioned AI handoff packages (`.md` and `.json`), and transfer them across the local network to a lightweight receiver running on a Mac.

## Phase 1 MVP Features

- **SwiftUI iPhone App (`apps/ios`):**
  - Capture ideas via voice mock or direct text input.
  - Pluggable AI structuring (Google Gemini API with zero-cloud local fallback).
  - Review screen with multi-tab preview (Overview, Markdown, JSON Schema).
  - Toss interface with swipe gesture and accessible Send button.
  - History log storing previous handoff revisions.
  - Settings screen with destination AI picker (Antigravity, GPT, Claude, Generic).
- **macOS Receiver (`apps/macos-receiver`):**
  - Standalone POSIX HTTP socket receiver with zero third-party dependencies.
  - Authenticated device pairing with session token verification.
  - SHA-256 manifest validation preventing payload corruption.
  - Safe directory writes and directory traversal prevention.
  - Generates verifiable receipt confirmations.
- **Shared Schema & Protocol (`packages/`):**
  - Formal JSON Schema (`packages/handoff-schema/schema/handoff.schema.json` v1.0.0).
  - End-to-end type-safe transfer protocol models and checksum utilities.
- **Optional AI Proxy (`services/ai-proxy`):**
  - Node.js proxy allowing server-side Gemini credential management.

---

## Quick Start & Verification

### 1. Compile the Mac Receiver
```bash
swiftc \
  packages/handoff-schema/Sources/TossHandoff.swift \
  packages/handoff-schema/Sources/AIProvider.swift \
  packages/transfer-protocol/Sources/TossProtocol.swift \
  packages/transfer-protocol/Sources/TossClient.swift \
  apps/macos-receiver/Sources/ReceiverServer.swift \
  apps/macos-receiver/Sources/main.swift \
  -o bin/toss-receiver
```

### 2. Start the Mac Receiver
```bash
./bin/toss-receiver --port 7443 --storage ./received
```

### 3. Run the Automated Test Suite
```bash
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

---

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Roadmap & Phases](docs/ROADMAP.md)
- [Handoff to GPT / Claude](docs/HANDOFF_TO_NEXT_AI.md)
- [Test Plan](docs/TEST_PLAN.md)
- [Security Policy](docs/SECURITY.md)
- [Architectural Decisions](docs/DECISIONS.md)
