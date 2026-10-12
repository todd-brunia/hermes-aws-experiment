#!/usr/bin/env python3
"""Prompt securely; write a Standard SecureString without Terraform state or argv secrets."""
import argparse
import getpass
import json
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--profile", required=True)
parser.add_argument("--region", default="us-east-1")
parser.add_argument("--account-id", required=True)
args = parser.parse_args()
identity = subprocess.run(
    ["aws", "sts", "get-caller-identity", "--profile", args.profile],
    check=True, capture_output=True, text=True,
)
if json.loads(identity.stdout)["Account"] != args.account_id:
    raise SystemExit("Wrong AWS account; no parameter written.")
key = getpass.getpass("OpenAI project service-account key: ").strip()
if not key.startswith("sk-") or any(c.isspace() for c in key):
    raise SystemExit("Expected an OpenAI secret key without whitespace.")
# /dev/stdin works on macOS and Linux. The secret is sent through a pipe,
# never a process argument, temporary file, Terraform variable, or console log.
request = json.dumps({
    "Name": "/hermes-experiment/openai-api-key", "Type": "SecureString",
    "Value": key, "Overwrite": True, "Tier": "Standard",
})
result = subprocess.run(
    ["aws", "ssm", "put-parameter", "--profile", args.profile,
     "--region", args.region, "--cli-input-json", "file:///dev/stdin"],
    input=request, capture_output=True, text=True,
)
if result.returncode:
    raise SystemExit("Parameter write failed; AWS output suppressed to protect the key.")
print("OpenAI key saved. Restart hermes.service on an existing server to reload it.")
