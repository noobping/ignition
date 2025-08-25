#!/usr/bin/env bash
set -euo pipefail
PXE_INTERFACE="${PXE_INTERFACE:-eth0}"
NGINX_DOCROOT="${NGINX_DOCROOT:-/var/www/html}"

# TFTP
rm -rf /tftpboot && ln -s /pxe/tftp /tftpboot

# HTTP
mkdir -p "${NGINX_DOCROOT%/}"
rm -rf "${NGINX_DOCROOT}/pxe" || true
ln -s /pxe/http "${NGINX_DOCROOT}/"

# Pin dnsmasq to interface
CONF="/etc/dnsmasq.d/tftp-only.conf"
sed -i "s/# interface=PXE_INTERFACE/interface=${PXE_INTERFACE}/" "$CONF"

echo "===== dnsmasq (TFTP-only) ====="
cat "$CONF" || true
echo "==============================="

# Start nginx
nginx -g 'daemon off;' &

# Start dnsmasq
exec dnsmasq -k --conf-file="$CONF" ${EXTRA_DNSMASQ_OPTS:-}