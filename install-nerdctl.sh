#!/usr/bin/env bash

set -e

mkdir -p /tmp/download
cd /tmp/download
curl -L -o nerdctl.tar.gz https://github.com/containerd/nerdctl/releases/download/v1.7.5/nerdctl-1.7.5-linux-amd64.tar.gz
tar -xzvf nerdctl.tar.gz nerdctl
cp nerdctl /usr/local/bin/nerdctl
