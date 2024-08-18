#!/usr/bin/env bash

set -euo pipefail

set -a
source .env
set +a

NODE_NAME="worker1"

NODE_MAC="86:e2:e3:21:13:b5"
IP_ADDRESS="10.10.10.11"
NET_INTERFACE="k8s-tap1"
CPU_COUNT="2"
MEMORY_SIZE="2048"

IMAGE_NAME="node-$NODE_NAME.qcow2"
PID_FILE="$NODE_NAME.pid"
LOG_FILE="$NODE_NAME.log"
TOKEN_FILE="$NODE_NAME.token"
BUTANE_CONFIG="$NODE_NAME.bu"
IGNITION_CONFIG="$NODE_NAME.ign"

if [ -f "$PID_FILE" ]; then
    node_pid=$(cat "$PID_FILE")

    if [ "$node_pid" -gt "0" ] && ps --pid "$node_pid"; then
        echo "Node already running."
        exit 0
    fi
fi

if [ ! -f "images/$IMAGE_NAME" ]; then
    base_image_name=""

    mkdir images 2>/dev/null || true
    cd images

    for f in fedora-coreos-*.qcow2; do
        base_image_name="$f"
        break
    done

    pwd
    echo "$base_image_name"

    if [ -z "$base_image_name" ]; then
        echo "Could not find base image at images/fedora-coreos-*.qcow2"
        exit 1
    fi

    qemu-img create -f qcow2 -F qcow2 -b "$base_image_name" "$IMAGE_NAME"
    ssh-keygen -R "$IP_ADDRESS"

    rm "$TOKEN_FILE" || true

    cd ..
fi

if [ ! -f "$TOKEN_FILE" ]; then
    ssh core@10.10.10.10 sudo kubeadm token create >"$TOKEN_FILE"
fi

if [ ! -f "$IGNITION_CONFIG" ]; then
    yq ".passwd.users[0].ssh_authorized_keys = [\"$SSH_PUBLIC_KEY\"]" "$BUTANE_CONFIG" >"$BUTANE_CONFIG.temp"

    if ! butane --strict --files-dir . "$BUTANE_CONFIG.temp" >"$IGNITION_CONFIG"; then
        rm "$BUTANE_CONFIG.temp"
        rm "$IGNITION_CONFIG" || true
        exit 1
    fi

    rm "$BUTANE_CONFIG.temp"
fi

nohup qemu-system-x86_64 -enable-kvm -m "$MEMORY_SIZE" -smp "$CPU_COUNT" -cpu host -nographic \
    -drive if=virtio,file=images/${IMAGE_NAME} \
    -fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG} \
    -device virtio-net-pci,netdev=tap-dev,mac=$NODE_MAC \
    -netdev tap,id=tap-dev,ifname=$NET_INTERFACE,script=no,downscript=no >"$LOG_FILE" &
disown

vm_pid="$!"

echo "$vm_pid" >"$PID_FILE"

tail -f "$LOG_FILE" &

logs_pid="$!"

until ssh -o StrictHostKeyChecking=accept-new core@$IP_ADDRESS exit; do
    sleep 10
done

kill "$logs_pid"

# wait until dependencies are installed and system rebooted
if ! ssh core@$IP_ADDRESS test -f /var/lib/rpm-ostree-install-deps.stamp; then
    ssh core@$IP_ADDRESS sudo journalctl -u rpm-ostree-install-deps --follow --no-tail 2>/dev/null || true

    echo "Waiting for VM"
    sleep 10
    until ssh core@$IP_ADDRESS exit 2>/dev/null; do
        echo "Waiting for VM"
        sleep 10
    done
fi

ssh core@$IP_ADDRESS sudo journalctl -u bootstrap-cluster --follow --no-tail 2>/dev/null &

BOOTSTRAP_LOGS_PID=$!

# wait until cluster is setup
ssh core@$IP_ADDRESS 'until test -f /var/lib/bootstrap-cluster.stamp; do echo Waiting > /dev/null; done'

kill $BOOTSTRAP_LOGS_PID

export KUBECONFIG="$(pwd)/bootstrap/config"

kubectl get csr -o yaml | yq '.items.[] | .metadata.name' | xargs kubectl certificate approve
