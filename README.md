[![Build Ignition](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml/badge.svg)](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml)

This repo builds an Ignition file (`fcos.ign`) from Butane and publishes it as a GitHub Pages artifact

```sh
podman run --rm -i -v "$PWD":"/pwd":Z -w /pwd quay.io/coreos/butane:release --files-dir . --strict < butane/fcos.bu > fcos.ign
```

Build the PXE files:

```sh
podman run --rm -i -v "$PWD":"/pwd":Z -w /pwd quay.io/coreos/butane:release --user "$(id -u):$(id -g)" pxe customize --live-ignition /work/fcos.ign -o "/work/initramfs.$(uname -m).img" "/work/$(uname -m)"
```

Pull the image:

```sh
podman pull ghcr.io/noobping/pxeboot:latest
```

Run the image:

```sh
podman run --rm -p 80:80 -p 69:69/udp ghcr.io/noobping/pxeboot:latest
```
