#!/usr/bin/env bash
set -euo pipefail
KEY_URL="https://noobping.dev/key.txt"
HOME_DIR="/home/nick"
mkdir -p "$HOME_DIR/.ssh"
curl -fsSL "$KEY_URL" | awk '/^ssh-(ed25519|rsa)/{print}' > "$HOME_DIR/.ssh/authorized_keys"
chown -R nick:nick "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"
chmod 600 "$HOME_DIR/.ssh/authorized_keys"