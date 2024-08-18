#!/usr/bin/env bash

set -euo pipefail

echo "Waiting for VM"
until ssh -o StrictHostKeyChecking=accept-new core@10.10.10.10 exit; do
    echo "Waiting for VM"
    sleep 10
done

if ! ssh core@10.10.10.10 test -f /var/lib/rpm-ostree-install-deps.stamp; then
    ssh core@10.10.10.10 sudo journalctl -u rpm-ostree-install-deps --follow --no-tail 2>/dev/null || true

    echo "Waiting for VM"
    sleep 10
    until ssh core@10.10.10.10 exit 2>/dev/null; do
        echo "Waiting for VM"
        sleep 10
    done
fi

ssh core@10.10.10.10 sudo journalctl -u bootstrap-cluster --follow --no-tail 2>/dev/null &

BOOTSTRAP_LOGS_PID=$!

ssh core@10.10.10.10 'until test -f $HOME/.kube/config; do echo Waiting > /dev/null; done'

kill $BOOTSTRAP_LOGS_PID

mkdir -p bootstrap
scp core@10.10.10.10:/var/home/core/.kube/config ./bootstrap/config

export KUBECONFIG="$(pwd)/bootstrap/config"

cilium-cli install --version 1.16.1

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server -n kube-system -f metrics-server-values.yaml

kubectl get csr -o yaml | yq '.items.[] | .metadata.name' | xargs kubectl certificate approve
