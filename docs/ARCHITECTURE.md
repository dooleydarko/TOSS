# TOSS Architecture Documentation
**Version:** 1.0.0 (Phase 1 MVP)  
**Date:** 2026-11-11  

---

## 1. System Overview

TOSS is an iPhone-first productivity system designed to turn quick spoken or typed ideas into structured, versioned AI handoffs (`.md`, `.json`, `.txt`) and transfer them locally to a paired Mac receiver with minimal friction.

```
+-----------------------------------------------------------+
|                      iPhone Client (SwiftUI)               |
|                                                           |
|  +-------------------+    +----------------------------+  |
|  |  Voice / Text     | -> | AI Structurer (Gemini API  |  |
|  |  Capture Interface|    | or Local Offline Fallback) |  |
|  +-------------------+    +----------------------------+  |
|            |                           |                  |
|            v                           v                  |
|  +-------------------+    +----------------------------+  |
|  | Local SwiftStore  |    | Structured Handoff Object  |  |
|  | (History & Cache) |    | (Schema Version 1.0.0)     |  |
|  +-------------------+    +----------------------------+  |
|                                        |                  |
|                                        v                  |
|                           +----------------------------+  |
|                           | TossClient Network Layer   |  |
|                           | (Pairing + SHA-256 Digest) |  |
|                           +----------------------------+  |
+----------------------------------------|------------------+
                                         | Local HTTP / mDNS
                                         | Transfer Protocol
                                         v
+-----------------------------------------------------------+
|                   macOS Receiver (Swift / POSIX)          |
|                                                           |
|  +-----------------------------------------------------+  |
|  | ReceiverServer (Default Port 7443)                  |  |
|  | - Auth session verification                         |  |
|  | - SHA-256 payload integrity check                   |  |
|  | - Path sanitization & traversal defense             |  |
|  +-----------------------------------------------------+  |
|                            |                              |
|                            v                              |
|  +-----------------------------------------------------+  |
|  | Storage Directory: ~/Documents/TOSS_Received/       |  |
|  | - handoff.json (Machine-readable)                   |  |
|  | - handoff.md   (Human-readable narrative)           |  |
|  | - receipt.json (Cryptographic delivery receipt)     |  |
|  +-----------------------------------------------------+  |
+-----------------------------------------------------------+
```

---

## 2. Component Directory

1. **`packages/handoff-schema/`**:
   - `handoff.schema.json`: Formal JSON Schema 1.0.0.
   - `TossHandoff.swift`: Model declarations, validations, Markdown generator, and JSON codec.
   - `AIProvider.swift`: Pluggable AI structuring layer featuring `GeminiAIProvider` and zero-dependency `RuleBasedFallbackProvider`.

2. **`packages/transfer-protocol/`**:
   - `TossProtocol.swift`: Pairing models, transfer manifests, receipt ACK structures, and SHA-256 security utilities.
   - `TossClient.swift`: Client-side handshake, authentication, payload dispatch, and progress streaming.

3. **`apps/macos-receiver/`**:
   - `ReceiverServer.swift`: Non-blocking POSIX socket HTTP server supporting `/health`, `/pair`, and `/transfer`.
   - `main.swift`: CLI entrypoint accepting `--port`, `--host`, `--storage`, and `--secret`.

4. **`apps/ios/`**:
   - `TossStore.swift`: Reactive state container managing handoffs, pairing credentials, and transfer events.
   - `Views.swift`: SwiftUI views implementing Capture, Review, Toss (with swipe and accessible button), History, and Settings.
   - `TossApp.swift`: Multiplatform SwiftUI app bootstrap.

5. **`services/ai-proxy/`**:
   - `server.js`: Optional server-side proxy protecting private Gemini API keys from client exposure.
