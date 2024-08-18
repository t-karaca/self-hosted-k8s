# self-hosted-k8s

Setup a Kubernetes Cluster on a Linux Host with QEMU VMs running Fedora CoreOS.
This setup uses kubeadm for a vanilla Kubernetes setup without a special distribution like k3s or Rancher.

## Requirements

The scripts in this repository require following tools to be installed:

- dnsmasq
- qemu
- ssh
- butane
- coreos-installer
- yq
- kubectl
- helm
- cilium-cli

Following settings are required on the host:

- KVM needs to be enabled
- IP Forwarding needs to be enabled
- Masquerading needs to be enabled
- if a firewall is active, then dhcp needs to be allowed (for dnsmasq)

## Setup

To login to the VMs with ssh, you need to create a `.env` file with the following contents:

```bash
SSH_PUBLIC_KEY="<insert public key here>"
```

## Running

### setup-network.sh

This script requires Network Manager to setup the bridge and tap interfaces for the VM network.
If firewalld is installed and active the script will set it up to allow DHCP and enable Masquerading.
After the setup it will start dnsmasq which will be bound on the bridge interface.

### start-all.sh

When dnsmasq is running the VMs can be started using the `start-*.sh` scripts.
The `start-all.sh` script will first start the control-plane VM which will automatically setup a new cluster using a systemd unit.
The VMs are setup using Butane. For the control-plane the config can be found in the `control-plane.bu` file.
The script will also install cilium and metrics-server on the cluster.
When the control-plane is running the 2 worker nodes will be started and automatically joined the cluster.

The kubeconfig file will be exported in this repository to `bootstrap/config`.
So if the repository is located at `~/self-hosted-k8s` then you would need to run

```bash
export KUBECONFIG=~/self-hosted-k8s/bootstrap/config
```

to setup kubectl in the current shell session to access the cluster.
Running `kubectl top nodes` should then return an output like this:

```
NAME            CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
control-plane   72m          3%     1045Mi          56%
worker1         17m          0%     554Mi           29%
worker2         18m          0%     513Mi           27%
```

### stop-all.sh

This script can be used to shutdown the cluster and the VMs.

### clean.sh

When the VMs are not running this script will cleanup the nodes, so the next time
you run the `start-all.sh` script, a fresh new cluster will be setup.

## Configuration

The configuration for the VMs use Butane to transform the `.bu` files to `.ign` files.
If you change any settings in the butane files, make sure to delete the corresponding ignition file
so the start scripts also regenerate the ignition files and apply the new settings.

Since the ignition configuration only applies on the initial boot of the VM you also need to delete
the image file for the node e.g. `images/node-control-plane.qcow2`.
