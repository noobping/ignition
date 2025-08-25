#!/usr/bin/env bash

# Normalize names for TFTP/HTTP simplicity
# The download typically yields files with version in name; symlink to stable names
for f in initramfs* rootfs* vmlinuz*; do
[[ -f "$TARGET_DIR/$f" ]] || continue
done
# Symlink best-match
ln -sf "$(ls -1 $TARGET_DIR/vmlinuz* | head -n1)" "$TARGET_DIR/vmlinuz"
ln -sf "$(ls -1 $TARGET_DIR/initramfs* | head -n1)" "$TARGET_DIR/initramfs.img"
ln -sf "$(ls -1 $TARGET_DIR/*rootfs* | head -n1)" "$TARGET_DIR/rootfs.img"
fi

# Publish via HTTP
install -D -m 0644 "$TARGET_DIR/rootfs.img" "$HTTP_ROOT/fcos/rootfs.img"
install -D -m 0644 "$TARGET_DIR/initramfs.img" "$HTTP_ROOT/fcos/initramfs.img"
install -D -m 0644 "$TARGET_DIR/vmlinuz" "$HTTP_ROOT/fcos/vmlinuz"

# Prepare TFTP PXE directory. We'll use iPXE.
mkdir -p "$TFTP_ROOT/ipxe"
cat > "$TFTP_ROOT/ipxe/fcos.ipxe" <<'EOF'
#!ipxe
set base-url http://${next-server}/fcos
kernel ${base-url}/vmlinuz initrd=initramfs.img coreos.live.rootfs_url=${base-url}/rootfs.img ${KARGS}
initrd ${base-url}/initramfs.img
boot
EOF

# Render dnsmasq config (TFTP-only; no DHCP lease handing).
cat > /etc/dnsmasq.conf <<EOF
# TFTP only; assumes an external DHCP server provides next-server/filename or you use ProxyDHCP.
# If you want dnsmasq to offer ProxyDHCP, add to DNSMASQ_EXTRA: --dhcp-range=::,proxy -d --enable-tftp
# Interface binding
interface=${PXE_INTERFACE}
bind-interfaces
# Log to stdout
log-facility=-
# TFTP setup
enable-tftp
TFTP-root=${TFTP_ROOT}
# Serve default iPXE script when client asks for a filename
pxe-service=X86PC,"iPXE",ipxe/fcos.ipxe
# Optional extras
${DNSMASQ_EXTRA}
EOF

# Start services
nginx -g 'daemon off;' &
NGINX_PID=$!

dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf &
DNSMASQ_PID=$!

trap 'kill $DNSMASQ_PID $NGINX_PID; exit 0' TERM INT
wait -n $NGINX_PID $DNSMASQ_PID