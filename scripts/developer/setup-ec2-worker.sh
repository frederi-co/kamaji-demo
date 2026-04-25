#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Kamaji Worker Node Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# Usage: bash setup-ec2-worker.sh
# ─────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════"
echo "  Kamaji Worker Node Setup"
echo "  Host: $(hostname)"
echo "════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────
# Step 1 — System prerequisites
# ─────────────────────────────────────────────
echo "── Step 1: System prerequisites"
sudo apt-get update -q
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
echo "  ✓ Prerequisites installed"

# ─────────────────────────────────────────────
# Step 2 — Enable IP forwarding
# ─────────────────────────────────────────────
echo ""
echo "── Step 2: Enabling IP forwarding"
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf || \
  echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf > /dev/null
echo "  ✓ IP forwarding enabled"

# ─────────────────────────────────────────────
# Step 3 — Install containerd
# ─────────────────────────────────────────────
echo ""
echo "── Step 3: Installing containerd"
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "  ✓ containerd installed and configured (SystemdCgroup=true)"

# ─────────────────────────────────────────────
# Step 4 — Install kubelet, kubeadm, kubectl v1.30
# ─────────────────────────────────────────────
echo ""
echo "── Step 4: Installing kubelet, kubeadm, kubectl v1.30"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -q
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
echo "  ✓ kubelet $(kubelet --version | awk '{print $2}') installed and held"

# ─────────────────────────────────────────────
# Step 5 — Pre-pull images
# ─────────────────────────────────────────────
echo ""
echo "── Step 5: Pre-pulling images (this makes joins fast)"
sudo crictl pull registry.k8s.io/pause:3.9
sudo crictl pull registry.k8s.io/kube-proxy:v1.30.0
sudo crictl pull calico/node:v3.24.1
sudo crictl pull calico/cni:v3.24.1
sudo crictl pull calico/kube-controllers:v3.24.1
sudo crictl pull python:3.11-slim
echo "  ✓ All images pre-pulled"
echo ""
echo "  Cached images:"
sudo crictl images | grep -v 'IMAGE ID' | awk '{printf "    %-50s %s\n", $1":"$2, $3}'

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  ✓ Worker node setup complete!"
echo "════════════════════════════════════════════"
echo ""
echo "  This node is ready to join a tenant cluster."
echo ""
echo "  EC2 Security Group — ensure these ports are open:"
echo "    22     TCP   SSH"
echo "    10250  TCP   kubelet API (for kubectl exec/logs)"
echo ""
echo "  To join a tenant cluster, on EC2 #1 run:"
echo "    kubeadm --kubeconfig=~/<tenant>.kubeconfig token create --print-join-command"
echo ""
echo "  Then on this node run the output prefixed with sudo:"
echo "    sudo kubeadm join <mgmt-ip>:<port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
