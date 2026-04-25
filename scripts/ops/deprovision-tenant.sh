#!/bin/bash
set -euo pipefail

declare -A API_PORT=( [dev-alice]=31001 [dev-bryan]=31003 [project-charlie]=31005 )

usage() {
  echo "Usage: $0 <tenant-name>"
  echo "  tenant-name: dev-alice | dev-bryan | project-charlie"
  exit 1
}

[[ $# -lt 1 ]] && usage
DEV=$1

[[ -z "${API_PORT[$DEV]+_}" ]] && { echo "Unknown developer: $DEV"; usage; }

echo "==> Deprovisioning $DEV..."

# 1. Delete TenantControlPlane
if kubectl get tcp "$DEV" -n "$DEV" &>/dev/null; then
  echo "  --> Deleting tenant control plane..."
  kubectl delete tcp "$DEV" -n "$DEV"
  echo "  ✓ Tenant control plane deleted"
else
  echo "  ✓ No active tenant control plane found (already deleted)"
fi

# 2. Delete namespace (removes ServiceAccount, Role, RoleBinding, secrets)
if kubectl get namespace "$DEV" &>/dev/null; then
  echo "  --> Deleting namespace $DEV..."
  kubectl delete namespace "$DEV"
  echo "  ✓ Namespace deleted"
else
  echo "  ✓ Namespace $DEV not found (already deleted)"
fi

echo ""
echo "✓ Tenant $DEV deprovisioned."
