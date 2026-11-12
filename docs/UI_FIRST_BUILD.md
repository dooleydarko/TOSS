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
