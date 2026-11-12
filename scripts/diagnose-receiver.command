#!/bin/bash
# No pairing secret, no network listener, no changes to security settings.
cd "$(dirname "$0")" || exit 1
echo "=== TOSS launch diagnostics ==="
/usr/bin/sw_vers
/usr/bin/uname -m
/usr/bin/file ./toss-receiver
/usr/bin/codesign --verify --strict --verbose=2 ./toss-receiver
echo "Signature verification exit: $?"
/usr/sbin/spctl --assess --type execute --verbose=2 ./toss-receiver
echo "Gatekeeper assessment exit: $?"
/bin/df -h .
./toss-receiver --version
echo "Receiver launch exit: $?"
echo "=== End diagnostics (no pairing code) ==="
