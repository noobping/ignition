#!/usr/bin/env bash
done
# Symlink best-match
ln -sf "$(ls -1 $TARGET_DIR/vmlinuz* | head -n1)" "$TARGET_DIR/vmlinuz"
ln -sf "$(ls -1 $TARGET_DIR/initramfs* | head -n1)" "$TARGET_DIR/initramfs.img"
ln -sf "$(ls -1 $TARGET_DIR/*rootfs* | head -n1)" "$TARGET_DIR/rootfs.img"
fi

# 2) Publish via HTTP
install -D -m 0644 "$TARGET_DIR/rootfs.img" "$HTTP_ROOT/fcos/rootfs.img"
install -D -m 0644 "$TARGET_DIR/initramfs.img" "$HTTP_ROOT/fcos/initramfs.img"
install -D -m 0644 "$TARGET_DIR/vmlinuz" "$HTTP_ROOT/fcos/vmlinuz"

# 3) Prepare TFTP PXE directory (iPXE script and/or grub configs). We'll use iPXE (chainloading recommended).
mkdir -p "$TFTP_ROOT/ipxe"
cat > "$TFTP_ROOT/ipxe/fcos.ipxe" <<'EOF'
#!ipxe
set base-url http://${next-server}/fcos
kernel ${base-url}/vmlinuz initrd=initramfs.img coreos.live.rootfs_url=${base-url}/rootfs.img ${KARGS}
initrd ${base-url}/initramfs.img
boot
EOF

# 4) Render dnsmasq config (TFTP-only; no DHCP lease handing). Use proxy mode *if* you pass DNSMASQ_EXTRA accordingly.
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

# 5) Generate an example ignition config URL note (no file served by default). Place any ignition at ${HTTP_ROOT}/ignition/host.ign
mkdir -p "$HTTP_ROOT/ignition"
cat > "$HTTP_ROOT/fcos/README.txt" <<EOF
This server exposes Fedora CoreOS PXE artifacts under /fcos/ .
Set kernel args to include your ignition config, e.g.:
ignition.config.url=http://${HOSTNAME:-pxe}/ignition/host.ign
Current KARGS: ${KARGS}
EOF

# 6) Start services
nginx -g 'daemon off;' &
NGINX_PID=$!

# If capability CAP_NET_BIND_SERVICE/CAP_NET_RAW etc. are present, dnsmasq can bind. Use --keep-in-foreground.
dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf &
DNSMASQ_PID=$!

trap 'kill $DNSMASQ_PID $NGINX_PID; exit 0' TERM INT
wait -n $NGINX_PID $DNSMASQ_PID