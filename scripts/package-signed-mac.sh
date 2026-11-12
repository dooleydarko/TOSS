#!/bin/bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'Usage: package-signed-mac.sh DEVELOPER_ZIP "Developer ID Application: Name (TEAMID)" NOTARY_PROFILE'
  exit 2
fi
ZIP="$1"
IDENTITY="$2"
PROFILE="$3"
[[ "$IDENTITY" == "Developer ID Application: "* ]] || { echo "Developer ID Application identity required"; exit 2; }
[[ -f "$ZIP" ]] || { echo "Developer ZIP not found"; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist-signed"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ditto -x -k "$ZIP" "$WORK"
STAGE="$WORK/TOSS-Mac-Developer"
APP="$STAGE/TOSS-Desktop.app"
RECEIVER="$STAGE/toss-receiver"
[[ -d "$APP" && -f "$RECEIVER" && -f "$STAGE/BUILD-COMMIT.txt" ]] || { echo "Unexpected package structure"; exit 2; }
lipo "$RECEIVER" -verify_arch x86_64 arm64
lipo "$APP/Contents/MacOS/TOSS-Desktop" -verify_arch x86_64 arm64
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$RECEIVER"
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$RECEIVER"
codesign --verify --deep --strict --verbose=2 "$APP"
DMG="$WORK/TOSS-Mac.dmg"
hdiutil create -volname TOSS -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait --output-format json > "$WORK/notary.json"
python3 - "$WORK/notary.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
if result.get("status") != "Accepted":
    raise SystemExit("Apple notarization was not accepted: " + str(result.get("status")))
PY
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
cp "$DMG" "$OUT/TOSS-Mac.dmg"
cp "$WORK/notary.json" "$OUT/notary-result.json"
(cd "$OUT" && shasum -a 256 TOSS-Mac.dmg > SHA256SUMS.txt)
echo "Signed, notarized local disk image: $OUT/TOSS-Mac.dmg"
echo "No release published; verify on real hardware and complete release acceptance first."
