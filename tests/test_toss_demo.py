#!/usr/bin/env python3
import json
import hashlib
import urllib.request
import urllib.error
import uuid
from datetime import datetime

PORT = 7443
HOST = "127.0.0.1"
BASE_URL = f"http://{HOST}:{PORT}"
PAIRING_SECRET = "toss-dev-secret-change-in-production"

def main():
    print("==================================================")
    print("        TOSS LIVE PHONE-TO-MAC HANDOFF DEMO       ")
    print("==================================================")

    # 1. Check Receiver Health
    print("\n[1/4] Checking Mac Receiver health...")
    req = urllib.request.Request(f"{BASE_URL}/health")
    with urllib.request.urlopen(req) as resp:
        health_data = json.loads(resp.read().decode())
        print(f"      Receiver: {health_data.get('receiver')}")
        print(f"      Status:   {health_data.get('status')}")
        print(f"      Storage:  {health_data.get('storagePath')}")

    # 2. Pair Device
    print("\n[2/4] Pairing iPhone client with Mac Receiver...")
    pair_payload = {
        "deviceId": str(uuid.uuid4()),
        "deviceName": "iPhone 16 Pro (Demo Client)",
        "pairingSecret": PAIRING_SECRET,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    req = urllib.request.Request(
        f"{BASE_URL}/pair",
        data=json.dumps(pair_payload).encode(),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        pair_resp = json.loads(resp.read().decode())
        token = pair_resp.get("token")
        print(f"      Pairing Result: {pair_resp.get('message')}")
        print(f"      Session Token:  {token}")

    # 3. Create Sample Handoff
    print("\n[3/4] Preparing structured handoff package...")
    handoff_id = str(uuid.uuid4())
    project_id = str(uuid.uuid4())
    now_iso = datetime.utcnow().isoformat() + "Z"

    handoff = {
        "schemaVersion": "1.0.0",
        "handoffId": handoff_id,
        "projectId": project_id,
        "title": "TOSS Live Voice Demo: Haptic Audio Sync",
        "createdAt": now_iso,
        "updatedAt": now_iso,
        "revision": 1,
        "destination": "antigravity",
        "objective": "Demonstrate live end-to-end handoff transfer to macOS receiver.",
        "context": "Voice capture recorded on iPhone; user reviewed and initiated swipe toss.",
        "requirements": [
            "Real-time audio-haptic feedback synchronization",
            "Local encrypted delivery with receipt acknowledgment",
            "Safe storage in receiver directory without script execution"
        ],
        "constraints": [
            "Never execute inbound scripts automatically",
            "Enforce strict schema validation and SHA-256 checksums"
        ],
        "completed": [
            "Receiver daemon active on port 7443",
            "Handshake authentication verified"
        ],
        "nextActions": [
            "Inspect handoff.md and handoff.json on Mac",
            "Connect repository to GitHub remote"
        ],
        "knownIssues": [],
        "attachments": [],
        "source": {
            "type": "voice",
            "transcriptAvailable": True,
            "rawInput": "Let's test tossing a sample handoff to the live receiver right now!"
        }
    }

    json_str = json.dumps(handoff, indent=2, sort_keys=True)
    json_hash = hashlib.sha256(json_str.encode()).hexdigest()

    markdown_str = f"""# {handoff['title']}
**Schema Version:** 1.0.0 | **Revision:** 1 | **Destination:** antigravity
**Handoff ID:** `{handoff_id}`
**Project ID:** `{project_id}`
**Created At:** {now_iso}

---

## Objective
{handoff['objective']}

## Context
{handoff['context']}

## Requirements
- Real-time audio-haptic feedback synchronization
- Local encrypted delivery with receipt acknowledgment
- Safe storage in receiver directory without script execution

## Constraints
- Never execute inbound scripts automatically
- Enforce strict schema validation and SHA-256 checksums

## Next Actions
1. Inspect handoff.md and handoff.json on Mac
2. Connect repository to GitHub remote

## Source Note
- **Input Type:** voice (transcript available)
> "Let's test tossing a sample handoff to the live receiver right now!"
"""
    md_hash = hashlib.sha256(markdown_str.encode()).hexdigest()

    transfer_payload = {
        "authToken": token,
        "manifest": {
            "handoffId": handoff_id,
            "title": handoff["title"],
            "schemaVersion": "1.0.0",
            "files": [
                {
                    "filename": "handoff.json",
                    "sizeBytes": len(json_str.encode()),
                    "checksumSha256": json_hash
                },
                {
                    "filename": "handoff.md",
                    "sizeBytes": len(markdown_str.encode()),
                    "checksumSha256": md_hash
                }
            ],
            "timestamp": now_iso
        },
        "markdownContent": markdown_str,
        "jsonContent": json_str
    }

    # 4. Toss Handoff
    print("\n[4/4] Tossing handoff to Mac Receiver...")
    req = urllib.request.Request(
        f"{BASE_URL}/transfer",
        data=json.dumps(transfer_payload).encode(),
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            ack = json.loads(resp.read().decode())
            print("\n================ RECEIPT ACKNOWLEDGEMENT ================")
            print(f"Receipt ID:       {ack.get('receiptId')}")
            print(f"Handoff ID:       {ack.get('handoffId')}")
            print(f"Status:           {'ACCEPTED ✓' if ack.get('accepted') else 'REJECTED ✗'}")
            print(f"Received Files:   {', '.join(ack.get('receivedFiles', []))}")
            print(f"Destination Path: {ack.get('savedToDirectory')}")
            print(f"Server Message:   {ack.get('message')}")
            print("=========================================================\n")
    except urllib.error.HTTPError as e:
        print(f"Server error {e.code}: {e.read().decode()}")

if __name__ == "__main__":
    main()
