#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "TOSS developer receiver — plaintext LAN, trusted network and test notes only."
echo "Choose a unique pairing secret (at least 16 characters)."
read -r -s -p "Pairing secret: " TOSS_PAIRING_SECRET
echo
if [[ ${#TOSS_PAIRING_SECRET} -lt 16 || "$TOSS_PAIRING_SECRET" == "toss-dev-secret-change-in-production" ]]; then
  echo "Choose a different secret of at least 16 characters."; exit 2
fi
export TOSS_PAIRING_SECRET
STORAGE="$HOME/Library/Application Support/TOSS/received"
mkdir -p "$STORAGE"
chmod 700 "$STORAGE"
exec ./toss-receiver --host 0.0.0.0 --port 7443 --storage "$STORAGE"
