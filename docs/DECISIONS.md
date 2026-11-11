# TOSS Architectural Decision Records (ADR)

## ADR-001: Standalone Swift POSIX Socket HTTP Server
- **Context:** The macOS receiver needs to listen on the local network for pairing and incoming transfers without requiring third-party package dependencies or full Xcode developer frameworks (e.g. running on machines with Command Line Tools).
- **Decision:** Implement a lightweight, non-blocking HTTP 1.1 server using Darwin/POSIX sockets (`sys/socket.h`, `netinet/in.h`).
- **Consequences:** Zero external dependencies; instant compilation with `swiftc`; robust compatibility across macOS versions.

## ADR-002: Dual-Format Handoff Artifacts (JSON + Markdown)
- **Context:** Downstream consumers include both humans and automated AI agents (Antigravity, GPT, Claude).
- **Decision:** Every handoff produces both a strictly typed `handoff.json` conforming to `handoff.schema.json` v1.0.0 and an easily readable narrative `handoff.md`.
- **Consequences:** Human developers can read instructions immediately; AI agents can parse schema fields deterministically without hallucination.

## ADR-003: Rule-Based Fallback Provider for Complete Offline Operation
- **Context:** Mobile users may not have immediate internet connectivity, or may not have provisioned a Google AI Studio / Gemini API key.
- **Decision:** Provide a built-in `RuleBasedFallbackProvider` that structures thoughts locally without network access or cloud API calls.
- **Consequences:** The app is always functional. Cloud AI structuring remains an optional enhancement rather than a hard failure barrier.

## ADR-004: Explicit Send Action Alongside Gesture
- **Context:** Swipe gestures can occasionally fail due to accessibility constraints or platform touch interception.
- **Decision:** Include a persistent, accessible "Send Handoff" button alongside the swipe-up card animation.
- **Consequences:** Guaranteed usability and accessibility compliance.
