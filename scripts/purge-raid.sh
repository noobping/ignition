# TARGET RAID UUID
UUID='92e834db:6e1cd704:26d110d0:bec8f175'

set -euo pipefail

# 1) Stop any active md arrays carrying that UUID
for md in /dev/md*; do
  [ -e "$md" ] || continue
  if mdadm --detail "$md" 2>/dev/null | grep -q "$UUID"; then
    echo "Stopping $md"
    mdadm --stop "$md" || true
  fi
done

# 2) Identify all member devices/partitions with that UUID
mapfile -t DEVS < <(
  for d in /dev/sd? /dev/sd?? /dev/nvme?n? /dev/nvme?n?p?; do
    [ -e "$d" ] || continue
    mdadm --examine "$d" 2>/dev/null | grep -q "$UUID" && echo "$d"
  done | sort -u
)

echo "Matched devices: ${DEVS[*]:-none}"
[ "${#DEVS[@]}" -gt 0 ] || { echo "Nothing to wipe for that UUID."; exit 0; }

# 3) Force read-write and unmount anything on them
for d in "${DEVS[@]}"; do
  swapoff "$d" 2>/dev/null || true
  umount -f "$d" 2>/dev/null || true
  hdparm -r0 "$d"   >/dev/null 2>&1 || true
  blockdev --setrw "$d"           || true
done

# 4) Nuke md superblocks + filesystem signatures
for d in "${DEVS[@]}"; do
  echo "Zeroing md superblock on $d"
  mdadm --zero-superblock --force "$d" || true
  echo "Wiping FS signatures on $d"
  wipefs -a "$d" || true
done

# 5) (Paranoid) wipe the first and last MB where md metadata may live
for d in "${DEVS[@]}"; do
  echo "Scrubbing edges on $d"
  dd if=/dev/zero of="$d" bs=1M count=8 conv=fsync status=none || true
  SZ=$(blockdev --getsz "$d")        # sectors
  OFF=$((SZ - 2048))                 # last ~1MB
  dd if=/dev/zero of="$d" bs=512 seek="$OFF" count=2048 conv=fsync status=none || true
done

# 6) Final sweep: re-probe and ensure no md sees that UUID
partprobe || true
udevadm settle || true
mdadm --examine --scan | grep -q "$UUID" && echo "Warning: UUID still seen." || echo "UUID purged."
