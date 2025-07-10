#!/usr/bin/env bash
# install_docker_kvm.sh
# Installs Docker Engine + Compose and KVM/libvirt on Ubuntu 22.04 (Jammy).

set -euo pipefail

echo "==> Updating APT and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release software-properties-common

echo "==> Adding Docker’s official repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo tee /etc/apt/keyrings/docker.asc >/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "==> Installing Docker Engine, Buildx, and Compose plug-ins..."
sudo apt-get update
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin docker-compose

echo "==> Enabling and starting Docker..."
sudo systemctl enable --now docker

echo "==> Installing KVM/libvirt stack..."
# Ensure 'universe' is enabled for cpu-checker; uncomment next line if needed.
# sudo add-apt-repository universe
sudo apt-get install -y \
  qemu-kvm libvirt-daemon-system virtinst bridge-utils cpu-checker

echo "==> Adding ${USER} to useful groups (docker, libvirt, kvm)..."
sudo usermod -aG docker  "${USER}"
sudo usermod -aG libvirt "${USER}"
sudo usermod -aG kvm     "${USER}"

echo "==> Verifying hardware virtualization support..."
sudo kvm-ok || true

cat <<'EOF'

=================  Finished  =================
• Docker:  test with  sudo docker run --rm hello-world
• KVM:     list VMs with  sudo virsh list --all
• Groups:  log out & back in (or run 'newgrp docker && newgrp libvirt')
==============================================
EOF
