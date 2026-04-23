#!/bin/bash
set -euo pipefail

MGMT_IP="54.169.253.180"
SCRIPTS_DIR="$HOME/kamaji-scripts"
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml"

usage() {
  echo "Usage: $0 <dev-name> <path-to-mgmt-kubeconfig>"
  echo "  Example: $0 dev-alice /tmp/dev-alice-mgmt.kubeconfig"
  exit 1
}

[[ $# -lt 2 ]] && usage
DEV=$1
MGMT_KUBECONFIG=$2

[[ ! -f "$MGMT_KUBECONFIG" ]] && { echo "Error: kubeconfig not found at $MGMT_KUBECONFIG"; exit 1; }

echo "==> Setting up WSL for $DEV..."

# 1. Check systemd
if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
  echo "Error: systemd is not running. Add the following to /etc/wsl.conf and restart WSL:"
  echo "  [boot]"
  echo "  systemd=true"
  exit 1
fi
echo "  ✓ systemd running"

# 2. Disable swap
sudo swapoff -a 2>/dev/null || true
echo "  ✓ swap disabled"

# 3. Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf > /dev/null
echo "  ✓ IP forwarding enabled"

# 4. Install containerd if not present
if ! command -v containerd &>/dev/null; then
  echo "  --> Installing containerd..."
  sudo apt-get update -q
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  sudo systemctl restart containerd
  sudo systemctl enable containerd
fi
echo "  ✓ containerd ready"

# 5. Install kubelet, kubeadm, kubectl v1.30 if not present
if ! command -v kubelet &>/dev/null; then
  echo "  --> Installing kubelet, kubeadm, kubectl..."
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
  sudo apt-get update -q
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
fi
echo "  ✓ kubelet, kubeadm, kubectl ready"

# 6. Pre-pull images
echo "  --> Pre-pulling images (this may take a few minutes on first run)..."
sudo crictl pull registry.k8s.io/pause:3.9 2>/dev/null
sudo crictl pull registry.k8s.io/kube-proxy:v1.30.0 2>/dev/null
sudo crictl pull calico/node:v3.24.1 2>/dev/null
sudo crictl pull calico/cni:v3.24.1 2>/dev/null
sudo crictl pull calico/kube-controllers:v3.24.1 2>/dev/null
echo "  ✓ images pre-pulled"

# 7. Place mgmt kubeconfig
mkdir -p "$HOME/.kube"
cp "$MGMT_KUBECONFIG" "$HOME/.kube/${DEV}.mgmt.kubeconfig"
echo "  ✓ mgmt kubeconfig saved to ~/.kube/${DEV}.mgmt.kubeconfig"

# 8. Download Calico manifest
curl -fsSL "$CALICO_URL" -o "$HOME/.kube/calico.yaml"
echo "  ✓ calico manifest cached"

# 9. Copy developer scripts
mkdir -p "$SCRIPTS_DIR"
SCRIPT_SRC="$(dirname "$0")"
cp "$SCRIPT_SRC/new-cluster.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/deploy-app.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/change-env.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/destroy-cluster.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR"/*.sh
echo "  ✓ scripts copied to $SCRIPTS_DIR"

# 10. Copy TCP manifest if provided as 3rd argument
TCP_MANIFEST="${3:-}"
if [[ -n "$TCP_MANIFEST" && -f "$TCP_MANIFEST" ]]; then
  cp "$TCP_MANIFEST" "$HOME/.kube/${DEV}-tcp.yaml"
  echo "  ✓ TCP manifest saved to ~/.kube/${DEV}-tcp.yaml"
fi

# 11. Save dev name
echo "$DEV" > "$HOME/.kamaji-dev"
echo "  ✓ developer identity saved (~/.kamaji-dev)"

echo ""
echo "✓ WSL setup complete for $DEV!"
echo ""
echo "Available commands (from $SCRIPTS_DIR):"
echo "  ./new-cluster.sh           — provision a new cluster and join this WSL as worker"
echo "  ./deploy-app.sh            — deploy the demo app"
echo "  ./change-env.sh <colour> <label>  — change app environment"
echo "  ./destroy-cluster.sh       — destroy cluster and reset WSL"
