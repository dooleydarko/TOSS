# First iPhone UI implementation

Base e45e65f. Capture uses solid surfaces and native text, original speech recognition and handoff actions, a recent-handoff entry to the existing history screen, and a Siri-inspired recording orb. No waveform is displayed. No timing API, new draft persistence, or Lyric Studio changes. Model label shows the existing configuration, not a verified connection. History editing, additional model adapters, Discover, ready-to-toss ball, and desktop interface remain separate work.

## Upstream source
- Repository: https://github.com/mdo91/AI-Animation-Demo
- Commit: 14986559887b8ac388e8d73916f833b02d77b14e
- Path: AI-Animation-Demo/Components/Orb/PulsingOrb.swift
- MIT: docs/licenses/AI-Animation-Demo.txt (retain in distribution notices).
- Imported component body unchanged; only removed preview macro and added attribution. Wrapper uses 90pt size instead of demo default 140pt for capture layout, adds state icons, and uses a static gradient when idle/reduced motion. These are integration adaptations, not a verified pixel-identical replica. Demo project requires iOS 17 but component uses iOS 15-era SwiftUI APIs; retain current iOS deployment target and compile in CI. User visual review still required.

## Verification
Run integrated regression, receiver build, simulator compile and home launch/screenshot. This does not verify physical microphone or animation behavior; inspect screenshot and test real iPhone separately. No main merge.

## Review and Toss follow-up
Editable structured fields with explicit Save/Cancel and original transcript preserved. Changed reviews create revision snapshots using the existing local storage key; latest versions remain the visible history list. Review previews and sends use the saved revision. The Toss ball reuses the recording orb's color family, uses an upward swipe or accessible button, respects reduced motion, selects a receiver, prevents duplicate actions during a send, and shows success only after an accepted matching receipt. Queued status is not delivery. Physical devices exclude the synthetic loopback target. Existing insecure development pairing and queue scheduling remain hardening work. The ball is an original integration variation, not a verified reproduction of the reference. No new model, Discover, history editing entry or desktop UI in this commit. Visual and physical verification remain outstanding.
