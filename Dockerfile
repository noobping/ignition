FROM fedora:latest
RUN dnf -y install dnsmasq nginx iproute which && dnf clean all
RUN mkdir -p /pxe/http/fcos/{x86_64,aarch64} /pxe/tftp/EFI/{x86_64,aarch64} /run/nginx /var/log/nginx /var/cache/nginx /var/lib/dnsmasq

# x86_64
COPY fedora-*-initramfs.x86_64-with-ign.img /pxe/http/fcos/x86_64/initramfs.x86_64-with-ign.img
COPY fedora-*-kernel.x86_64                 /pxe/http/fcos/x86_64/kernel.x86_64
COPY fedora-*-rootfs.x86_64.img             /pxe/http/fcos/x86_64/rootfs.x86_64.img
# aarch64
COPY fedora-*-initramfs.aarch64-with-ign.img /pxe/http/fcos/aarch64/initramfs.aarch64-with-ign.img
COPY fedora-*-kernel.aarch64                 /pxe/http/fcos/aarch64/kernel.aarch64
COPY fedora-*-rootfs.aarch64.img             /pxe/http/fcos/aarch64/rootfs.aarch64.img

# Configuration
COPY configs/dnsmasq.conf /etc/dnsmasq.d/tftp.conf
COPY configs/nginx.conf /etc/nginx/nginx.conf
RUN chown -R nginx:nginx /pxe /run/nginx /var/log/nginx /var/cache/nginx /var/lib/dnsmasq
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && setcap 'cap_net_bind_service=+ep' /usr/sbin/dnsmasq

USER nginx
WORKDIR /pxe

EXPOSE 80/tcp 69/udp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD bash -c 'ss -lun | grep -q ":69 " && ss -ltn | grep -q ":80 "'
ENTRYPOINT ["/bin/bash", "-c", "nginx -g 'daemon off;' & exec dnsmasq -k --enable-tftp --tftp-root=/pxe/tftp --port=0"]
