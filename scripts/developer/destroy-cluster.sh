#!/bin/bash
set -euo pipefail

[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }
DEV=$(cat "$HOME/.kamaji-dev")
MGMT_KUBECONFIG="$HOME/.kube/${DEV}.mgmt.kubeconfig"
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"

echo "==> Destroying cluster for $DEV..."

# 1. Delete TenantControlPlane from management cluster
if kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$DEV" -n "$DEV" &>/dev/null; then
  echo "  --> Deleting tenant control plane..."
  kubectl --kubeconfig="$MGMT_KUBECONFIG" delete tcp "$DEV" -n "$DEV"
  echo "  ✓ Tenant control plane deleted"
else
  echo "  ✓ No active tenant control plane found (already deleted)"
fi

# 2. Reset WSL kubelet state
echo "  --> Resetting WSL node..."
sudo kubeadm reset -f 2>/dev/null || true
sudo rm -rf /etc/cni/net.d
echo "  ✓ WSL node reset"

# 3. Clean up tenant kubeconfig
[[ -f "$TENANT_KUBECONFIG" ]] && rm -f "$TENANT_KUBECONFIG"
echo "  ✓ Tenant kubeconfig removed"

echo ""
echo "✓ Cluster destroyed for $DEV."
echo "  WSL is clean and ready for the next session."
echo ""
echo "  Run ./new-cluster.sh to provision a new cluster."
