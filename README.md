[![Build Ignition](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml/badge.svg)](https://github.com/noobping/ignition/actions/workflows/build-ignition.yml)
[![CodeQL](https://github.com/noobping/ignition/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/noobping/ignition/actions/workflows/github-code-scanning/codeql)
[![License: MIT](https://img.shields.io/badge/License-MIT-default.svg)](https://opensource.org/licenses/MIT)

# Ignition

My Fedora CoreOS Ignition files and related scripts. The goal is to automate the provisioning of Fedora CoreOS and Fedora Silverblue systems.
The ignition file is generated from the [butane file](butane/base.yml). 
The pipeline integrates the ignition file into ISOs and a network boot environment. So that new systems can be provisioned via network boot or bootable ISOs.

## Network Boot Environment

Run the network boot environment using Podman:

```sh
podman run --rm -p 80:80 -p 69:69/udp ghcr.io/noobping/netboot:latest
```

> [!IMPORTANT]
> Make sure to add a DNS record for `net.boot` on the internal DNS server. In the DHCP configuration, set the boot file to either `amd.efi` or `arm.efi`, and use the IP address resolved from `net.boot`.

## Build Ignition

Build the ignition file from the butane file:

```sh
podman run --rm -i -v "$PWD":/work:Z -w /work quay.io/coreos/butane:release --files-dir . --strict < butane/base.yml > fcos.ign
```
