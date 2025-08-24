[![Build Ignition](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml/badge.svg)](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml)

This repo builds an Ignition file (`fcos.ign`) from Butane and publishes it as a GitHub Pages artifact

```sh
podman run --rm -i -v "$PWD":"/pwd":Z -w /pwd quay.io/coreos/butane:release --files-dir . --strict < butane/fcos.bu > fcos.ign
```
