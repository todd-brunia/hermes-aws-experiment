#!/usr/bin/env bash
# Run as root on the provisioned server. Generates credentials on the host.
set -euo pipefail
umask 077
if [[ $EUID -ne 0 ]]; then
  echo "Run this installer as root on the Hermes server." >&2
  exit 1
fi
test -f /usr/local/sbin/start-hermes
if [[ ! -f /srv/hermes/dashboard.env ]]; then
  password=$(openssl rand -hex 24)
  session_secret=$(openssl rand -hex 32)
  cat > /srv/hermes/dashboard.env <<ENV
HERMES_DASHBOARD=1
HERMES_DASHBOARD_HOST=0.0.0.0
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=hermes
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=$password
HERMES_DASHBOARD_BASIC_AUTH_SECRET=$session_secret
ENV
  unset password session_secret
fi
chmod 0600 /srv/hermes/dashboard.env
python3 - <<'PY'
from pathlib import Path
path = Path("/usr/local/sbin/start-hermes")
content = path.read_text()
marker = "--env-file /srv/hermes/dashboard.env"
if marker not in content:
    original = "--security-opt no-new-privileges"
    if content.count(original) != 1:
        raise SystemExit("Unexpected startup script; dashboard installation stopped.")
    replacement = marker + " -p 127.0.0.1:9119:9119 " + original
    path.write_text(content.replace(original, replacement))
PY
bash -n /usr/local/sbin/start-hermes
systemctl restart hermes
echo "Dashboard enabled on host loopback port 9119. Username: hermes."
echo "Read the password privately in a Session Manager shell from /srv/hermes/dashboard.env."
