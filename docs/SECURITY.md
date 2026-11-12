# TOSS Security & Privacy Policy

## 1. Threat Model & Mitigations

### Untrusted Inbound Content
- **Risk:** Malicious scripts or instructions received over the local network could compromise the developer's workstation if executed automatically.
- **Mitigation:** The macOS receiver **never executes transferred instructions or commands**. Content is saved strictly as passive Markdown and JSON files. External application launches or script evaluations require explicit user confirmation.

### Path Traversal Attacks
- **Risk:** An attacker crafting a handoff title like `../../.ssh/authorized_keys` could attempt arbitrary file overwrite.
- **Mitigation:** All incoming titles and filenames are filtered through `TossSecurityUtils.sanitizeFilename()`, stripping directory separators (`/`, `\`), parent traversal segments (`..`), and null bytes (`\0`).

### Authentication & Pairing
- **Risk:** Rogue devices on the same Wi-Fi network attempting to inject unauthorized files.
- **Mitigation:** Transfer endpoints reject requests without a valid session token. Session tokens are generated only upon completing an authenticated pairing handshake verified with a shared secret (`pairingSecret`).

### Payload Tampering
- **Risk:** Payloads modified in flight over local networks.
- **Mitigation:** Manifests enforce per-file SHA-256 digests. If the computed hash fails to match the manifest item, the receiver immediately halts processing with HTTP 422 (Unprocessable Entity).

### API Credential Leakage
- **Risk:** Hardcoding Gemini API keys into mobile apps or committing them to source control.
- **Mitigation:** No production keys are committed. Environment templates (`.env.example`) are used. For cloud deployments, `services/ai-proxy` encapsulates credentials server-side. Additionally, TOSS works completely offline without any API keys.

## Development release gate

The current LAN protocol is plaintext HTTP. SHA-256 detects corruption, not an active attacker who can alter the payload and manifest; pairing secrets and session tokens can be intercepted. The CLI defaults to loopback, advertises only explicit LAN mode, rejects its default/short pairing secret in LAN mode and warns before listening. The iPhone requires an entered secret. These measures are not TLS or peer authentication. Do not transmit sensitive notes, expose a port publicly, or distribute this as a production release until authenticated encryption, receiver identity, pairing revocation, secure retention and device tests are implemented. Previous plaintext preference backups may retain legacy credentials.

## Secure transport v2 (0.1.2 developer implementation; CI pending)
The current client uses /v2/pair and /v2/transfer only, without plaintext fallback. AES-256-GCM encrypts and authenticates request bodies and responses with separate HKDF-SHA256 direction keys; responses bind to the specific request ciphertext, route and HTTP status. Requests use random nonces and a 120-second freshness window; the receiver rejects repeated pairing ciphertexts with a bounded cache and identical transfer content retains existing receipt idempotence. The launcher generates a new 256-bit random code each run and displays it locally; enter it on the iPhone. Old queue entries encrypted with earlier codes may need a fresh send after restarting the receiver. Legacy plaintext endpoints remain loopback-only for developer fixtures. No claim of TLS, forward secrecy, permanent device identity, protection from denial of service or independent security review. HTTP metadata remains visible, and possession of the shared code permits pairing. Keep the code private; physical device tests, revocation, key lifecycle and external security review remain release gates.
