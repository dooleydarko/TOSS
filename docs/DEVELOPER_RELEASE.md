# TOSS 0.1.3 — developer test packages

These are pre-release developer artifacts, not a production release. Download the successful **TOSS developer release packages** workflow artifact from GitHub Actions and extract its ZIPs. Verify checksums with `shasum -a 256 -c SHA256SUMS.txt`.

## Mac (macOS 12+, Intel and Apple Silicon)
Extract TOSS-Mac-Developer.zip. Open TOSS-Desktop.app. Its default inbox is ~/Library/Application Support/TOSS/received. The app is ad-hoc signed, not notarized; Gatekeeper may block it. Review provenance and follow Apple's normal approval process if appropriate; never disable system security.

For local developer LAN tests only, open Start TOSS Receiver.command in the extracted directory. A fresh random pairing code is generated and displayed in Terminal. Keep it private. Keep Terminal open, connect your phone to the same trusted private Wi-Fi, and allow local network access when prompted. On iPhone, select the Mac and enter that code in the Toss screen. Send a non-sensitive test handoff, then verify receipt and both files in the desktop inbox. Stop the receiver with Control-C. Do not open or forward port 7443 to the internet.

## iOS Simulator
Extract TOSS-iOS-Simulator.zip. With an iPhone simulator booted on a compatible Xcode Mac, run:
`xcrun simctl install booted /path/to/TOSS-iOS.app`
`xcrun simctl launch booted com.dooleydarko.toss.ios`

## Physical iPhone
TOSS-iOS-Unsigned-Device.zip contains an unsigned build for inspection; it cannot be installed directly. To test on a phone, clone the same commit, install XcodeGen, run `xcodegen generate`, open TOSS.xcodeproj in Xcode, set your Apple development team and unique bundle identifier if needed, connect your iPhone, choose TOSS-iOS and Run. Enable Developer Mode if requested. App Store/TestFlight builds require Apple signing and provisioning; distribution also requires release and privacy review.

## Release blockers
- Application-layer authenticated encryption is implemented; TLS, independent security review, persistent device identity and real-device verification remain open. No public release.
- Actual iPhone/macOS network, microphone, Keychain and Intel hardware testing remain required.
- Developer ID signing/notarization, iOS provisioning and store distribution are not completed.
- No automatic execution of transferred instructions. Model credentials and quotas are user-provided.
- GitHub artifacts are generated from the commit recorded in BUILD-COMMIT.txt. A build is available only when its workflow succeeds.

## Appearance
Dark is the default. Select Dark, Light or System under iPhone Settings > Appearance or the Mac inbox theme picker. The solid cards, mint action color and existing recording orb remain. History and transfer storage are unchanged. Visual review is still required.

## Secure developer transfers
Version 0.1.2 requires matching new receiver and iPhone builds. Network payloads and acknowledgments use authenticated encryption; discovery and HTTP routing metadata remain visible. The launcher rotates the private pairing code on each restart. For queued transfers from older releases or an earlier receiver run, re-send with the new code. Do not expose port 7443 publicly.

## Export and receiver management
Review > export saves Markdown, JSON or plain text via the system Files picker. New transfers produce handoff.md, handoff.json and handoff.txt; existing matching receipts gain text output on re-send without changing receipt ID. Settings > Devices manages verified saved pairing codes and forgets a receiver. Queue > Retry with new code recovers a failed transfer after a receiver restart. Pairing codes are stored in the phone's Keychain. Use the new receiver and iPhone builds together.
