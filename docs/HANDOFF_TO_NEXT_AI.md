# TOSS — Handoff to Next AI (GPT & Claude)
**Version:** 1.0.0 (Phase 1 Complete)  
**Author:** Google Antigravity  
**Date:** 2026-11-11  
**Target Repository:** `/Users/abcd/.gemini/antigravity/scratch/toss_handoff`  
**Current Branch:** `main`  
**Commit Hash:** `408281a`  

---

## 1. Executive Summary

Google Antigravity has completed **Phase 1 (Backbone & MVP)** of the TOSS project. The working backbone delivers an end-to-end pipeline:
1. **Schema & Models:** Versioned JSON schema (`handoff.schema.json` v1.0.0), Swift data models, JSON serialization, and human-readable Markdown generation.
2. **AI Structuring:** Pluggable `AIProvider` system supporting Google Gemini API structuring, paired with an offline rule-based fallback that ensures full functionality without internet or API keys.
3. **Mac Receiver:** A standalone POSIX socket HTTP server compiled with `swiftc` (zero external dependencies), implementing authenticated pairing, SHA-256 payload integrity validation, directory traversal prevention, and atomic disk writes.
4. **iPhone Client (SwiftUI):** Full view hierarchy (`CaptureView`, `ReviewView`, `TossView`, `HistoryView`, `SettingsView`) with swipe gesture and accessible button.
5. **End-to-End Verification:** 8/8 automated tests passing, confirming live device pairing, socket payload transmission, checksum verification, and filesystem receipt confirmation.

---

## 2. Architecture Map & Implemented Modules

```
toss_handoff/
├── apps/
│   ├── ios/Sources/
│   │   ├── TossApp.swift          # Main SwiftUI app entry point
│   │   ├── TossStore.swift        # Reactive state container for handoffs & devices
│   │   └── Views.swift            # Capture, Review, Toss, History, Settings views
│   └── macos-receiver/Sources/
│       ├── ReceiverServer.swift   # POSIX socket HTTP server (/health, /pair, /transfer)
│       └── main.swift             # CLI runner with --port, --storage, --secret args
├── packages/
│   ├── handoff-schema/
│   │   ├── schema/
│   │   │   └── handoff.schema.json # JSON Schema Draft 2020-12
│   │   └── Sources/
│   │       ├── TossHandoff.swift  # Swift model & Markdown/JSON serializers
│   │       └── AIProvider.swift   # GeminiAIProvider & RuleBasedFallbackProvider
│   └── transfer-protocol/Sources/
│       ├── TossProtocol.swift     # Wire models, manifest, ACK, SHA-256 utilities
│       └── TossClient.swift       # Async HTTP pairing & transfer client
├── services/
│   └── ai-proxy/
│       ├── package.json
│       └── server.js              # Optional Node.js Gemini API proxy
├── docs/
│   ├── ARCHITECTURE.md            # System architecture details
│   ├── ROADMAP.md                 # Multi-phase progression plan
│   ├── TEST_PLAN.md               # Test matrix and methodology
│   ├── SECURITY.md                # Security policy & threat mitigations
│   ├── DECISIONS.md               # Architectural decision records
│   └── HANDOFF_TO_NEXT_AI.md      # This document
├── examples/
│   ├── sample-handoff.json        # Schema-compliant sample payload
│   └── sample-handoff.md          # Formatted Markdown export sample
├── bin/
│   ├── toss-receiver              # Compiled Mac receiver binary
│   └── toss-test-runner           # Compiled test runner binary
├── tests/
│   └── main.swift                 # Integrated automated test suite
├── .env.example
├── .gitignore
├── Package.swift
└── README.md
```

---

## 3. Environment & Build Commands

- **Environment:** macOS (Darwin 22.6.0), Apple Swift version 5.7.2, Node.js v24.20.0, Python 3.13.14.
- **Xcode Command Line Tools:** `/Library/Developer/CommandLineTools`.

### Build Receiver
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

### Run Tests
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

## 4. Test Execution Record

| Test Suite | Test Case | Status | Verified Output / Behavior |
|---|---|:---:|---|
| TossSchema | Handoff Creation & Validation | PASS | Schema v1.0.0, required fields enforced |
| TossSchema | Empty Title Fails Validation | PASS | Missing title throws TossValidationError |
| TossSchema | JSON Serialization Round-trip | PASS | Exact property match after encode/decode |
| TossSchema | Markdown Serialization | PASS | Sections, bullets, and metadata formatted |
| TossProtocol | SHA-256 Checksum Computation | PASS | 64-char hex, deterministic hashing |
| TossProtocol | Path Traversal & Sanitization | PASS | `../../etc/passwd` sanitized to safe filename |
| AIProvider | Offline Rule-Based AI Fallback | PASS | Unstructured text converted to requirements & actions |
| End-to-End | Full Pairing and Transfer Loop | PASS | Device paired, payload sent, SHA-256 checked, `handoff.json` & `handoff.md` written to disk, ACK verified |

**Note on Untested Areas:**
- Physical iPhone-to-physical-Mac Wi-Fi latency and live Apple Speech Recognition framework require a connected physical iOS device with microphone entitlement.

---

## 5. Next Steps for Phase 2 (GPT) & Phase 3 (Claude)

### Phase 2: GPT Instructions
1. **Preserve the Working Core:** Do not rewrite `ReceiverServer.swift` or `TossClient.swift`; they are already verified end-to-end.
2. **SwiftUI Animation Polish:** In `apps/ios/Sources/Views.swift`, enhance the `TossView` card swipe physics (e.g., adding spring curves and haptic feedback triggers).
3. **Bonjour Discovery:** Integrate `NWBrowser` / `NetServiceBrowser` to discover `_toss._tcp` services automatically without manual IP/port entry.
4. **Prompt Tuning:** Refine the system prompt in `AIProvider.swift` for edge cases (e.g. conversational digressions or multi-objective notes).

### Phase 3: Claude Instructions
1. **Hardening & Security:** Audit socket read buffers in `ReceiverServer.swift` for denial-of-service / oversized payload protection (enforce max body size of 10MB).
2. **Session Lifecycle:** Add timestamp-based token expiration (e.g., tokens expire after 1 hour).
3. **Packaging:** Create an Xcode project (`.xcodeproj`) bundling the iOS app and optional Mac menu bar receiver for release compilation and signing.
