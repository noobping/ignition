#!/usr/bin/env bash
# Fedora CoreOS storage pool builder — AUTO MODE
# - Scans for completely empty disks and groups them by class (hdd/ssd/nvme)
# - Auto-picks RAID per class based on count:
#     1 disk  -> none
#     2 disks -> raid1
#     3+      -> raid5
# - Creates LUKS2 (TPM2-bound) → LVM (with LVM RAID as above) → Btrfs
# - Adds /etc/crypttab and /etc/fstab and mounts to /mnt/pools/<class>
# - Re-runnable with --add-passphrase to add a human fallback to TPM2-enrolled LUKS
# - No prompts, no extra options — just does it. Use --dry-run to preview.
#
# * Run as root on Fedora CoreOS (or similar). Requires: cryptsetup, systemd-cryptenroll,
#   lvm2, btrfs-progs, lsblk, wipefs, blkid.
set -euo pipefail

VERSION="2.0.0"

# ---------- simple toggles ----------
MOUNT_ROOT="/mnt/pools"
LABEL_PREFIX="POOL"
DRY_RUN=0
ADD_PASSPHRASE=0

# ---------- helpers ----------
err() { echo "[ERR] $*" >&2; }
log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }

device_basename() { basename "$1"; }

# classify device: nvme > ssd (ROTA=0) > hdd (ROTA=1)
class_of() {
  local dev="$1" base rota
  base=$(device_basename $dev)
  rota=$(cat /sys/block/${base}/queue/rotational 2>/dev/null || echo 1)
  if [[ $base == nvme* ]]; then echo nvme; return; fi
  if [[ "$rota" == "0" ]]; then echo ssd; else echo hdd; fi
}

# wipefs -n prints existing signatures. Non-empty output => has sigs
has_signatures() { [[ -n "$(wipefs -n "$1" 2>/dev/null || true)" ]]; }

is_disk_candidate() {
  local dev="$1" base
  base="$(device_basename "$dev")"
  # must be a real disk, not loop/dm/zram, not removable, not RO
  [[ -b "$dev" ]] || return 1
  [[ -e "/sys/block/$base" ]] || return 1
  [[ "$base" =~ ^(sd|vd|xvd|nvme|pmem) ]] || return 1
  [[ -f "/sys/block/$base/removable" ]] && [[ $(cat "/sys/block/$base/removable") == 1 ]] && return 1
  [[ -f "/sys/block/$base/ro" ]] && [[ $(cat "/sys/block/$base/ro") == 1 ]] && return 1
  # disk only (no partitions)
  [[ -z "$(lsblk -nr -o TYPE "$dev" | grep -v '^disk$')" ]] || return 1
  # ignore if any signatures or partition table present
  has_signatures "$dev" && return 1
  return 0
}

choose_mode_for_n() {
  local n="$1"
  if   (( n >= 3 )); then echo raid5
  elif (( n == 2 )); then echo raid1
  elif (( n == 1 )); then echo none
  else echo skip; fi
}

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--add-passphrase] [--version] [--help]

Automatic build of encrypted LVM (+LVM RAID) → Btrfs storage pools per device class.
No interactivity, no extra switches; uses ALL blank disks it finds.

Options:
  --dry-run          Show plan and commands, make no changes
  --add-passphrase   Enroll a human passphrase on TPM2-enrolled LUKS devices created by this script
  --version          Show version
  --help             Show this help

Examples:
  # Build everything automatically on all empty disks
  sudo $0

  # Preview only
  sudo $0 --dry-run

  # Later, add a human passphrase fallback
  sudo $0 --add-passphrase
EOF
}

# ---------- arg parsing ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    --add-passphrase) ADD_PASSPHRASE=1; shift;;
    --version) echo "$VERSION"; exit 0;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 1;;
  esac
done

# ---------- preflight ----------
need lsblk; need wipefs; need cryptsetup; need systemd-cryptenroll; need lvm; need mkfs.btrfs; need blkid; need mount; need awk; need sed; need grep

if (( ADD_PASSPHRASE )); then
  log "Adding a human passphrase to existing TPM2-enrolled LUKS devices created by this script."
  log "You'll be prompted once per device."
  if [[ ! -f /etc/crypttab ]]; then err "/etc/crypttab not found"; exit 1; fi
  mapfile -t lines < <(grep -E '^crypt_(hdd|ssd|nvme)_' /etc/crypttab || true)
  if (( ${#lines[@]} == 0 )); then err "No matching crypttab entries found (crypt_*). Nothing to do."; exit 1; fi
  for line in "${lines[@]}"; do
    name=$(awk '{print $1}' <<<"$line")
    source=$(awk '{print $2}' <<<"$line")
    if [[ "$source" =~ ^UUID= ]]; then
      uuid="${source#UUID=}"
      dev="/dev/disk/by-uuid/${uuid}"
    else
      dev="$source"
    fi
    log "Enrolling passphrase on $dev ($name) ..."
    if (( DRY_RUN )); then
      echo "systemd-cryptenroll $dev --password --unlock-tpm2-device=auto"
    else
      systemd-cryptenroll "$dev" --password --unlock-tpm2-device=auto
    fi
  done
  log "Done."
  exit 0
fi

# ---------- discover blank disks ----------
shopt -s nullglob
candidates=( /dev/sd[a-z] /dev/sd[a-z][a-z] /dev/nvme*n1 /dev/vd[a-z] /dev/xvd[a-z] )
shopt -u nullglob

hdds=(); ssds=(); nvmes=()
for dev in "${candidates[@]}"; do
  is_disk_candidate "$dev" || continue
  cls="$(class_of "$dev")"
  case "$cls" in
    hdd) hdds+=("$dev");;
    ssd) ssds+=("$dev");;
    nvme) nvmes+=("$dev");;
  esac
done

plan_lines=()
add_plan() {
  local cls="$1"; shift
  local -n arr="$1"
  local n=${#arr[@]}
  local m="$(choose_mode_for_n "$n")"
  if (( n > 0 )) && [[ "$m" != skip ]]; then
    plan_lines+=("- $cls: $n device(s), mode=$m: ${arr[*]}")
  fi
}
add_plan hdd hdds
add_plan ssd ssds
add_plan nvme nvmes

if (( ${#plan_lines[@]} == 0 )); then
  err "No eligible blank disks found. (We ignore disks with existing partitions/signatures.)"; exit 1
fi

log "Planned operations:"
printf '%s
' "${plan_lines[@]}"

mkdir -p "$MOUNT_ROOT"
mkdir -p /etc/storage-pools.d

# ---------- build function ----------
build_pool() {
  local cls="$1"; shift
  local devs=("$@")
  local n=${#devs[@]}
  local mode

  if (( n == 0 )); then return 0; fi
  mode="$(choose_mode_for_n "$n")"
  [[ "$mode" == skip ]] && return 0
  case "$mode" in
    none) :;;
    raid1) (( n >= 2 )) || { warn "$cls: need >=2 devices for RAID1 (have $n). Skipping."; return 0; };;
    raid5) (( n >= 3 )) || { warn "$cls: need >=3 devices for RAID5 (have $n). Skipping."; return 0; };;
  esac

  local vg="vg_${cls}"
  local lv="lv_${cls}"
  local label="${LABEL_PREFIX}_${cls^^}"

  log "
>>> Building $cls pool (mode=$mode) on: ${devs[*]}"
  mapnames=()
  luksuuids=()
  tmpkeys=()

  # 1) LUKS2 + enroll TPM2 + open
  for i in "${!devs[@]}"; do
    dev="${devs[$i]}"
    map="crypt_${cls}_$i"
    keyfile="$(mktemp -p /run -t spkey.XXXXXX)"
    tmpkeys+=("$keyfile")
    mapnames+=("$map")

    if (( DRY_RUN )); then
      echo "cryptsetup luksFormat --type luks2 $dev (with random keyfile)"
      echo "systemd-cryptenroll $dev --tpm2"
      echo "cryptsetup open $dev $map --key-file $keyfile"
    else
      head -c 64 /dev/urandom > "$keyfile"
      cryptsetup luksFormat --type luks2 --batch-mode --pbkdf=argon2id --key-file "$keyfile" "$dev"
      systemd-cryptenroll "$dev" --tpm2
      cryptsetup open "$dev" "$map" --key-file "$keyfile"
    fi

    if (( DRY_RUN )); then luksuuids+=("DRYRUN-UUID-$i")
    else luksuuids+=("$(cryptsetup luksUUID "$dev")"); fi
  done

  # 2) PV/VG/LV
  mappers=("${mapnames[@]/#/\/dev\/mapper\/}")
  if (( DRY_RUN )); then
    echo "pvcreate ${mappers[*]}"
    echo "vgcreate $vg ${mappers[*]}"
  else
    pvcreate "${mappers[@]}"
    vgcreate "$vg" "${mappers[@]}"
  fi

  case "$mode" in
    none)
      (( DRY_RUN )) && echo "lvcreate -n $lv -l 100%FREE $vg" || lvcreate -n "$lv" -l 100%FREE "$vg"
      ;;
    raid1)
      (( DRY_RUN )) && echo "lvcreate --type raid1 -m 1 -n $lv -l 100%FREE $vg" || lvcreate --type raid1 -m 1 -n "$lv" -l 100%FREE "$vg"
      ;;
    raid5)
      stripes=$(( n - 1 ))
      (( DRY_RUN )) && echo "lvcreate --type raid5 -i $stripes -n $lv -l 100%FREE $vg" || lvcreate --type raid5 -i "$stripes" -n "$lv" -l 100%FREE "$vg"
      ;;
  esac

  lvpath="/dev/$vg/$lv"

  # 3) Format Btrfs
  (( DRY_RUN )) && echo "mkfs.btrfs -L $label $lvpath" || mkfs.btrfs -L "$label" "$lvpath"

  # 4) Mount + fstab
  mountpt="$MOUNT_ROOT/$cls"
  mkdir -p "$mountpt"
  if (( DRY_RUN )); then
    echo "blkid -s UUID -o value $lvpath -> (UUID)"
    echo "echo 'UUID=<uuid> $mountpt btrfs rw,compress=zstd,noatime 0 0' >> /etc/fstab"
    echo "mount $mountpt"
  else
    fsuuid="$(blkid -s UUID -o value "$lvpath")"
    grep -q "UUID=$fsuuid " /etc/fstab || echo "UUID=$fsuuid $mountpt btrfs rw,compress=zstd,noatime 0 0" >> /etc/fstab
    mount "$mountpt"
  fi

  # 5) crypttab entries + remove temporary key slots
  for idx in "${!devs[@]}"; do
    dev="${devs[$idx]}"; map="${mapnames[$idx]}"; luksuuid="${luksuuids[$idx]}"; keyfile="${tmpkeys[$idx]}"

    if (( DRY_RUN )); then
      echo "echo '$map UUID=$luksuuid none tpm2-device=auto,x-initrd.attach' >> /etc/crypttab"
      echo "cryptsetup luksKillSlot $dev 0"
      echo "cryptsetup close $map"
    else
      if ! grep -qE "^$map[[:space:]]" /etc/crypttab 2>/dev/null; then
        echo "$map UUID=$luksuuid none tpm2-device=auto,x-initrd.attach" >> /etc/crypttab
      fi
      cryptsetup luksKillSlot "$dev" 0 || warn "$dev: could not remove slot 0 (already removed?)"
      cryptsetup close "$map"
      rm -f "$keyfile"
    fi
  done

  log "$cls pool complete: mode=$mode VG=vg_${cls} LV=lv_${cls} mounted at $mountpt (label $label)"
}

# ---------- build all classes ----------
build_pool hdd "${hdds[@]}"
build_pool ssd "${ssds[@]}"
build_pool nvme "${nvmes[@]}"

log "All done. Reboot to verify automatic TPM2 unlock + LVM activation + mounts."
