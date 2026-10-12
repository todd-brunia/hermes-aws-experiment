#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
  init) terraform -chdir=infra/runtime init -backend-config=backend.hcl ;;
  plan) terraform -chdir=infra/runtime plan ;;
  apply) terraform -chdir=infra/runtime apply ;;
  destroy) terraform -chdir=infra/runtime destroy ;;
  dashboard-setup) python3 scripts/configure-dashboard.py ;;
  dashboard)
    instance_id=$(terraform -chdir=infra/runtime output -raw instance_id)
    region=$(terraform -chdir=infra/runtime output -raw aws_region)
    aws ssm start-session --region "$region" --target "$instance_id" \
      --document-name AWS-StartPortForwardingSession \
      --parameters '{"portNumber":["9119"],"localPortNumber":["9119"]}'
    ;;
  connect)
    instance_id=$(terraform -chdir=infra/runtime output -raw instance_id)
    region=$(terraform -chdir=infra/runtime output -raw aws_region)
    aws ssm start-session --region "$region" --target "$instance_id"
    ;;
  *) echo "Usage: AWS_PROFILE=your-member-account $0 {init|plan|apply|destroy|connect|dashboard-setup|dashboard}" >&2; exit 2 ;;
esac
