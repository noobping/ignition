#!/usr/bin/env bash
set -euo pipefail

BUTANE_CONFIG="butane/fcos.bu"
OUTPUT_IGN="fcos.ign"

if [[ ! -f "${BUTANE_CONFIG}" ]]; then
    echo "error: Could not find Butane configuration at ${BUTANE_CONFIG}" >&2
    exit 1
fi

echo "Building Ignition config from ${BUTANE_CONFIG}…"

# Convert the Butane config into an Ignition file, copying any files
# referenced from the config into the Ignition.  This mirrors the example
# in the project README.
podman run --rm -i -v "$(pwd)":"/pwd":Z -w /pwd \
    quay.io/coreos/butane:release \
    --files-dir . \
    --strict \
    < "${BUTANE_CONFIG}" > "${OUTPUT_IGN}"

echo "Ignition file written to ${OUTPUT_IGN}"
