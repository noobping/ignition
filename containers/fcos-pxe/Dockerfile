FROM fedora:latest

ARG UID=1000
ARG GID=1000

RUN dnf -y install \
    dnsmasq \
    nginx \
    coreos-installer \
    dumb-init \
    && dnf clean all && rm -rf /var/cache/dnf

RUN install -d -o root -g root -m 0755 /srv/fcos \
    && install -d -o root -g root -m 0755 /var/lib/tftpboot \
    && install -d -o root -g root -m 0755 /usr/share/nginx/html

RUN groupadd -g ${GID} appuser && useradd -u ${UID} -g ${GID} -M -s /sbin/nologin appuser

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY dnsmasq.conf.tmpl /etc/dnsmasq.conf.tmpl
COPY nginx.conf /etc/nginx/nginx.conf
COPY html/ /usr/share/nginx/html/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80/tcp 69/udp

VOLUME ["/srv/fcos", "/usr/share/nginx/html", "/var/lib/tftpboot"]

ENV FCOS_STREAM=stable \
    FCOS_ARCH=$(uname -m) \
    FCOS_VERSION=current \
    TFTP_ROOT=/var/lib/tftpboot \
    HTTP_ROOT=/usr/share/nginx/html \
    PXE_INTERFACE=eth0 \
    DNSMASQ_EXTRA="" \
    KARGS="ignition.firstboot ignition.platform.id=metal"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]