#!/usr/bin/env bash

set -euo pipefail

# only valid for Arch Linux with AUR helper
if command -v yay >/dev/null; then
    # import Fedora GPG Key needed for butane-bin
    curl https://fedoraproject.org/fedora.gpg | gpg --import

    yay -S --needed coreos-installer butane-bin dnsmasq
fi

deps_installed="true"

if ! command -v coreos-installer >/dev/null; then
    echo "coreos-installer is not installed"
    deps_installed="false"
fi

if ! command -v butane >/dev/null; then
    echo "butane is not installed"
    deps_installed="false"
fi

if ! command -v dnsmasq >/dev/null; then
    echo "dnsmasq is not installed"
    deps_installed="false"
fi

if [ "$deps_installed" = "false" ]; then
    exit 1
fi

image_name=""

mkdir images 2>/dev/null || true

for f in images/fedora-coreos-*.qcow2; do
    image_name="$f"
    break
done

if [ -z "$image_name" ]; then
    coreos-installer download --stream stable --architecture x86_64 --platform qemu --format qcow2.xz --decompress -C ./images/
else
    echo "Found CoreOS image at $image_name"
fi
