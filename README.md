[![Build Ignition](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml/badge.svg)](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml)

This repo builds an ignition file (`fcos.ign`) from Butane and integrates it into a network boot environment:

```sh
podman run --rm -p 80:80 -p 69:69/udp ghcr.io/noobping/pxeboot:latest
```
