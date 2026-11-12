# TOSS developer-to-production acceptance

Status: developer beta. Keep the working branch; never force push or overwrite local history.

## CI gate
- Integrated regression and live loopback receiver tests pass on the exact commit.
- iOS simulator compile, UI tests and screenshots; macOS universal architecture verification.
- Release ZIP smoke test, checksum verification, and recorded source commit.
- Review failures before moving forward. Do not publish an unsigned device build as an installable IPA.

## Physical test matrix
- Mac: macOS 12 or later, Intel and Apple Silicon; record OS/build, launch inbox and receiver; verify permission prompt and actual file output.
- iPhone: supported iOS 15+ device, Xcode version compatible with the phone and signing team; enable Developer Mode when requested.
- Test on same trusted Wi-Fi: discover, pair with code displayed on Mac, type and speak, create offline handoff, edit, export .md/.json/.txt, toss and compare receipt/files. Deny then grant microphone and network permissions.
- Test offline queue recovery, receiver restart and changed code, wrong code, duplicate delivery, revision history and forgetting a receiver. Check app relaunch and history persistence.
- Verify no received instructions are automatically executed. Review security limitations and perform independent security assessment before public distribution.

## Signing and distribution (owner-controlled prerequisites)
- Mac: Apple Developer ID Application identity, registered notarytool Keychain profile, signed executable and app with hardened runtime, notarization and stapling of the distributable container. Verify with codesign and spctl on a clean Mac. Use Apple Developer account credentials locally; never commit certificates, passwords or API keys.
- iPhone: select Apple development team in Xcode, confirm bundle identifier and provisioning, build and run on device. For TestFlight use an enrolled Apple Developer account, archive and upload through Xcode/App Store Connect, provide privacy declarations and complete review where required.
- Update infrastructure: use signed distribution channels only; no automatic unsigned updater. Maintain versioned archives and history-preserving migration; test rollback before enabling automatic updates.

## Remaining security decisions
The developer LAN implementation encrypts request/receipt bodies with a shared random code. It is not TLS or forward secrecy; metadata remains visible. Local forgetting is not server-side individual-device revocation. A new code rotates access for all devices. Review the design with an independent security engineer before public release.

Record each physical test as PASS/FAIL/BLOCKED with hardware, OS, build commit, reproduction and non-sensitive evidence. Do not mark a gate passed without evidence.

## Optional local signing tooling
After the release gates have passed, run `bash scripts/package-signed-mac.sh /path/to/TOSS-Mac-Developer.zip "Developer ID Application: Your Name (TEAMID)" your-notary-keychain-profile` from the checkout on an authorized Mac. It signs the existing universal receiver and app, creates a disk image, submits to Apple notarization, staples and verifies it locally. It does not publish a release. The signer and profile must already be installed; no credentials are accepted by the script. The script does not remove the remaining security/device gates.

For iOS, generate the project and set the signing team in Xcode, then use Product > Archive and Organizer > Distribute App only when you explicitly intend distribution. Do not attempt this on CI without provisioning and authorized credentials.
