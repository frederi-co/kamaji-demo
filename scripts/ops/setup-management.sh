#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Kamaji Management Cluster Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# Usage: bash setup-management.sh <public-ip> [console-password]
# ─────────────────────────────────────────────

usage() {
  echo "Usage: $0 <public-ip> [console-password]"
  echo "  Example: $0 52.221.159.116 admin123"
  exit 1
}

[[ $# -lt 1 ]] && usage

MGMT_IP="$1"
CONSOLE_EMAIL="admin@kamaji.demo"
CONSOLE_PASSWORD="${2:-}"

if [[ -z "$CONSOLE_PASSWORD" ]]; then
  read -rsp "Enter Kamaji Console password: " CONSOLE_PASSWORD
  echo ""
fi

echo ""
echo "════════════════════════════════════════════"
echo "  Kamaji Management Cluster Setup"
echo "  Management IP: $MGMT_IP"
echo "════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────
# Step 1 — System prerequisites
# ─────────────────────────────────────────────
echo "── Step 1: System prerequisites"
sudo apt-get update -q
sudo apt-get install -y apt-transport-https ca-certificates curl gpg jq bash-completion
echo "  ✓ System prerequisites installed"

# ─────────────────────────────────────────────
# Step 2 — Install k3s
# ─────────────────────────────────────────────
echo ""
echo "── Step 2: Installing k3s"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -

sudo mkdir -p /home/ubuntu/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube

grep -q 'KUBECONFIG' /home/ubuntu/.bashrc || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.bashrc
grep -q 'KUBECONFIG' /home/ubuntu/.profile || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.profile

export KUBECONFIG=/home/ubuntu/.kube/config
kubectl wait node --all --for=condition=Ready --timeout=60s
echo "  ✓ k3s installed and node Ready"

# ─────────────────────────────────────────────
# Step 3 — Configure kubectl
# ─────────────────────────────────────────────
echo ""
echo "── Step 3: Configuring kubectl"
grep -q 'kubectl completion bash' /home/ubuntu/.bashrc || cat >> /home/ubuntu/.bashrc << 'EOF'

# kubectl autocomplete
source <(kubectl completion bash)

# k alias with autocomplete
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
echo "  ✓ kubectl bash completion and k alias configured"

# ─────────────────────────────────────────────
# Step 4 — Install Helm
# ─────────────────────────────────────────────
echo ""
echo "── Step 4: Installing Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "  ✓ Helm installed"

# ─────────────────────────────────────────────
# Step 5 — Install cert-manager
# ─────────────────────────────────────────────
echo ""
echo "── Step 5: Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=120s
echo "  ✓ cert-manager installed and Ready"

# ─────────────────────────────────────────────
# Step 6 — Install Kamaji
# ─────────────────────────────────────────────
echo ""
echo "── Step 6: Installing Kamaji"
helm repo add clastix https://clastix.github.io/charts
helm repo update
helm install kamaji clastix/kamaji \
  --namespace kamaji-system \
  --create-namespace

kubectl -n kamaji-system rollout status deploy/kamaji --timeout=120s
echo "  ✓ Kamaji controller installed and Ready"
echo "  ✓ etcd pods:"
kubectl -n kamaji-system get pods | grep etcd

# ─────────────────────────────────────────────
# Step 7 — Install kubeadm v1.30
# ─────────────────────────────────────────────
echo ""
echo "── Step 7: Installing kubeadm v1.30"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -q
sudo apt-get install -y kubeadm
echo "  ✓ kubeadm installed"

# ─────────────────────────────────────────────
# Step 8 — Install Kamaji Console
# ─────────────────────────────────────────────
echo ""
echo "── Step 8: Installing Kamaji Console"
JWT_SECRET=$(openssl rand -hex 32)

kubectl create secret generic kamaji-console \
  --namespace kamaji-system \
  --from-literal=ADMIN_EMAIL="$CONSOLE_EMAIL" \
  --from-literal=ADMIN_PASSWORD="$CONSOLE_PASSWORD" \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --from-literal=NEXTAUTH_URL="http://${MGMT_IP}:30080/ui"

helm install console clastix/kamaji-console \
  --namespace kamaji-system

kubectl -n kamaji-system rollout status deploy/console-kamaji-console --timeout=120s

# Expose via NodePort 30080
kubectl -n kamaji-system patch svc console-kamaji-console \
  -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":3000,"nodePort":30080}]}}'

echo "  ✓ Kamaji Console installed and exposed on port 30080"

# ─────────────────────────────────────────────
# Step 9 — Generate ops kubeconfig (public IP)
# ─────────────────────────────────────────────
echo ""
echo "── Step 9: Generating ops kubeconfig"
sed "s/127.0.0.1/${MGMT_IP}/g" /home/ubuntu/.kube/config | \
  sed 's/certificate-authority-data:.*/insecure-skip-tls-verify: true/' > /home/ubuntu/kamaji-ops.kubeconfig
chmod 600 /home/ubuntu/kamaji-ops.kubeconfig
echo "  ✓ Ops kubeconfig saved to ~/kamaji-ops.kubeconfig"
echo "  To copy to your ops laptop:"
echo "    scp -i <key.pem> ubuntu@${MGMT_IP}:/home/ubuntu/kamaji-ops.kubeconfig ~/.kube/kamaji-mgmt.kubeconfig"

# ─────────────────────────────────────────────
# Step 10 — Copy scripts
# ─────────────────────────────────────────────
echo ""
echo "── Step 10: Installing ops scripts"
mkdir -p /home/ubuntu/scripts/ops /home/ubuntu/scripts/developer
SCRIPT_DIR="$(dirname "$0")"
cp "$SCRIPT_DIR/provision-tenant.sh" /home/ubuntu/scripts/ops/
cp "$SCRIPT_DIR/deprovision-tenant.sh" /home/ubuntu/scripts/ops/
cp "$SCRIPT_DIR/../developer/"*.sh /home/ubuntu/scripts/developer/
chmod +x /home/ubuntu/scripts/ops/*.sh /home/ubuntu/scripts/developer/*.sh
echo "  ✓ Scripts installed to ~/scripts/"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  ✓ Management cluster setup complete!"
echo "════════════════════════════════════════════"
echo ""
echo "  k3s API server:    https://${MGMT_IP}:6443"
echo "  Kamaji Console:    http://${MGMT_IP}:30080/ui"
echo "  Console login:     $CONSOLE_EMAIL / $CONSOLE_PASSWORD"
echo ""
echo "  EC2 #1 Security Group — ensure these ports are open:"
echo "    22     SSH"
echo "    6443   k3s API (developer kubectl access)"
echo "    30080  Kamaji Console"
echo "    30888  Demo app NodePort"
echo "    31001  dev-alice API server"
echo "    31002  dev-alice konnectivity"
echo "    31003  dev-bryan API server"
echo "    31004  dev-bryan konnectivity"
echo "    31005  dev-charlie API server"
echo "    31006  dev-charlie konnectivity"
echo ""
echo "  Next steps:"
echo "    1. Open the ports above in the EC2 security group"
echo "    2. Copy ops kubeconfig to your laptop:"
echo "         scp -i <key.pem> ubuntu@${MGMT_IP}:/home/ubuntu/kamaji-ops.kubeconfig ~/.kube/kamaji-mgmt.kubeconfig"
echo "         export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig"
echo "    3. Provision tenants (from ops laptop or EC2 #1):"
echo "         bash provision-tenant.sh dev-alice"
echo "         bash provision-tenant.sh dev-bryan"
echo "         bash provision-tenant.sh dev-charlie"
echo "    4. Send each developer their <dev-name>-mgmt.kubeconfig"
echo "    5. Developer runs: bash setup-wsl.sh <dev-name> <mgmt-kubeconfig>"
