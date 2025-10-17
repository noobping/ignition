#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop"
KEY="${CERT_DIR}/tls.key"
CRT="${CERT_DIR}/tls.crt"

# Wait for system bus (systemd brings it up)
for i in {1..30}; do
  if busctl --system list >/dev/null 2>&1; then break; fi
  sleep 1
done

# Configure RDP with our cert/key
grdctl --system rdp set-tls-key  "$KEY" || true
grdctl --system rdp set-tls-cert "$CRT" || true

# Optional non-interactive credentials
if [[ -n "${GRD_USERNAME:-}" && -n "${GRD_PASSWORD:-}" ]]; then
  # grdctl prompts twice (user, password). We feed both.
  { printf "%s\n" "$GRD_USERNAME"; printf "%s\n" "$GRD_PASSWORD"; } | grdctl --system rdp set-credentials || true
fi

# Make sure RDP is on
grdctl --system rdp enable || true