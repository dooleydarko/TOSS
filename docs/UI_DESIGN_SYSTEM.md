# TOSS — shared UI foundation (v0.1)
Status: proposed design baseline; not yet applied to application screens.

Primary reference approved by the owner: [Ronas IT — Self-care Mobile App Design Concept](https://dribbble.com/shots/23278774-Self-care-Mobile-App-Design-Concept).
Adapt its calm, minimal, card-led hierarchy. Add restrained frosted glass surfaces as requested. This is inspiration, not a pixel-for-pixel reproduction.

## Design principles
- Consistent geometry, spacing, typography, motion and states across every screen.
- One clear primary action per screen; preserve existing working flows and accessibility.
- Frosted glass is a surface treatment, not a readability requirement. Use opaque surfaces when contrast, reduced transparency, performance or platform support requires it.
- Product-specific accent colors may change; component behavior and geometry remain shared.
- Native SwiftUI for TOSS; equivalent CSS variables and reusable components for future web applications.

## Proposed tokens
These are starting values, not sampled colors or a final brand palette.

| Token | Light starting value | Role |
| --- | --- | --- |
| canvas | #F2F4F3 | App background |
| surface | #FFFFFF | Opaque fallback |
| ink | #172321 | Primary text |
| secondary | #52635F | Secondary text |
| accent | #BCE8DA | Mint highlight, use dark foreground |
| action | #172321 | Primary button, use white foreground |
| glass | white 70% | Frosted overlay, contrast tested |
| border | ink 10% | Subtle surface separation |
| radius-card | 24 pt / px | Cards |
| radius-control | 16 pt / px | Fields and buttons |
| radius-pill | 999 | Chips |
| spacing | 4, 8, 12, 16, 24, 32 | Layout scale |
| motion | 180–280 ms | Standard transitions |

Use system semantic colors for success, warning, error and dark mode; validate contrast in context. Native materials on iOS 15+; CSS backdrop-filter with opaque fallback on web. System fonts (SF on iOS, system UI stack on web), dynamic type, 44 pt minimum iOS touch targets, keyboard focus on web. Respect reduced motion and reduced transparency.

## Shared components
- Canvas, screen header, glass card, solid emphasis card, primary and secondary buttons, input field, segmented control, tab bar, status chip, empty/error/loading states.
- Define reusable variants and central tokens. No ad hoc colors, corners or shadows in new screens.
- Glass is best on navigation, controls and secondary cards; long transcripts and code previews need stable, high-contrast surfaces.
- Motion: restrained feedback; the spring-based Toss gesture remains the signature interaction.

## TOSS screen mapping
- Capture: large voice card, recording control, live waveform and editable transcript, contextual project input, structure CTA.
- Review: clear overview, existing Markdown/JSON views, primary send CTA.
- Toss: destination and transfer status, prominent swipeable card, explicit accessible send button.
- History: searchable handoff cards, revision metadata.
- Queue: state chips, retry action and informative empty state.
- Settings: grouped controls with existing privacy disclosures.

## Build and review gates
1. Introduce centralized tokens/components in isolation, then migrate Capture as reference screen.
2. Check visual consistency and behavior in light/dark modes, large text, reduced motion/transparency, small phone layouts and keyboard presentation.
3. Reuse the components for the other screens; keep receiver, transfer, schema and storage unchanged in UI-only commits.
4. Run regression suite and iOS simulator build for each batch; physical device verification and release remain separate.
5. No merge to main until the visual review and functional checks pass. Keep ongoing hardening work separate and reconcile via reviewed integration.

For other web projects, port the semantic tokens and component states, not the iOS code. Add a component gallery showing normal, pressed, focused, disabled, loading, empty and error variants. Each project may set its own accent and imagery while sharing the rules above.
