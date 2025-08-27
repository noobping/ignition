#!/usr/bin/env bash
set -euo pipefail

DEST_DEVICE=${1:-/dev/sda}
STOCK_ISO="fcos-live.iso"
CUSTOM_ISO="fcos-auto-install.iso"
IGN_FILE="fcos.ign"

if [[ ! -f "${IGN_FILE}" ]]; then
    echo "error: Ignition file ${IGN_FILE} not found.  Run scripts/build-ignition.sh first." >&2
    exit 1
fi

if [[ ! -f "${STOCK_ISO}" ]]; then
    podman run --rm --pull=always -v "$(pwd)":/data:Z -w /data \
        quay.io/coreos/coreos-installer:release \
        download -f iso
    mv fedora-coreos-*-live-iso.$(arch).iso "${STOCK_ISO}"
    mv fedora-coreos-*-live-iso.$(arch).iso.sig "${STOCK_ISO}.sig"
else
    echo "Using existing ${STOCK_ISO}"
fi

echo "Creating customized ISO ${CUSTOM_ISO} to install to ${DEST_DEVICE}…"
podman run --rm --pull=always \
    --user "$(id -u):$(id -g)" \
    -v /dev:/dev -v /run/udev:/run/udev -v "$(pwd)":/data:Z -w /data \
    quay.io/coreos/coreos-installer:release \
    iso customize \
    --live-ignition "${IGN_FILE}" \
    --dest-device "${DEST_DEVICE}" \
    --dest-ignition "${IGN_FILE}" \
    -o "${CUSTOM_ISO}" \
    "${STOCK_ISO}"

echo "Customized ISO created as ${CUSTOM_ISO}"
