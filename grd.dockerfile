FROM fedora:latest
RUN dnf -y install \
      systemd dbus dbus-tools shadow-utils passwd \
      gnome-remote-desktop gdm freerdp \
    && dnf clean all

# Create the service user (system account, dedicated home)
RUN useradd -r -m -d /var/lib/gnome-remote-desktop -s /sbin/nologin gnome-remote-desktop

# Generate self-signed RDP cert as the service user
RUN su -s /bin/bash -c '\
      mkdir -p ~/.local/share/gnome-remote-desktop && \
      winpr-makecert -silent -rdp -path ~/.local/share/gnome-remote-desktop tls \
    ' gnome-remote-desktop

# Pre-enable the services and set graphical target
RUN systemctl enable gdm gnome-remote-desktop.service && \
    systemctl set-default graphical.target

COPY scripts/bootstrap-grd.sh /usr/local/bin/bootstrap-grd.sh
RUN chmod +x /usr/local/bin/bootstrap-grd.sh
COPY grd.service /etc/systemd/system/grd-bootstrap.service
RUN systemctl enable grd-bootstrap.service

EXPOSE 3389/tcp
VOLUME ["/sys/fs/cgroup"]

# Hand control to systemd
ENTRYPOINT ["/usr/sbin/init"]
