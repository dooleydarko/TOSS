# TOSS — Phase 3 / Claude release hardening

Phase 2 starts from main 39c17b9. Review the phase2-gpt-refinements branch and its CI evidence before fast-forward integration. Do not rewrite the existing receiver or client. Preserve schema v1.0.0 and local history.

## Release gates (not yet certified)
- [ ] Run the original 12 integrated tests plus new multi-goal and Gemini response tests on macOS; preserve logs. Compile all schema and protocol sources, ReceiverServer.swift and tests/main.swift. No optimized build (assertions must remain active).
- [ ] Generate TOSS.xcodeproj with XcodeGen, compile iOS simulator and physical iPhone; build receiver for Apple Silicon and Intel (minimum macOS 12). Confirm permission usage strings in built Info.plist.
- [ ] Device tests: allow/deny microphone and speech permissions independently, silence versus speech waveform, repeated start/stop, append to typed notes, partial/final transcript, network loss, unsupported locale, call interruption, background/foreground, leaving Capture, manual fallback. Verify no audio files retained, and voice metadata survives JSON/Markdown transfer.
- [ ] Live Gemini tests with an explicitly configured supported model: separate goals, cancellations, conflicting constraints, digressions, embedded prompt injection, malformed response, timeout, quota, offline fallback, raw notes preserved. No claim of model accuracy from mocked tests alone.
- [ ] Receiver: enforce bounded header and 10 MB body limits before allocation, read deadlines, malformed Content-Length, concurrent connection limits, constant-time authentication, one-hour token expiry/revocation, secure randomized pairing secret; audit plaintext LAN HTTP, replay, symlinks, path traversal and idempotent receipt.
- [ ] Queue: existing implementation has retry states but no scheduled backoff loop in processNextBatch; ensure exponential backoff, restart recovery, stable ID-based updates, actor-safe publication, cancellation and no duplicate deliveries. Move stored pairing secrets to Keychain.
- [ ] History: current revision creation reuses handoffId and replaces earlier entries; test retrieval across multiple revisions and restart, stable project ID, migration and durable storage. Git extraction must remain desktop-only.
- [ ] Discovery: test real LAN Bonjour, permission denial, stale devices, reconnection, paired identity, default loopback on physical iPhone and correct target selection.
- [ ] Accessibility: Dynamic Type, VoiceOver, reduced motion, dark mode, explicit send action; ensure gesture and button cannot dispatch twice and receipt status is accurate.
- [ ] Packaging: generate signed iOS archive and Intel/ARM receiver; notarization where needed, secure update and rollback, export compliance/privacy review, version and release notes.
- [ ] Never execute received notes or scripts automatically; review/approval remains mandatory. Do not expose secrets in logs or AI context.

## Reproduce regression run on macOS

    mkdir -p bin
    swiftc packages/handoff-schema/Sources/*.swift packages/transfer-protocol/Sources/*.swift apps/macos-receiver/Sources/ReceiverServer.swift tests/main.swift -o bin/toss-test-runner
    ./bin/toss-test-runner

Physical microphone, Bonjour Wi-Fi and live Gemini accuracy require real devices / credentials. Passing CI is not a substitute.

## Phase 3 progress (GPT pre-hardening; Claude review still required)

Branch `phase3-hardening`, draft PR #2. Phase 2 CI passed 14/14 and simulator compilation. The current Phase 3 branch implements bounded request headers/body (16 KiB/10 MiB), socket deadlines, 16 concurrent connections, session expiry with synchronized storage, manifest validation, replay receipt reuse, and durable revision snapshots. It adds negative receiver tests and revision persistence/transfer assertions. Inspect latest CI before marking these verified. Remaining: queue scheduling/Keychain, pairing secret setup and LAN transport protection, comprehensive adversarial tests, physical iPhone/Mac, Gemini, signed packaging and independent Claude review. The default development secret remains unchanged; do not expose the receiver on an untrusted network.
