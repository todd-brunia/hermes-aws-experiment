#!/usr/bin/env python3
"""Prompt securely; write a Standard SecureString without Terraform state or argv secrets."""
import argparse
import getpass
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--profile", required=True)
parser.add_argument("--region", default="us-east-1")
parser.add_argument("--account-id", required=True)
parser.add_argument("--from-clipboard", action="store_true", help="macOS: read the copied key with pbpaste instead of the hidden prompt")
args = parser.parse_args()
identity = subprocess.run(
    ["aws", "sts", "get-caller-identity", "--profile", args.profile],
    check=True, capture_output=True, text=True,
)
if json.loads(identity.stdout)["Account"] != args.account_id:
    raise SystemExit("Wrong AWS account; no parameter written.")
if args.from_clipboard:
    try:
        key = subprocess.run(["pbpaste"], check=True, capture_output=True, text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        raise SystemExit("Could not read the macOS clipboard. Use the hidden prompt instead.")
else:
    key = getpass.getpass("OpenAI project service-account key: ").strip()
if not key.startswith("sk-") or any(c.isspace() for c in key):
    raise SystemExit("Expected an OpenAI secret key without whitespace.")
# AWS CLI distributions differ in how they read /dev/stdin. Use a short-lived
# owner-only file inside an owner-only directory; remove both even on failure.
request = json.dumps({
    "Name": "/hermes-experiment/openai-api-key", "Type": "SecureString",
    "Value": key, "Overwrite": True, "Tier": "Standard",
})
with tempfile.TemporaryDirectory(prefix="hermes-key-") as directory:
    payload = Path(directory) / "request.json"
    with open(payload, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as file:
        file.write(request)
    result = subprocess.run(
        ["aws", "ssm", "put-parameter", "--profile", args.profile,
         "--region", args.region, "--cli-input-json", "file://" + str(payload)],
        capture_output=True, text=True,
    )
if result.returncode:
    code = re.search(r"An error occurred \(([A-Za-z0-9_-]+)\)", result.stderr)
    detail = code.group(1) if code else "AWS CLI error"
    raise SystemExit(f"Parameter write failed ({detail}, exit {result.returncode}); raw output suppressed to protect the key.")
print("OpenAI key saved. Restart hermes.service on an existing server to reload it.")
