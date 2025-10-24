#!/usr/bin/env bash
# Mount Btrfs subvolumes on FCOS if not already mounted.

set -euo pipefail

DEV="/dev/disk/by-label/fast"

# Map subvolume name -> mountpoint.
# Note: use subvol="/" for the top-level subvolume.
declare -A MAP=(
  ["/"]="/var/srv/fast"
  ["music"]="/var/music"
  ["apps"]="/var/apps"
  ["git"]="/var/git"
  ["touhou"]="/var/music/touhou"
  ["books"]="/var/books"
  ["docs"]="/var/docs"
  ["photos"]="/var/photos"
  ["videos"]="/var/videos"
  ["snapshots"]="/var/snapshots"
)

err() { echo "[$(basename "$0")] $*" >&2; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "Please run as root."
    exit 1
  fi
}

check_device() {
  if [[ ! -b "$DEV" && ! -e "$DEV" ]]; then
    err "Device $DEV not found. Is the disk present and labeled 'fast'?"
    exit 1
  fi
}

is_already_mounted() {
  local mp="$1"
  # Returns 0 if something is mounted at the mountpoint, 1 otherwise.
  findmnt -rn --target "$mp" >/dev/null 2>&1
}

mount_one() {
  local subvol="$1"
  local mp="$2"

  mkdir -p "$mp"

  if is_already_mounted "$mp"; then
    echo "✓ Already mounted: $mp"
    return 0
  fi

  # Build options. We keep it minimal to match your fstab style.
  # (nofail is an fstab-only option; not used with mount(8).)
  local opts="subvol=$subvol"

  # Mount as Btrfs
  if mount -t btrfs -o "$opts" "$DEV" "$mp"; then
    echo "→ Mounted $DEV (subvol=$subvol) at $mp"
  else
    err "Failed to mount $DEV (subvol=$subvol) at $mp"
    return 1
  fi
}

main() {
  require_root
  check_device

  # Ensure parent dirs exist before child subvols like /var/music/touhou
  # We’ll sort mountpoints by path depth so parents get created first.
  # Build a list of "depth mountpoint subvol"
  mapfile -t items < <(
    for sub in "${!MAP[@]}"; do
      mp="${MAP[$sub]}"
      depth=$(awk -F'/' '{print NF-1}' <<<"$mp")
      printf "%d\t%s\t%s\n" "$depth" "$mp" "$sub"
    done | sort -n
  )

  for line in "${items[@]}"; do
    depth="${line%%$'\t'*}"; rest="${line#*$'\t'}"
    mp="${rest%%$'\t'*}"; sub="${rest##*$'\t'}"
    mount_one "$sub" "$mp"
  done
}

main "$@"