FROM fedora:latest
RUN dnf -y update && \
    dnf -y install cage weston wayland-utils freerdp && \
    dnf clean all
ENV RDP_SERVER=rdp.srv \
    RDP_USER=nick \
    RDP_PASSWORD=kiosk
ENTRYPOINT ["bash", "-lc", "exec cage wlfreerdp /u:\"$RDP_USER\" /p:\"$RDP_PASSWORD\" /v:\"$RDP_SERVER\" /f /clipboard"]
