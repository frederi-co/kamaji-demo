#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Kamaji Worker Node Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# Usage: bash setup-ec2-worker.sh <dev-name> <path-to-mgmt-kubeconfig>
# ─────────────────────────────────────────────

SCRIPTS_DIR="$HOME/kamaji-scripts"
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml"

usage() {
  echo "Usage: $0 <dev-name> <path-to-mgmt-kubeconfig>"
  echo "  Example: $0 project-charlie /tmp/project-charlie.mgmt.kubeconfig"
  exit 1
}

[[ $# -lt 2 ]] && usage
DEV=$1
MGMT_KUBECONFIG=$2

[[ ! -f "$MGMT_KUBECONFIG" ]] && { echo "Error: kubeconfig not found at $MGMT_KUBECONFIG"; exit 1; }

echo ""
echo "════════════════════════════════════════════"
echo "  Kamaji Worker Node Setup"
echo "  Host: $(hostname)"
echo "  Tenant: $DEV"
echo "════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────
# Step 1 — System prerequisites
# ─────────────────────────────────────────────
echo "── Step 1: System prerequisites"
sudo swapoff -a 2>/dev/null || true
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
# Step 6 — Tenant onboarding
# ─────────────────────────────────────────────
echo ""
echo "── Step 6: Tenant onboarding ($DEV)"

mkdir -p "$HOME/.kube"
cp "$MGMT_KUBECONFIG" "$HOME/.kube/${DEV}.mgmt.kubeconfig"
echo "  ✓ mgmt kubeconfig saved to ~/.kube/${DEV}.mgmt.kubeconfig"

curl -fsSL "$CALICO_URL" -o "$HOME/.kube/calico.yaml"
echo "  ✓ calico manifest cached"

mkdir -p "$SCRIPTS_DIR"
SCRIPT_SRC="$(dirname "$0")"
cp "$SCRIPT_SRC/join-cluster.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/deploy-app.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/change-env.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/detach-cluster.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR"/*.sh
echo "  ✓ scripts copied to $SCRIPTS_DIR"

echo "$DEV" > "$HOME/.kamaji-dev"
echo "  ✓ tenant identity saved (~/.kamaji-dev)"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  ✓ Worker node setup complete!"
echo "════════════════════════════════════════════"
echo ""
echo "  Tenant:  $DEV"
echo "  Host:    $(hostname)"
echo ""
echo "  EC2 Security Group — ensure these ports are open:"
echo "    22     TCP   SSH"
echo "    10250  TCP   kubelet API (for kubectl exec/logs)"
echo ""
echo "  Next: run ./kamaji-scripts/join-cluster.sh"
