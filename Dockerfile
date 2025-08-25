FROM fedora:latest
RUN dnf -y install dnsmasq nginx iproute which shim grub2 && dnf clean all
RUN mkdir -p /pxe/fcos/{x86_64,aarch64} /pxe/pxelinux.cfg /pxe/EFI/{BOOT,x86_64,aarch64} /var/cache/nginx /var/lib/dnsmasq
RUN cp /usr/share/shim/shimx64.efi /pxe/EFI/BOOT/BOOTX64.EFI \
 && cp /usr/share/shim/shimaa64.efi /pxe/EFI/BOOT/BOOTAA64.EFI \
 && cp /usr/lib/grub/x86_64-efi/grubx64.efi /pxe/EFI/BOOT/grubx64.efi \
 && cp /usr/lib/grub/arm64-efi/grubaa64.efi /pxe/EFI/BOOT/grubaa64.efi

# x86_64
COPY pxe-x86_64/*-initramfs.x86_64-with-ign.img /pxe/http/fcos/x86_64/initramfs.x86_64-with-ign.img
COPY pxe-x86_64/*-kernel.x86_64                 /pxe/http/fcos/x86_64/kernel.x86_64
COPY pxe-x86_64/*-rootfs.x86_64.img             /pxe/http/fcos/x86_64/rootfs.x86_64.img
# aarch64
COPY pxe-aarch64/*-initramfs.aarch64-with-ign.img /pxe/http/fcos/aarch64/initramfs.aarch64-with-ign.img
COPY pxe-aarch64/*-kernel.aarch64                 /pxe/http/fcos/aarch64/kernel.aarch64
COPY pxe-aarch64/*-rootfs.aarch64.img             /pxe/http/fcos/aarch64/rootfs.aarch64.img

# Configuration
COPY configs/fcos.ipxe /pxe/fcos.ipxe
COPY configs/pxelinux.cfg /pxe/pxelinux.cfg/default
COPY configs/dnsmasq.conf /etc/dnsmasq.d/tftp.conf
COPY configs/nginx.conf /etc/nginx/nginx.conf
RUN chown -R nginx:nginx /pxe /var/cache/nginx /var/lib/dnsmasq
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && setcap 'cap_net_bind_service=+ep' /usr/sbin/dnsmasq

USER nginx
WORKDIR /pxe

EXPOSE 80/tcp 69/udp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD bash -c 'ss -lun | grep -q ":69 " && ss -ltn | grep -q ":80 "'
ENTRYPOINT ["/bin/bash", "-c", "nginx -g 'daemon off;' & exec dnsmasq -k --enable-tftp --tftp-root=/pxe/tftp --port=0"]
