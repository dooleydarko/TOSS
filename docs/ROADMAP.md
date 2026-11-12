# TOSS Roadmap & Progression Plan

## Phase 1 — Antigravity: Foundation & MVP Backbone (COMPLETED)
- [x] Initialized version-controlled Git repository with modular multi-agent structure.
- [x] Defined standardized JSON schema (`handoff.schema.json` v1.0.0) and Markdown format.
- [x] Implemented core Swift models with strict validation and round-trip serialization.
- [x] Built `AIProvider` abstraction with `GeminiAIProvider` and 100% offline rule-based fallback.
- [x] Implemented local macOS Receiver with authentication, path sanitization, and SHA-256 integrity verification.
- [x] Implemented SwiftUI iPhone client views (`CaptureView`, `ReviewView`, `TossView`, `HistoryView`, `SettingsView`).
- [x] Verified full end-to-end pairing, payload transfer, and receipt generation via automated integration tests.
- [x] Authored architectural and continuation documentation (`HANDOFF_TO_NEXT_AI.md`).

---

## Phase 2 — Progression & Refinements (IN PROGRESS)
- [x] Implemented Bonjour / mDNS zero-conf auto-discovery (`_toss._tcp`) using Apple's NetService / Network framework.
- [x] Built Offline Transfer Queue & Auto-Retry Engine (`TossTransferQueue`) with retry counters and persistent storage.
- [x] Polished SwiftUI card swipe physics with spring mechanics, dynamic card tilt, shadow scaling, and snap-back curves.
- [x] Added `QueueView` to the iOS client for managing offline and pending handoffs.
- [x] Authored `project.yml` XcodeGen specification with iOS/macOS bundle entitlements.
- [x] Expanded automated test suite from 8 to 10 verified test cases (10/10 passing).
- [ ] Next: SQLite / SwiftData storage schema for deep revision history.
- [ ] Next: Audio waveform visualization and live Speech framework integration on iOS.

---

## Phase 3 — Claude: Hardening & Release Preparation
- [ ] Code review, edge case audits, and concurrency safety checks.
- [ ] Security hardening of socket handlers and session token expiry mechanics.
- [ ] Packaging macOS receiver as an optional Menu Bar agent with status indicators.
- [ ] Automated CI/CD workflows for building and testing across macOS and iOS.
- [ ] Verified release notes and deployment documentation.
