#!/usr/bin/env bash

set -euo pipefail

nodes=("control-plane" "worker1" "worker2")

for node_name in "${nodes[@]}"; do
    rm "$node_name.ign" 2>/dev/null || true
    rm "$node_name.log" 2>/dev/null || true
    rm "$node_name.pid" 2>/dev/null || true
    rm "$node_name.token" 2>/dev/null || true
    rm "images/node-$node_name.qcow2" 2>/dev/null || true
done

rm -r bootstrap/ 2>/dev/null || true
