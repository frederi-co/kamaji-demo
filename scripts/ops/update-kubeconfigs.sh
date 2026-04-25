#!/bin/bash
set -euo pipefail

MGMT_KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kamaji-mgmt.kubeconfig}"

[[ ! -f "$MGMT_KUBECONFIG" ]] && { echo "Error: management kubeconfig not found at $MGMT_KUBECONFIG"; exit 1; }

echo "==> Fetching tenant kubeconfigs from management cluster..."

TENANTS=$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp --all-namespaces --no-headers 2>/dev/null | awk '{print $1}')

if [[ -z "$TENANTS" ]]; then
  echo "  No active tenant control planes found."
  exit 0
fi

mkdir -p "$HOME/.kube"

for ns in $TENANTS; do
  STATUS=$(kubectl --kubeconfig="$MGMT_KUBECONFIG" get tcp "$ns" -n "$ns" --no-headers | awk '{print $4}')
  if [[ "$STATUS" != "Ready" ]]; then
    echo "  ⚠ Skipping $ns — TCP status: $STATUS"
    continue
  fi

  kubectl --kubeconfig="$MGMT_KUBECONFIG" get secret "${ns}-admin-kubeconfig" -n "$ns" \
    -o jsonpath='{.data.admin\.conf}' | base64 --decode > "$HOME/.kube/${ns}-tenant.kubeconfig"
  echo "  ✓ Saved ~/.kube/${ns}-tenant.kubeconfig"
done

echo ""
echo "✓ Done. Tenant kubeconfigs:"
ls ~/.kube/*-tenant.kubeconfig 2>/dev/null | sed 's|.*/||' | sed 's/^/    /'
