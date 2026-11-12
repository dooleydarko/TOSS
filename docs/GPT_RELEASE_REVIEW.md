# GPT release review

Base: 9db6c89 (previous regression workflow passed). GPT is conducting this review in lieu of an unavailable Claude session; not an independent Claude approval.

## Findings addressed
- Receiver advertised loopback-only endpoint and blocked the main run loop: advertise only explicit LAN mode and keep the main run loop live.
- Default LAN secret and absent iPhone pairing input: reject known default/short secrets in LAN mode, add explicit user-entered secret, and show HTTP warning.
- Invalid bind address could silently select all interfaces: validate inet_pton; remove local storage path from public health response.
- Incomplete build packaging: explicit release version and schemes, iOS Info.plist with local-network-only ATS exception and permission declarations, universal macOS build and ad-hoc signing, smoke test, simulator and unsigned device artifacts with checksums and notices.

## Open release gates
- Critical: plaintext LAN transport and unauthenticated discovery. Need authenticated encrypted transport and secure pairing/identity before any production release. Checksums do not authenticate the sender.
- High: queue migration may leave historical plaintext backups; verify actual Keychain failure/recovery and app lifecycle.
- High: physical iPhone and Intel hardware compatibility, microphone and network permissions; verify receiver discovery across actual Wi-Fi.
- High: Apple signing, notarization, provisioning, privacy review, release distribution and rollback.
- Medium: receiver lifecycle synchronization, symlink race resistance, persistent transfer identity, queue UX, and independent review.
- Live provider credentials and real device tests not simulated by CI. Do not mark a new build passing until its own CI succeeds.

## 0.1.2 follow-up
Implemented authenticated application-layer encryption, generated pairing codes, and request-bound acknowledgments. Plaintext v1 endpoints are restricted to loopback test fixtures. This is not TLS, forward secrecy, independent device identity or production certification. Real device testing and updated queue credential recovery are still required. Review the new CI results, then continue with remaining MVP export and device management requirements.

## 0.1.3 follow-up
Three-format export, saved receiver pairing, local forget and queue re-key are implemented. New regression and simulator checks are pending. Apple signing, notarization and physical iPhone/Intel tests cannot be substituted by CI compilation. See RELEASE_ACCEPTANCE.md for the exact sequence and external prerequisites.
