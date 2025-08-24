#!/usr/bin/env bash
set -euo pipefail

detect_dest() {
    for dev in /dev/sd* /dev/vd* /dev/nvme*; do
        if [[ -b "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done
    echo "error: unable to determine installation device" >&2
    return 1
}

main() {
    dest="$(detect_dest)"
    echo "Detected installation device: $dest"
    mkdir -p /etc/coreos/installer.d
    cat > /etc/coreos/installer.d/10-dest.yaml <<EOF
dest-device: $dest
EOF
}

main "$@"
