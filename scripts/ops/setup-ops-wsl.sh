#!/bin/bash
set -euo pipefail

MGMT_IP="52.221.159.116"
MGMT_KUBECONFIG="$HOME/.kube/kamaji-mgmt.kubeconfig"

echo ""
echo "════════════════════════════════════════════"
echo "  Kamaji Ops WSL Setup"
echo "════════════════════════════════════════════"
echo ""

# 1. Check systemd
if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
  echo "Error: systemd is not running. Add the following to /etc/wsl.conf and restart WSL:"
  echo "  [boot]"
  echo "  systemd=true"
  exit 1
fi
echo "  ✓ systemd running"

# 2. Install kubectl
if ! command -v kubectl &>/dev/null; then
  echo "  --> Installing kubectl v1.30..."
  sudo apt-get update -q
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL --insecure https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
  sudo apt-get update -q
  sudo apt-get install -y kubectl
fi
echo "  ✓ kubectl ready ($(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1))"

# 3. Configure kubectl bash completion and k alias
grep -q 'kubectl completion bash' "$HOME/.bashrc" || cat >> "$HOME/.bashrc" << 'EOF'

# kubectl autocomplete
source <(kubectl completion bash)

# k alias with autocomplete
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
echo "  ✓ kubectl bash completion and k alias configured"

# 4. Fetch ops kubeconfig from EC2 #1
echo ""
echo "  --> Fetching ops kubeconfig from EC2 #1..."

PEM_FILE=""
for candidate in /tmp/kamaji.pem "$HOME/.ssh/kamaji.pem" /mnt/c/Users/*/Downloads/kamaji.pem; do
  if [[ -f "$candidate" ]]; then
    PEM_FILE="$candidate"
    break
  fi
done

if [[ -z "$PEM_FILE" ]]; then
  echo "Error: kamaji.pem not found. Copy it first:"
  echo "  cp /mnt/c/Users/<username>/Downloads/kamaji.pem /tmp/kamaji.pem"
  echo "  chmod 600 /tmp/kamaji.pem"
  exit 1
fi

chmod 600 "$PEM_FILE"
mkdir -p "$HOME/.kube"
scp -i "$PEM_FILE" -o StrictHostKeyChecking=no \
  ubuntu@${MGMT_IP}:/home/ubuntu/kamaji-ops.kubeconfig "$MGMT_KUBECONFIG"
chmod 600 "$MGMT_KUBECONFIG"
echo "  ✓ Ops kubeconfig saved to $MGMT_KUBECONFIG"

# 5. Set KUBECONFIG in shell profile
grep -q 'kamaji-mgmt.kubeconfig' "$HOME/.bashrc" || \
  echo "export KUBECONFIG=$MGMT_KUBECONFIG" >> "$HOME/.bashrc"
export KUBECONFIG="$MGMT_KUBECONFIG"
echo "  ✓ KUBECONFIG set in ~/.bashrc"

# 6. Copy ops scripts
SCRIPTS_DIR="$HOME/kamaji-scripts"
mkdir -p "$SCRIPTS_DIR"
SCRIPT_SRC="$(dirname "$0")"
cp "$SCRIPT_SRC/provision-tenant.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/deprovision-tenant.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_SRC/update-kubeconfigs.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR"/*.sh
echo "  ✓ Ops scripts copied to $SCRIPTS_DIR"

# 7. Fetch tenant kubeconfigs
echo ""
echo "  --> Fetching tenant kubeconfigs..."
bash "$SCRIPT_SRC/update-kubeconfigs.sh"

# 8. Verify
echo ""
echo "  --> Verifying management cluster access..."
kubectl get nodes
echo ""
kubectl get tcp --all-namespaces

echo ""
echo "════════════════════════════════════════════"
echo "  ✓ Ops WSL setup complete!"
echo "════════════════════════════════════════════"
echo ""
echo "  Management cluster: https://${MGMT_IP}:6443"
echo "  Kamaji Console:     http://${MGMT_IP}:30080/ui"
echo ""
echo "  Available commands (from $SCRIPTS_DIR):"
echo "    ./provision-tenant.sh <tenant>    — provision a new tenant"
echo "    ./deprovision-tenant.sh <tenant>  — deprovision a tenant"
echo "    ./update-kubeconfigs.sh           — refresh all tenant kubeconfigs"
echo ""
echo "  Run 'source ~/.bashrc' to apply shell changes in this session."
