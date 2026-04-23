#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <colour> [label]"
  echo "  By name:   $0 blue"
  echo "  By name:   $0 red Production"
  echo "  By hex:    $0 '#e53935' Production"
  echo ""
  echo "Colour names:"
  echo "  blue    #1a73e8  Development"
  echo "  green   #2e7d32  Testing"
  echo "  orange  #f57c00  Staging"
  echo "  red     #e53935  Production"
  echo "  purple  #6a1b9a  Hotfix"
  exit 1
}

[[ $# -lt 1 ]] && usage
[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }

DEV=$(cat "$HOME/.kamaji-dev")
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"
[[ ! -f "$TENANT_KUBECONFIG" ]] && { echo "Error: no active cluster. Run new-cluster.sh first."; exit 1; }

# Resolve colour name to hex + default label
case "${1,,}" in
  blue)   BG_COLOR="#1a73e8"; DEFAULT_LABEL="Development" ;;
  green)  BG_COLOR="#2e7d32"; DEFAULT_LABEL="Testing"     ;;
  orange) BG_COLOR="#f57c00"; DEFAULT_LABEL="Staging"     ;;
  red)    BG_COLOR="#e53935"; DEFAULT_LABEL="Production"  ;;
  purple) BG_COLOR="#6a1b9a"; DEFAULT_LABEL="Hotfix"      ;;
  *)      BG_COLOR="$1";      DEFAULT_LABEL="Development" ;;
esac

ENV_LABEL="${2:-$DEFAULT_LABEL}"

# Pick a contrasting badge colour based on label
case "${ENV_LABEL,,}" in
  production)  ENV_COLOR="#b71c1c" ;;
  staging)     ENV_COLOR="#e65100" ;;
  testing)     ENV_COLOR="#1b5e20" ;;
  hotfix)      ENV_COLOR="#4a148c" ;;
  *)           ENV_COLOR="#34a853" ;;
esac

echo "==> Updating $DEV cluster environment..."
kubectl --kubeconfig="$TENANT_KUBECONFIG" set env deployment/demo-app \
  BG_COLOR="$BG_COLOR" \
  ENV_LABEL="$ENV_LABEL" \
  ENV_COLOR="$ENV_COLOR"

kubectl --kubeconfig="$TENANT_KUBECONFIG" rollout status deployment/demo-app --timeout=60s

PUBLIC_IP=$(curl -sf --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 || true)
WSL_IP=${PUBLIC_IP:-$(ip route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')}
echo ""
echo "✓ Environment updated to '$ENV_LABEL' (${BG_COLOR})"
echo "  Refresh your browser: http://${WSL_IP}:30888"
