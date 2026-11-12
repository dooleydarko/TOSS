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
