#!/bin/bash
set -euo pipefail

MGMT_IP="52.221.159.116"
CALICO_MANIFEST="$HOME/.kube/calico.yaml"

[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }
DEV=$(cat "$HOME/.kamaji-dev")
MGMT_KUBECONFIG="$HOME/.kube/${DEV}.mgmt.kubeconfig"
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"

echo "==> Joining cluster for $DEV..."

# 1. Verify control plane is Ready
echo "  --> Checking control plane status..."
STATUS=$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$DEV" -n "$DEV" \
  --no-headers 2>/dev/null | awk '{print $3}' || true)
[[ "$STATUS" != "Ready" ]] && { echo "Error: control plane is not Ready (status: ${STATUS:-not found}). Contact ops."; exit 1; }
echo "  ✓ Control plane is Ready"

# 2. Fetch tenant kubeconfig
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
sudo systemctl start containerd || true
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' | sudo tee /etc/default/kubelet > /dev/null
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
echo "✓ Joined cluster for $DEV!"
echo "  Control plane: https://${MGMT_IP}:$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$DEV" -n "$DEV" -o jsonpath='{.spec.networkProfile.port}')"
echo "  Worker node:   $(hostname)"
echo ""
echo "Next: run ./deploy-app.sh to deploy the demo application"
