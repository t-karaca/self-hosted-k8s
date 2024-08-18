#!/usr/bin/env bash

set -euo pipefail

nmcli connection delete k8s-br0
nmcli connection delete k8s-tap0
nmcli connection delete k8s-tap1
nmcli connection delete k8s-tap2

nmcli connection add \
    type bridge \
    ifname k8s-br0 \
    con-name k8s-br0 \
    ip4 10.10.10.1/24

nmcli connection add \
    type tun \
    ifname k8s-tap0 \
    con-name k8s-tap0 \
    mode tap \
    owner "$(id -u)" \
    ip4 0.0.0.0/24 \
    slave-type bridge \
    master k8s-br0

nmcli connection add \
    type tun \
    ifname k8s-tap1 \
    con-name k8s-tap1 \
    mode tap \
    owner "$(id -u)" \
    ip4 0.0.0.0/24 \
    slave-type bridge \
    master k8s-br0

nmcli connection add \
    type tun \
    ifname k8s-tap2 \
    con-name k8s-tap2 \
    mode tap \
    owner "$(id -u)" \
    ip4 0.0.0.0/24 \
    slave-type bridge \
    master k8s-br0

nmcli connection up k8s-br0

# apply firewall settings only if installed and active
if command -v firewall-cmd >/dev/null && sudo firewall-cmd --state 2>/dev/null; then
    # DHCP needs to be allowed in the firewall for dnsmasq to receive DHCP requests
    sudo firewall-cmd --add-service=dhcp --permanent
    # masquerade for VMs to reach the internet
    sudo firewall-cmd --add-masquerade --permanent
    sudo firewall-cmd --reload
fi

# wait until bridge is ready
sleep 2

sudo dnsmasq --conf-file=dnsmasq.conf --no-daemon
