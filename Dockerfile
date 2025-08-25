FROM fedora:latest
RUN dnf -y install dnsmasq nginx iproute which && dnf clean all
RUN mkdir -p /pxe/http/fcos/{x86_64,aarch64} /pxe/tftp/EFI/{x86_64,aarch64}

# x86_64
COPY files/fedora-*-initramfs.x86_64-with-ign.img /pxe/http/fcos/x86_64/initramfs.x86_64-with-ign.img
COPY files/fedora-*-kernel.x86_64                 /pxe/http/fcos/x86_64/kernel.x86_64
COPY files/fedora-*-rootfs.x86_64.img             /pxe/http/fcos/x86_64/rootfs.x86_64.img
# aarch64
COPY files/fedora-*-initramfs.aarch64-with-ign.img /pxe/http/fcos/aarch64/initramfs.aarch64-with-ign.img
COPY files/fedora-*-kernel.aarch64                 /pxe/http/fcos/aarch64/kernel.aarch64
COPY files/fedora-*-rootfs.aarch64.img             /pxe/http/fcos/aarch64/rootfs.aarch64.img

# Configuration
COPY containers/pxe-boot/dnsmasq.conf /etc/dnsmasq.d/tftp.conf
COPY containers/pxe-boot/nginx.conf /etc/nginx/nginx.conf
COPY containers/pxe-boot/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80/tcp 69/udp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD bash -c 'ss -lun | grep -q ":69 " && ss -ltn | grep -q ":80 "'
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
