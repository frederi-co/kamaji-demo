#!/bin/bash
set -euo pipefail

MGMT_IP="54.169.253.180"
CALICO_MANIFEST="$HOME/.kube/calico.yaml"

[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }
DEV=$(cat "$HOME/.kamaji-dev")
MGMT_KUBECONFIG="$HOME/.kube/${DEV}.mgmt.kubeconfig"
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"

echo "==> Provisioning cluster for $DEV..."

# 1. Apply TenantControlPlane
echo "  --> Creating tenant control plane..."
kubectl --kubeconfig="$MGMT_KUBECONFIG" apply -f "$HOME/.kube/${DEV}-tcp.yaml"

# 2. Wait for Ready
echo "  --> Waiting for control plane to be ready (~16 seconds)..."
START=$(date +%s)
for i in $(seq 1 24); do
  STATUS=$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$DEV" -n "$DEV" \
    --no-headers 2>/dev/null | awk '{print $3}' || true)
  [[ "$STATUS" == "Ready" ]] && break
  sleep 5
done
[[ "$STATUS" != "Ready" ]] && { echo "Error: control plane did not become Ready in time"; exit 1; }
END=$(date +%s)
echo "  ✓ Control plane ready in $((END - START)) seconds"

# 3. Fetch tenant kubeconfig
kubectl --kubeconfig="$MGMT_KUBECONFIG" get secret "${DEV}-admin-kubeconfig" \
  -n "$DEV" -o jsonpath='{.data.admin\.conf}' | base64 --decode > "$TENANT_KUBECONFIG"
echo "  ✓ Tenant kubeconfig saved to $TENANT_KUBECONFIG"

# 4. Generate join command
echo "  --> Generating join token..."
JOIN_CMD=$(kubeadm --kubeconfig="$TENANT_KUBECONFIG" token create --print-join-command)

# 5. Reset WSL from any previous join
echo "  --> Resetting previous cluster state..."
sudo kubeadm reset -f 2>/dev/null || true
sudo rm -rf /etc/cni/net.d

# 6. Join cluster
echo "  --> Joining cluster as worker node..."
sudo systemctl start containerd
sleep 2
sudo $JOIN_CMD

# 7. Wait for node to register
echo "  --> Waiting for node to register..."
sleep 5
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
for i in $(seq 1 12); do
  STATUS=$(kubectl --kubeconfig="$TENANT_KUBECONFIG" get node "$NODE" --no-headers 2>/dev/null | awk '{print $2}' || true)
  [[ "$STATUS" == "Ready" || "$STATUS" == "NotReady" ]] && break
  sleep 5
done

# 8. Install Calico CNI
echo "  --> Installing Calico CNI..."
kubectl --kubeconfig="$TENANT_KUBECONFIG" apply -f "$CALICO_MANIFEST" > /dev/null

# 9. Wait for node Ready
echo "  --> Waiting for node to become Ready..."
kubectl --kubeconfig="$TENANT_KUBECONFIG" wait node "$NODE" \
  --for=condition=Ready --timeout=180s

echo ""
echo "✓ Cluster ready for $DEV!"
echo "  Control plane: https://${MGMT_IP}:$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$DEV" -n "$DEV" -o jsonpath='{.spec.networkProfile.port}')"
echo "  Worker node:   $(hostname)"
echo ""
echo "Next: run ./deploy-app.sh to deploy the demo application"
