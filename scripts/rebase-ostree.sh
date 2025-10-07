#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-fedora}"
FLAVOR="${1:-}"
if [[ -z "${FLAVOR}" ]]; then
    echo "Usage: $0 <silverblue|kinoite|coreos> [version]" >&2
    exit 2
fi

echo "Get version for $FLAVOR..."
LATEST_TAG="$(skopeo list-tags docker://quay.io/$REMOTE-ostree-desktops/silverblue | jq -r '.Tags[]' | grep -E '^[0-9]+$' | sort -V | tail -1)"
VERSION=${2:-$((LATEST_TAG - 1))}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
require_cmd rpm-ostree
require_cmd ostree

echo "Rebase $FLAVOR to $VERSION..."
REFSPEC="$REMOTE:$REMOTE/$VERSION/$(uname -m)/$FLAVOR"
if [[ "$FLAVOR" == "coreos" ]]; then
    REFSPEC="$REMOTE:$REMOTE/$(uname -m)/coreos/stable"
fi

if ! ostree remote refs $REMOTE | grep $REFSPEC >/dev/null 2>&1; then
    echo "$REFSPEC not found..."
    exit 2
fi

echo "Current deployments:"
rpm-ostree status || true
echo
echo "Rebasing to: ${REFSPEC}"
sudo rpm-ostree rebase "${REFSPEC}"; exit $?
