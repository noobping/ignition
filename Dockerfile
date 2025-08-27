FROM fedora:latest
RUN dnf -y install dnsmasq nginx iproute ipxe-bootimgs-x86 ipxe-bootimgs-aarch64 && dnf clean all
RUN mkdir -p /pxe/fcos /var/cache/nginx /var/lib/dnsmasq
RUN cp /usr/share/ipxe/arm64-efi/snponly.efi /pxe/arm.efi
RUN cp /usr/share/ipxe/ipxe-snponly-x86_64.efi /pxe/amd.efi

# Ignition file
COPY fcos.ign /pxe/ign.json
COPY ks.cfg /pxe/ks.cfg
# x86_64
COPY pxe-x86_64/*-initramfs.x86_64-with-ign.img /pxe/fcos/initramfs-x86_64.img
COPY pxe-x86_64/*-kernel.x86_64                 /pxe/fcos/kernel-x86_64
COPY pxe-x86_64/*-rootfs.x86_64.img             /pxe/fcos/rootfs-x86_64.img
# aarch64
COPY pxe-aarch64/*-initramfs.aarch64-with-ign.img /pxe/fcos/initramfs-aarch64-with-ign.img
COPY pxe-aarch64/*-kernel.aarch64                 /pxe/fcos/kernel-aarch64
COPY pxe-aarch64/*-rootfs.aarch64.img             /pxe/fcos/rootfs-aarch64.img

# Configuration
COPY configs/default.ipxe /pxe/default.ipxe
COPY configs/dnsmasq.conf /etc/dnsmasq.d/tftp.conf
COPY configs/fcos.ipxe /pxe/fcos.ipxe
COPY configs/nginx.conf /etc/nginx/nginx.conf
RUN chown -R nginx:nginx /pxe /var/cache/nginx /var/lib/dnsmasq
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && setcap 'cap_net_bind_service=+ep' /usr/sbin/dnsmasq

USER nginx
WORKDIR /pxe

EXPOSE 80/tcp 69/udp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD bash -c 'ss -lun | grep -q ":69 " && ss -ltn | grep -q ":80 "'
ENTRYPOINT ["/bin/bash", "-c", "nginx -g 'daemon off;' & exec dnsmasq -k --enable-tftp --tftp-root=/pxe --port=0"]
