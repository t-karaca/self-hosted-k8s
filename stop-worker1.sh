#!/usr/bin/env bash

set -e

NODE_NAME="worker1"

IP_ADDRESS="10.10.10.11"

PID_FILE="$NODE_NAME.pid"

# try shutting down gracefully
if ! ssh core@$IP_ADDRESS sudo shutdown 0; then

    # we do not have ssh access to the system, we need to kill the process
    if [ -f "$PID_FILE" ]; then
        node_pid=$(cat "$PID_FILE")

        if [ "$node_pid" -gt "0" ] && ps --pid "$node_pid"; then
            kill "$node_pid"
        fi
    fi
fi
