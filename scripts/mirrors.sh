#!/usr/bin/env bash
set -euo pipefail

declare -A remotes=(
    [i3d]="https://mirror.i3d.net/pub/fedora"
    [transip]="https://mirror.transip.net/fedora/fedora/"
    [liteserver]="https://fedora.mirror.liteserver.nl/"
    [netone]="https://mirror.netone.nl/fedora/"
    [hostiserver]="https://mirrors.hostiserver.com/fedora/"
)

echo "Processing ostree remotes..."
for name in "${!remotes[@]}"; do
    url="${remotes[$name]}"
    echo "Adding $name -> URL: $url"
    ostree remote add --set=gpg-verify=true "$name" "$url"
done
echo "Added ostree remotes"
