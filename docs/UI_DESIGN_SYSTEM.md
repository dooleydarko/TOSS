# TOSS — shared UI foundation (v0.5)
Status: proposed design baseline; not yet applied to application screens.

Primary reference approved by the owner: [Ronas IT — Self-care Mobile App Design Concept](https://dribbble.com/shots/23278774-Self-care-Mobile-App-Design-Concept).
Use its calm, minimal, card-led hierarchy as the primary layout reference. Owner correction: no frosted cards, glassmorphism, translucent surfaces or backdrop blur. Use solid, simple surfaces.

## Design principles
- Consistent geometry, spacing, typography, motion and states across every screen.
- One clear primary action per screen; preserve existing working flows and accessibility.
- All cards and controls use solid, opaque surfaces. No frosted glass or decorative blur.
- Product-specific accent colors may change; component behavior and geometry remain shared.
- Native SwiftUI for TOSS; equivalent CSS variables and reusable components for future web applications.

## Proposed tokens
These are starting values, not sampled colors or a final brand palette.

| Token | Light starting value | Role |
| --- | --- | --- |
| canvas | #F2F4F3 | App background |
| surface | #FFFFFF | Solid card surface |
| ink | #172321 | Primary text |
| secondary | #52635F | Secondary text |
| accent | #BCE8DA | Mint highlight, use dark foreground |
| action | #172321 | Primary button, use white foreground |
| border | ink 10% | Subtle surface separation |
| radius-card | 24 pt / px | Cards |
| radius-control | 16 pt / px | Fields and buttons |
| radius-pill | 999 | Chips |
| spacing | 4, 8, 12, 16, 24, 32 | Layout scale |
| motion | 180–280 ms | Standard transitions |

Use system semantic colors for success, warning, error and dark mode; validate contrast in context. Use opaque SwiftUI colors and solid CSS backgrounds. System fonts (SF on iOS, system UI stack on web), dynamic type, 44 pt minimum iOS touch targets, keyboard focus on web. Respect reduced motion and reduced transparency.

## Shared components
- Canvas, screen header, solid card, solid emphasis card, primary and secondary buttons, input field, segmented control, tab bar, status chip, empty/error/loading states.
- Define reusable variants and central tokens. No ad hoc colors, corners or shadows in new screens.
- Use simple flat color blocks, with subtle borders only where needed; long transcripts and code previews need stable, high-contrast surfaces.
- Motion: restrained feedback; the spring-based Toss gesture remains the signature interaction.

## TOSS screen mapping
- Capture/home: adapt the reference's greeting/header area into an entry point for previous handoffs, with access to search, open and edit existing handoffs. Adapt its “How you feel today” tracking area into the recording area with a single Siri-inspired animated orb recording control and editable live transcript (no waveform). Preserve contextual project input and structure CTA.
- Signature ball: adapt the reference's ball into a tangible handoff object. After recording, structuring and review, the user tosses the ball upward to send the completed handoff to the paired desktop. Preserve the accessible send button and transfer acknowledgment; the ball is not a substitute for delivery confirmation.
- Review: clear overview, existing Markdown/JSON views, primary send CTA.
- Toss: destination and transfer status, prominent swipeable ball, explicit accessible send button.
- History: searchable previous handoffs, revision metadata, and an edit/continue flow that preserves prior revisions; entry accessible from the home header.
- Queue: state chips, retry action and informative empty state.
- Settings: grouped controls, connected AI providers, model picker and existing privacy disclosures.

## Build and review gates
1. Introduce centralized tokens/components in isolation, then migrate Capture as reference screen with the header/history entry, recording tracker and ball. Wire editing and ball delivery to real store behavior, not placeholder data.
2. Check visual consistency and behavior in light/dark modes, large text, reduced motion/transparency, small phone layouts and keyboard presentation.
3. Reuse the components for the other screens; keep receiver, transfer, schema and storage unchanged in UI-only commits.
4. Run regression suite and iOS simulator build for each batch; physical device verification and release remain separate.
5. No merge to main until the visual review and functional checks pass. Keep ongoing hardening work separate and reconcile via reviewed integration.

For other web projects, port the semantic tokens and component states, not the iOS code. Add a component gallery showing normal, pressed, focused, disabled, loading, empty and error variants. Each project may set its own accent and imagery while sharing the rules above.

## Recording-to-handoff interaction (owner clarification)
- The home tracking area is the actual voice capture workspace: a single Siri-inspired animated circular orb with an accessible microphone/stop control and visible, continuously updating speech-to-text directly underneath. No waveform, audio bars, or oscillating trace. Idle shows a quiet colorful orb; recording animates internal color and a subtle breathing scale with an obvious stop affordance and elapsed time; processing has its own animation and status label. Keep surrounding cards opaque and flat. After review the orb becomes the ready-to-toss ball; do not send until an explicit swipe or Send action. Respect reduced motion; provide accessible labels and state announcements.
- Preserve the raw editable transcript separately from the structured output; allow stop, correction and additional dictation before structuring.
- A clearly labeled Create Handoff action sends the transcript to the configured AI structuring provider. The existing offline formatter is a fallback and must not be misrepresented as a live AI model. Show processing, errors and retry states, keeping the raw words intact.
- The review area presents the AI-generated title, goals, requirements, constraints and next actions, with existing Markdown and JSON modes. Let the user inspect and edit before sending; continuing an existing handoff should retain revision history.
- Only a successfully prepared handoff is represented by the tossable ball. Swiping or tapping Send transfers the reviewed artifact, not the raw audio. Maintain transfer receipt and offline queue behavior.
- Apple Speech capture and AI structuring are separate stages. Do not claim always-on conversational AI is implemented.

## Model integration (owner requirement)
- Support a provider/model selector for handoff structuring, available in Settings and as a compact selection near Create Handoff. The model that writes a handoff is independent of the destination tool receiving it.
- Preserve the existing Gemini provider and extend the provider interface to support OpenAI, Anthropic and OpenAI-compatible endpoints (including compatible local or hosted models). Add other providers through adapters rather than hard-coding models into the UI.
- Allow free-tier and paid API models where the provider offers them. Do not imply free unlimited use, that a chat subscription includes API credits, or that a provider is connected before verification. Model availability and pricing vary by account and provider.
- Provide user-entered credentials stored in Keychain, connection testing, selectable models, cost/tier disclosure where verified, and clear authentication/rate-limit/error states. Never log or embed secrets. Do not send transcripts to a different cloud provider without user consent. Keep raw text when any provider fails.
- Keep the existing offline rule-based formatter available without a key; identify it as offline formatting, not a language model. Local model support is conditional on a reachable, compatible endpoint and device/server capacity.
- Model integration is a separate functional workstream; UI-only changes must preserve existing working Gemini and offline behavior. Validate adapters and failure paths before release.

## Mandatory component reuse and visual fidelity (owner requirement)
Applies to every coding agent (GPT, Claude, Antigravity, or others). For each approved reusable component, inspect the actual source and demo; if the license permits reuse, import the compatible source or pin a compatible dependency rather than rebuilding an approximate component from a screenshot. Aim for 1:1 visual and interaction fidelity to the approved component, including geometry, colors, typography, spacing, motion timing, states and gestures. Do not silently restyle it. Only change the integration boundary to bind it to TOSS data, navigation and accessibility. Any unavoidable platform, accessibility, license, or compatibility deviations must be documented and approved before accepting the component. The Dribbble composition is the visual direction, not a grant of rights to proprietary code/assets; implement the agreed layout with original branding and licensed components. No glass cards, no waveform. Do not copy Apple's proprietary Siri assets.

### Verified public source candidates (not yet selected or imported)
- https://github.com/mdo91/AI-Animation-Demo — MIT; native pulsing orb and AI state animations.
- https://github.com/mikelikesdesign/SwiftUI-experiments — MIT; AI globe and blob examples.
- https://github.com/SwiftfulThinking/SwiftfulUI — MIT; reusable native buttons, gestures, layouts and view modifiers.
- https://github.com/Shubham0812/SwiftUI-Animations — Apache-2.0; reusable animations.
- https://smoothui.dev/docs/components/siri-orb — web reference; native port requires checking license and reproducing the visual behavior; not a SwiftUI dependency.

### Acceptance gates
1. Record exact repository, source path, commit/tag, license and required notices. Verify individual asset rights and iOS 15 support before importing. No unapproved deployment-target increase.
2. Save approved reference screenshots and recordings, capture matching simulator states at the same viewport and appearance settings, compare side by side and flag discrepancies. Test animation and actual touch behavior separately; a still screenshot is not enough.
3. Keep an internal component gallery for all states and reuse the same component across screens. Do not claim 100% fidelity without visual verification; report differences explicitly.
4. Preserve the real recording/transcript, model selection, handoff structuring, editing, queue and transfer behaviors. All visual changes must pass regression and iOS build gates before integration.
