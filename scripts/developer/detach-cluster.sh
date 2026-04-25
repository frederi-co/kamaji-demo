#!/bin/bash
set -euo pipefail

[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }
DEV=$(cat "$HOME/.kamaji-dev")
MGMT_KUBECONFIG="$HOME/.kube/${DEV}.mgmt.kubeconfig"
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"

echo "==> Detaching worker node for $DEV..."

# 1. Reset WSL kubelet state
echo "  --> Resetting WSL node..."
sudo kubeadm reset -f 2>/dev/null || true
sudo rm -rf /etc/cni/net.d
echo "  ✓ WSL node reset"

# 2. Clean up tenant kubeconfig
[[ -f "$TENANT_KUBECONFIG" ]] && rm -f "$TENANT_KUBECONFIG"
echo "  ✓ Tenant kubeconfig removed"

echo ""
echo "✓ Worker detached for $DEV."
echo "  Control plane remains running — contact ops to deprovision."
echo "  WSL is clean and ready for the next session."
echo ""
echo "  Run ./join-cluster.sh to rejoin the cluster."
