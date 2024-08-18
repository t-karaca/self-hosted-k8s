#!/usr/bin/env bash

set -e

./stop-control-plane.sh
./stop-worker1.sh
./stop-worker2.sh
