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
