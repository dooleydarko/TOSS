#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
command -v xcodegen >/dev/null || { echo "Install XcodeGen (brew install xcodegen)."; exit 1; }
xcodegen generate
BUILD="$WORK/build"
xcodebuild -project TOSS.xcodeproj -scheme TOSS-Desktop -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project TOSS.xcodeproj -scheme TOSS-Receiver -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project TOSS.xcodeproj -scheme TOSS-iOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project TOSS.xcodeproj -scheme TOSS-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO build
MAC="$WORK/TOSS-Mac-Developer"
SIM="$WORK/TOSS-iOS-Simulator"
DEV="$WORK/TOSS-iOS-Unsigned-Device"
mkdir -p "$MAC" "$SIM" "$DEV"
ditto "$BUILD/Build/Products/Release/TOSS-Desktop.app" "$MAC/TOSS-Desktop.app"
cp "$BUILD/Build/Products/Release/TOSS-Receiver" "$MAC/toss-receiver"
cp scripts/start-receiver.command "$MAC/Start TOSS Receiver.command"
chmod +x "$MAC/toss-receiver" "$MAC/Start TOSS Receiver.command"
for binary in "$MAC/toss-receiver" "$MAC/TOSS-Desktop.app/Contents/MacOS/TOSS-Desktop"; do
  lipo -verify_arch x86_64 arm64 "$binary"
done
# Ad-hoc signing is for local testing only; it is not Developer ID or notarization.
codesign --force --sign - "$MAC/toss-receiver"
codesign --force --sign - "$MAC/TOSS-Desktop.app"
codesign --verify --strict "$MAC/toss-receiver"
codesign --verify --deep --strict "$MAC/TOSS-Desktop.app"
# Verify loopback service and reject the known default secret in LAN mode.
if TOSS_PAIRING_SECRET=toss-dev-secret-change-in-production "$MAC/toss-receiver" --host 0.0.0.0 --port 17443 --storage "$WORK/rejected"; then
  echo "Unsafe LAN default was accepted"; exit 1
fi
"$MAC/toss-receiver" --host 127.0.0.1 --port 17443 --storage "$WORK/smoke" >"$WORK/receiver.log" 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT
for attempt in {1..30}; do
  if curl --fail --silent --max-time 1 http://127.0.0.1:17443/health >"$WORK/health.json"; then break; fi
  sleep 1
done
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["status"]=="healthy" and "storagePath" not in d' "$WORK/health.json"
kill "$PID"
wait "$PID" || true
trap 'rm -rf "$WORK"' EXIT
ditto "$BUILD/Build/Products/Release-iphonesimulator/TOSS-iOS.app" "$SIM/TOSS-iOS.app"
ditto "$BUILD/Build/Products/Release-iphoneos/TOSS-iOS.app" "$DEV/TOSS-iOS.app"
for app in "$SIM/TOSS-iOS.app" "$DEV/TOSS-iOS.app"; do
  /usr/libexec/PlistBuddy -c 'Print :NSBonjourServices:0' "$app/Info.plist" | grep -Fx '_toss._tcp'
  /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsLocalNetworking' "$app/Info.plist" | grep -Fx true
  /usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$app/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :NSSpeechRecognitionUsageDescription' "$app/Info.plist"
done
for dir in "$MAC" "$SIM" "$DEV"; do
  cp docs/DEVELOPER_RELEASE.md "$dir/READ-ME.md"
  mkdir -p "$dir/licenses"
  cp docs/licenses/* "$dir/licenses/"
  git rev-parse HEAD > "$dir/BUILD-COMMIT.txt"
  name="$(basename "$dir")"
  ditto -c -k --sequesterRsrc --keepParent "$dir" "$OUT/$name.zip"
done
(cd "$OUT" && shasum -a 256 TOSS-*.zip > SHA256SUMS.txt)
