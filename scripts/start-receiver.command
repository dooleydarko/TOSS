#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "TOSS secure developer receiver — keep this pairing code private."
TOSS_PAIRING_SECRET="$(/usr/bin/openssl rand -hex 32)"
export TOSS_PAIRING_SECRET
printf 'Pairing code (enter on your iPhone): %s\n' "$TOSS_PAIRING_SECRET"
STORAGE="$HOME/Library/Application Support/TOSS/received"
umask 077
mkdir -p "$STORAGE"
chmod 700 "$STORAGE"
exec ./toss-receiver --host 0.0.0.0 --port 7443 --storage "$STORAGE"
