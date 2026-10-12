#!/usr/bin/env python3
"""Install the optional dashboard on the current Terraform instance using SSM."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
state = json.loads(subprocess.run(
    ["terraform", "-chdir=" + str(root / "infra/runtime"), "output", "-json"],
    capture_output=True, text=True, check=True,
).stdout)
instance = state["instance_id"]["value"]
region = state["aws_region"]["value"]
aws = ["aws", "--region", region]
payload = {
    "InstanceIds": [instance], "DocumentName": "AWS-RunShellScript",
    "Parameters": {"commands": [(root / "scripts/enable-dashboard-host.sh").read_text()]},
}
with tempfile.TemporaryDirectory(prefix="hermes-dashboard-") as directory:
    path = Path(directory) / "request.json"
    with open(path, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as file:
        json.dump(payload, file)
    command_id = subprocess.run(
        aws + ["ssm", "send-command", "--cli-input-json", "file://" + str(path),
               "--query", "Command.CommandId", "--output", "text"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
for attempt in range(24):
    time.sleep(5)
    result = subprocess.run(
        aws + ["ssm", "get-command-invocation", "--command-id", command_id,
               "--instance-id", instance, "--query", "Status", "--output", "text"],
        capture_output=True, text=True,
    )
    status = result.stdout.strip()
    if status == "Success":
        print("Dashboard configured. Run: bash scripts/stack.sh dashboard")
        break
    if status in {"Failed", "Cancelled", "TimedOut"}:
        raise SystemExit(f"Dashboard setup {status}; inspect SSM command {command_id}.")
else:
    raise SystemExit(f"Dashboard setup still pending; inspect SSM command {command_id}.")
