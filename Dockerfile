FROM fedora:latest
RUN dnf -y install dnsmasq nginx iproute which && dnf clean all
RUN mkdir -p /pxe/http/fcos/{x86_64,aarch64} /pxe/tftp/EFI/{x86_64,aarch64} /run/nginx /var/log/nginx /var/cache/nginx /var/lib/dnsmasq

ARG USERNAME=nginx
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USERNAME} && useradd -m -u ${UID} -g ${GID} -r -s /sbin/nologin ${USERNAME}

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
RUN chown -R ${USERNAME}:${USERNAME} /pxe /run/nginx /var/log/nginx /var/cache/nginx /var/lib/dnsmasq
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && setcap 'cap_net_bind_service=+ep' /usr/sbin/dnsmasq

COPY containers/pxe-boot/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

USER ${USERNAME}
WORKDIR /home/${USERNAME}

EXPOSE 80/tcp 69/udp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD bash -c 'ss -lun | grep -q ":69 " && ss -ltn | grep -q ":80 "'
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
