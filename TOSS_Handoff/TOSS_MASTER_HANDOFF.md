# TOSS — AI HANDOFF
## Master Build Handoff | Version 0.3 | 2026-11-11

> **READ FIRST — DEVELOPMENT ORDER**
> 1. **Google Antigravity builds the working backbone first.**
> 2. **Google AI Studio / Gemini API supports the app's AI capabilities and prompt testing**; it is not a replacement for Antigravity's IDE or a guarantee of free/unlimited agent execution.
> 3. **GPT reviews/refines the architecture and features.**
> 4. **Claude performs additional implementation, code review, hardening, and release preparation.**
> All phases use **one GitHub repository, one documented architecture, and continuous, verifiable handoffs**. Roles may overlap during reviews. Do not rebuild working parts unnecessarily.

## 1. Product vision

**TOSS** is a standalone, iPhone-first app that turns spoken or typed ideas into structured AI-friendly project handoffs. A user reviews a handoff and *swipes/tosses* it to a paired Mac, where a lightweight receiver saves it and optionally opens the folder or target application. Later, support Windows, two-way transfer, more AI engines, and richer project automations.

TOSS is **not** the AI Office, Scene, or Lyric Studio. It can eventually send handoffs for those projects, but remains a separate product.

**Core experience:** Record or type → transcribe (if voice) → AI organizes content → user edits/approves → swipe to paired computer → encrypted/reliable transfer → receiver saves handoff → success or actionable error.

## 2. Critical scope rule: build a small working foundation, not everything at once

Antigravity's first goal is an *end-to-end working prototype*, not an ambitious dashboard with fake buttons. Implement, test, and document the minimum requirements below, then stop and produce the GPT/Claude continuation package. Use honest status labels (`implemented`, `tested`, `blocked`, `planned`) and avoid unsupported “100% tested” claims.

### Phase 1 — Antigravity: build NOW (MVP)

1. **Project setup:** Initialize a version-controlled repository with separate mobile, receiver, shared-schema, and docs areas; record setup commands and development prerequisites.
2. **iPhone app:** SwiftUI preferred for a native-feeling iPhone-first experience; clear screens for Capture, Review, History, Devices, Settings. Provide text entry immediately; add voice recording and transcription as feasible, with explicit permission handling.
3. **AI formatting:** Add a provider abstraction and connect Gemini first via a secure server-side/proxy pattern or otherwise securely provisioned service; expose configurable model and prompt versions. Never ship a private production API key in client code. The app should also work without AI by letting the user save/send plain text or manually authored Markdown.
4. **Export:** Generate `.md`, `.json`, and `.txt` handoffs; validate structured JSON against a versioned schema. Allow user review/edit before sending.
5. **Mac receiver:** Build a lightweight macOS receiver with device pairing, configurable destination folder, receipt confirmation, and safe file handling. Never automatically run transferred shell commands.
6. **Transfer:** Local-network discovery/pairing with explicit trust (Bonjour/mDNS or a documented equivalent where permitted); authenticated, encrypted local transfer; progress, retry, and clear errors. If mobile platform constraints prevent the ideal swipe behavior, preserve a working Send control and implement animation separately.
7. **History:** Persistent local project/handoff list (e.g., SwiftData/SQLite or suitable local storage), with created/updated timestamps, searchable titles, revision IDs, and transfer statuses.
8. **Demo and testing:** Show a real test: create on iPhone/simulator, receive on macOS, verify file content and acknowledgement. Include repeatable tests for schema and transfer; document hardware requirements and blockers honestly.
9. **Handoff to next agent:** Export current repo commit/branch, tested features, unresolved defects, dependencies, run commands, screenshots/logs as applicable, and prioritized tasks.

**MVP acceptance checks**
- A user can enter text, create a structured handoff (AI-assisted when configured), preview/edit it, and save it locally.
- A user can initiate transfer to a trusted Mac and see verified delivery or a useful error.
- The macOS receiver saves the correct file(s) to a selected folder and acknowledges receipt.
- Invalid JSON is rejected or repaired before export; handoff schema version is recorded.
- The send/receive functionality remains usable without an active ChatGPT/Claude/Antigravity conversation; AI-provider downtime does not prevent transferring existing handoffs.
- No real credentials or secrets are committed to the repository.

### Phase 2 — GPT: refinement

- Audit architecture against the actual code; preserve functioning components.
- Improve UX, accessibility, visual polish, swipe animation, transfer states and recovery.
- Improve transcription/structuring quality with user-approved changes and robust prompt/schema tests.
- Add richer project memory, revision history, search, and optional repository metadata (URL, branch, commit, issues, next tasks).
- Improve offline queue/retry, bidirectional transfer and the handoff preparation workflow.
- Execute and document regression tests; list exact remaining work for Claude.

### Phase 3 — Claude: completion

- Code review, bug fixes, performance, platform-specific behavior, security review, and edge cases.
- Add/update automated tests, failure simulations, packaging and release checklists.
- Implement safe update/recovery infrastructure suited to distribution method (Mac updater only with signed, validated releases; iOS updates subject to Apple distribution rules).
- Produce verified builds and installation instructions when the necessary build/signing environments are available.
- Avoid claims of App Store readiness, signed binaries, or fully verified device behavior without actual evidence.

### Future releases — explicitly NOT required for MVP

- Windows receiver; full two-way phone↔desktop handoffs.
- Multi-provider selection (OpenAI, Anthropic, local models), switching/fallback and cost dashboards.
- Attachments, large-file/cloud transport, GitHub connector with authorized repo introspection.
- Extended cross-project memory, advanced search, reusable handoff templates, automatic version diffing.
- Desktop notifications, in-app update prompts and signed updater; themes/holiday themes.
- AI agent execution of handoffs with explicit user approval and permissions; never automatically execute inbound content.

## 3. Google AI Studio + Gemini API integration

**Use Google AI Studio to prototype/test prompts and structured output.** Gemini API is the first AI backend for transcript structuring, summaries, action lists, and versioned JSON. It may also be useful for optional agent-assisted coding where supported, but **it does not automatically extend Antigravity IDE credits or remove usage limits**.

Recommended abstractions:

```
AIProvider {
  transcribe(audio) -> Transcript     // only for providers/models that support it
  structure(input, context) -> HandoffJSON
  summarize(projectHistory) -> Summary
  health() -> Availability
}
```

- Keep provider implementations interchangeable; feature-detect model capabilities (do not assume every Gemini model directly performs accurate word-level transcription).
- For audio: provide a pluggable transcription adapter; assess on-device Apple speech recognition as a privacy/offline option and supported Gemini audio models as an optional online path.
- Keep secrets server-side whenever possible; provide env templates and setup docs. Do not embed keys in a publicly distributed app or send them through untrusted handoffs.
- Require per-user consent before uploading voice/audio or project content to cloud models. Explain what is sent.
- Include request timeouts, retry/backoff, quotas, budget limits, and a manual/offline fallback.
- Treat AI-generated instructions as **untrusted content**. AI outputs do not grant permission to access files, run code, or send data.
- Prompt templates and JSON schema must be versioned and tested with sample inputs.

## 4. Handoff data format

Produce an editable Markdown document plus a machine-readable JSON representation. Suggested `handoff.schema.json` fields:

```json
{
  "schemaVersion": "1.0.0",
  "handoffId": "uuid",
  "projectId": "uuid",
  "title": "TOSS MVP — Example",
  "createdAt": "ISO-8601 timestamp",
  "updatedAt": "ISO-8601 timestamp",
  "revision": 1,
  "destination": "antigravity | gpt | claude | generic",
  "objective": "Create an end-to-end phone-to-Mac transfer prototype",
  "context": "Relevant project background",
  "requirements": ["Functional requirement"],
  "constraints": ["Security and scope constraint"],
  "completed": [],
  "nextActions": ["Concrete next task"],
  "knownIssues": [],
  "repository": {"url": null, "branch": null, "commit": null},
  "attachments": [],
  "source": {"type": "voice | text | edited", "transcriptAvailable": false}
}
```

This is a **sample payload**, not a complete formal JSON Schema; Antigravity must define the actual JSON Schema, validation, serialization, migration policy, and tests. Preserve UUIDs and timestamps per real records; avoid inventing repo identifiers.

## 5. Suggested UX and interaction

- **Capture:** prominent record button and text input; safe permission/denial states.
- **Review:** split/segmented view of narrative handoff and structured tasks; edit, regenerate selected parts, save.
- **Toss:** select trusted device, preview selected files, perform directional swipe with satisfying animation and an accessible Send button. Show progress and genuine acknowledgement (not animation-only success).
- **History:** searchable cards grouped by project, revision and recipient AI.
- **Devices:** pair, remove trust, show reachability and troubleshooting.
- **Settings:** preferred destination format, save location, privacy controls and provider configuration.
- Visual direction: polished, minimal, smooth and responsive; do not let decorative 3D effects block the functional MVP.

## 6. Security, privacy and reliability

- Secure pairing; authenticated, encrypted transfers; rate limiting and replay protection as appropriate.
- Sanitize file names and paths, prevent path traversal, enforce size limits, validate received manifest/checksums.
- Avoid automatic execution of transferred scripts or instructions. Ask before opening external apps or executing tasks.
- User-controlled microphone access, export, deletion, data retention and AI provider sharing.
- Transfer states: queued → connecting → sending → verifying → received, plus failed/retryable/cancelled.
- Offline capture, local storage and local transfers where supported; online AI optional.
- Durable queue/idempotent transfer identifiers to avoid accidentally duplicating handoffs.
- Crash/logging facilities that do not capture sensitive transcripts by default.
- Maintain compatibility across schema versions and provide migrations rather than destructive resets.

## 7. Repository organization (suggested, adjust to actual platform)

```
TOSS/
  apps/
    ios/
    macos-receiver/
  packages/
    handoff-schema/
    transfer-protocol/
  services/
    ai-proxy/                 # only if using a remote AI provider
  docs/
    ARCHITECTURE.md
    ROADMAP.md
    HANDOFF_TO_NEXT_AI.md
    TEST_PLAN.md
    SECURITY.md
    DECISIONS.md
  examples/
    sample-handoff.md
    sample-handoff.json
  .env.example
  README.md
```

Select realistic technologies and document why. A single Xcode workspace/project shared across iOS/macOS may be simpler than separate incompatible stacks. Choose a build strategy appropriate for the developer's actual Mac and Xcode support; if direct iOS/macOS compilation cannot run, deliver buildable source and precise verification instructions rather than claiming it passed tests.

## 8. Example user text to validate the app

**Spoken/raw note:**
> “I want an iPhone app called TOSS. I can record an idea, have AI make a clean handoff, then swipe it over to my Mac so Antigravity can pick up the project. Keep all the old versions and don't lose the project history.”

**Expected structured handoff:**

```
Project: TOSS
Objective: Transfer AI-ready project instructions from iPhone to Mac.
Requirements:
- Record or type project instructions.
- Generate editable Markdown/JSON handoffs.
- Pair with Mac and securely transfer on user action.
- Save searchable version history.
Constraints:
- iPhone-first, macOS receiver first.
- Working core transfer is more important than animation polish.
Next actions:
1. Create repo and shared handoff schema.
2. Build capture/review prototype.
3. Implement and test secure pairing/receipt.
4. Verify a complete end-to-end transfer.
```

## 9. Mandatory Antigravity completion report

Before declaring Phase 1 done, write `docs/HANDOFF_TO_NEXT_AI.md` containing:

1. Repository URL, exact branch and commit hash.
2. Architecture map and all implemented services/modules.
3. Setup, build, run and test commands with environment details.
4. Precisely which tests ran, output/result, and which tests **did not** run.
5. A real end-to-end verification record or clear blockers.
6. Current known bugs, reproduction steps and logs/screenshots where safe.
7. Next tasks, ordered by severity and dependency.
8. Instructions for GPT and Claude to continue without rebuilding.
9. Version number and safe migration notes.

### First task for Antigravity — EXECUTE IN THIS ORDER

1. Inspect current directory and connected GitHub access; **do not assume an existing repository**.
2. Propose minimal architecture compatible with the actual build environment.
3. Initialize the project and documentation; create the first working capture → export path.
4. Implement receiver, pairing and transfer; test incrementally.
5. Connect Gemini in a secure, optional AI adapter and test schema validation.
6. Demonstrate an actual save/send/receive flow or document precisely what hardware/signing/credentials are blocking verification.
7. Deliver the repository plus `HANDOFF_TO_NEXT_AI.md` for GPT, then Claude.

**Success criterion:** TOSS makes one useful handoff and gets it reliably from an iPhone to a paired Mac, independently of an active coding-assistant session. All other features can be layered on safely through updates.
