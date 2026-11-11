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

## Phase 2 — GPT: Refinement & UX Polish
- [ ] Audit architecture against the implemented code; preserve working parts.
- [ ] Visual polish of the SwiftUI card swipe animation and haptic feedback.
- [ ] Enhance prompt engineering and few-shot examples for Gemini structuring.
- [ ] Add Bonjour / mDNS zero-conf auto-discovery for local receivers without manual IP entry.
- [ ] Introduce persistent SQLite / SwiftData storage schema for deep revision history.
- [ ] Regression testing and handoff package generation for Claude.

---

## Phase 3 — Claude: Hardening & Release Preparation
- [ ] Code review, edge case audits, and concurrency safety checks.
- [ ] Security hardening of socket handlers and session token expiry mechanics.
- [ ] Packaging macOS receiver as an optional Menu Bar agent with status indicators.
- [ ] Automated CI/CD workflows for building and testing across macOS and iOS.
- [ ] Verified release notes and deployment documentation.
