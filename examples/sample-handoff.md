# TOSS MVP Prototype
**Schema Version:** 1.0.0 | **Revision:** 1 | **Destination:** antigravity
**Handoff ID:** `a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`
**Project ID:** `f0e1d2c3-b4a5-9687-1234-56789abcdef0`
**Created At:** 2026-11-11T17:45:00Z

---

## Objective
Transfer AI-ready project instructions from iPhone to Mac.

## Context
Build an iPhone-first app called TOSS. Users can record an idea, have AI make a clean handoff, then swipe it over to their Mac so Antigravity can pick up the project. Keep all old versions and don't lose project history.

## Requirements
- Record or type project instructions on iPhone.
- Generate editable Markdown and JSON handoffs conforming to schema 1.0.0.
- Pair with Mac receiver and securely transfer on user action.
- Save searchable version history locally.

## Constraints
- iPhone-first, macOS receiver first.
- Working core transfer is more important than animation polish.
- No plain text production API keys in client code.

## Completed
- Project repository initialized with modular multi-agent structure.
- Handoff schema v1.0.0 defined and sample documents authored.

## Next Actions
1. Build SwiftUI capture and review prototype.
2. Implement macOS receiver with Bonjour advertisement and encrypted endpoint.
3. Verify end-to-end send/receive loop with SHA-256 checksum validation.

## Known Issues
*None reported in this revision.*

## Source Note
- **Input Type:** text
- **Raw Input:**
> "I want an iPhone app called TOSS. I can record an idea, have AI make a clean handoff, then swipe it over to my Mac so Antigravity can pick up the project. Keep all the old versions and don't lose the project history."
