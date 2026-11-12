#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
RECEIVER="$PWD/toss-receiver"
OS="$(/usr/bin/sw_vers -productVersion)"
echo "TOSS receiver — macOS $OS / $(/usr/bin/uname -m)"
if [[ "${OS%%.*}" -lt 12 ]]; then
  echo "This build requires macOS 12 or newer. No pairing code was generated."
  exit 2
fi
if [[ ! -x "$RECEIVER" ]]; then
  echo "Receiver executable missing or not executable. Extract the complete developer ZIP again."
  exit 2
fi
if ! /usr/bin/codesign --verify --strict "$RECEIVER"; then
  echo "Receiver signature verification failed. Do not run this copy. Re-download and extract the original package."
  exit 2
fi
# Preflight the exact binary before showing a private pairing code.
set +e
"$RECEIVER" --version
STATUS=$?
set -e
if [[ $STATUS -ne 0 ]]; then
  echo "Receiver preflight failed (exit $STATUS). Exit 137 means SIGKILL."
  echo "Run Diagnose TOSS.command and share the report, not a pairing code."
  exit "$STATUS"
fi
STORAGE="$HOME/Library/Application Support/TOSS/received"
umask 077
mkdir -p "$STORAGE"
chmod 700 "$STORAGE"
TOSS_PAIRING_SECRET="$(/usr/bin/openssl rand -hex 32)"
export TOSS_PAIRING_SECRET
echo "Keep this pairing code private."
printf 'Pairing code (enter on your iPhone): %s\n' "$TOSS_PAIRING_SECRET"
set +e
"$RECEIVER" --host 0.0.0.0 --port 7443 --storage "$STORAGE"
STATUS=$?
set -e
unset TOSS_PAIRING_SECRET
if [[ $STATUS -ne 0 ]]; then
  echo "Receiver exited (status $STATUS). Run Diagnose TOSS.command; do not share the pairing code."
fi
exit "$STATUS"
