#!/usr/bin/env bash
set -euo pipefail

# add a Kickstart file to a Fedora Silverblue ISO and append a kernel parameter that points to it.
#
# What it does:
#   1) Extract original ISO to a temp dir
#   2) Copy ks.cfg into the ISO root
#   3) Update boot configs to include: inst.ks=cdrom:/<KS_BASENAME>
#   4) Rebuild the ISO while REPLAYING original boot parameters (keeps BIOS+UEFI bootable)
#
# Requirements: xorriso, bsdtar, sed, grep. implantisomd5 checkisomd5, skopeo
#
# optional envs:
#   KS_TARGET=/ks/answer.ks 
#   KS_PARAM='inst.ks=cdrom:/ks/answer.ks'
#

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <fedora release version>" >&2
  exit 64
fi

TAG="$1"

sed "s|__VERSION__|$TAG|g" configs/silverblue.conf > ks.cfg || true

shopt -s nullglob
files=(Fedora-Silverblue-*-$(uname -m)-${TAG}*.iso)
if (( ${#files[@]} == 0 )); then
    echo "Error: no ISO found"
    exit 1
fi
iso_file="${files[0]}"
IN_ISO=$(readlink -f "${iso_file}")
KS_SRC=$(readlink -f "ks.cfg")
OUT_ISO="${IN_ISO%.iso}-noobing.iso"

echo "[*] Input ISO: $IN_ISO"
echo "[*] Kickstart: $KS_SRC"
echo "[*] Output ISO: $OUT_ISO"

[[ -r "$IN_ISO" ]] || { echo "Input ISO not readable: $IN_ISO" >&2; exit 1; }
[[ -r "$KS_SRC" ]] || { echo "Kickstart not readable: $KS_SRC" >&2; exit 1; }

# Where to place the kickstart inside ISO, default /ks.cfg
KS_TARGET="${KS_TARGET:-/ks.cfg}"
KS_PARAM="${KS_PARAM:-inst.ks=cdrom:/ks.cfg}"

WORKDIR="$(pwd)/.cache"
EXTRACT="${WORKDIR}/extract"
mkdir -p "$EXTRACT"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "[*] Extracting ISO to $EXTRACT"
# Using bsdtar preserves file attributes well enough for our purpose.
bsdtar -C "$EXTRACT" -xf "$IN_ISO"

# Place ks file
ks_dest="${EXTRACT}${KS_TARGET}"
mkdir -p "$(dirname "$ks_dest")"
cp -a "$KS_SRC" "$ks_dest"

echo "[*] Inserted Kickstart as ${KS_TARGET}"

# Helper: add KS_PARAM to kernel lines if not already present
add_param_to_kernel_lines() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Only edit if the file contains linux/linuxefi lines
  if grep -Eq '^\s*(linux|linuxefi)\b' "$file"; then
    for cfg in \
      "$EXTRACT/EFI/BOOT/grub.cfg" \
      "$EXTRACT/boot/grub2/grub.cfg"
    do
      [[ -f "$cfg" ]] || continue
      echo "[*] Patching kernel lines in: $cfg"

      # Only patch if no inst.ks is present yet
      if ! grep -Eq '(^|\s)inst\.ks=' "$cfg"; then
        # Append KS_PARAM before an optional trailing 'quiet'
        # Using '#' as sed delimiter avoids issues with '/'
        sed -Ei \
          -e "s#^([[:space:]]*linux(efi)?[[:space:]]+[^[:space:]]+[[:space:]].*?)([[:space:]]quiet)?\$#\1 ${KS_PARAM}\3#" \
          "$cfg"
      fi
    done
  fi

  # isolinux/syslinux configs use 'append' lines
  if grep -Eq '^\s*append\b' "$file"; then
    echo "[*] Patching append lines in: $file"
    # Append KS_PARAM to append lines if missing
    sed -E -i \
      -e "s#^(\s*append\b[^\r\n]*)(?<!\b$(printf %q "$KS_PARAM")\b)\s*$#\1 ${KS_PARAM}#g" \
      "$file" || true
  fi
}

# Patch common boot config locations
add_param_to_kernel_lines "${EXTRACT}/EFI/BOOT/grub.cfg"
add_param_to_kernel_lines "${EXTRACT}/boot/grub2/grub.cfg"
add_param_to_kernel_lines "${EXTRACT}/isolinux/isolinux.cfg"
add_param_to_kernel_lines "${EXTRACT}/isolinux/boot.msg"
add_param_to_kernel_lines "${EXTRACT}/syslinux/syslinux.cfg"
add_param_to_kernel_lines "${EXTRACT}/grub.cfg"

# Sanity: Show a sample linux line after patch
echo "[*] Sample kernel line after patch (if any):"
grep -R --line-number -E '^\s*(linux|linuxefi|append)\b' "$EXTRACT" | head -n 5 || true

# Grab original volume ID robustly (preserve it)
VOLID="$(
  xorriso -indev "$IN_ISO" -pvd_info 2>/dev/null |
  sed -n "s/^[[:space:]]*Volume id[[:space:]]*:[[:space:]]*'\\(.*\\)'.*$/\\1/p"
)"
echo "[*] Using volume ID: ${VOLID}"

IMG_REF="quay.io/fedora-ostree-desktops/silverblue:${TAG}"
OCI_TAR="$WORKDIR/silverblue.oci.tar"

# echo "[*] Fetching container to OCI archive..."
# skopeo copy "docker://$IMG_REF" "oci-archive:$OCI_TAR:${TAG}"
# skopeo copy --override-arch amd64 --override-os linux \
#   docker://quay.io/fedora-ostree-desktops/silverblue:${TAG} \
#   oci-archive:$WORKDIR/silverblue.oci.tar:${TAG}

echo "[*] Building output ISO (replay boot + graft only changed files) -> $OUT_ISO"
xorriso \
  -indev  "$IN_ISO" \
  -outdev "$OUT_ISO" \
  -boot_image any replay \
  ${VOLID:+-volid "$VOLID"} \
  -map "$EXTRACT/ks.cfg"                  /ks.cfg \
  -map "$EXTRACT/EFI/BOOT/grub.cfg"       /EFI/BOOT/grub.cfg \
  -map "$EXTRACT/boot/grub2/grub.cfg"     /boot/grub2/grub.cfg
  # -map "$OCI_TAR"                         /container/silverblue.oci.tar

echo "[*] Implanting ISO checksum (for rd.live.check)"
implantisomd5 --force "$OUT_ISO" || { echo "[-] implantisomd5 failed"; exit 1; }

# echo "[*] Verify ISO checksum..."
# checkisomd5 "$OUT_ISO" || { echo "[-] checkisomd5 failed"; exit 1; }

echo "[✓] Done. Wrote: $OUT_ISO"
