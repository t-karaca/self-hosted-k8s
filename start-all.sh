#!/usr/bin/env bash

set -e

./start-control-plane.sh
./start-worker1.sh &
./start-worker2.sh &
