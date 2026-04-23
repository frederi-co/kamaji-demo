#!/bin/bash
set -euo pipefail

MGMT_IP="54.169.253.180"
K8S_VERSION="v1.30.0"

declare -A API_PORT=( [dev-alice]=31001 [dev-bryan]=31003 [dev-charlie]=31005 )
declare -A PROXY_PORT=( [dev-alice]=31002 [dev-bryan]=31004 [dev-charlie]=31006 )
declare -A POD_CIDR=( [dev-alice]="10.100.0.0/16" [dev-bryan]="10.102.0.0/16" [dev-charlie]="10.104.0.0/16" )
declare -A SVC_CIDR=( [dev-alice]="10.101.0.0/16" [dev-bryan]="10.103.0.0/16" [dev-charlie]="10.105.0.0/16" )
declare -A DNS_SVC=( [dev-alice]="10.101.0.10" [dev-bryan]="10.103.0.10" [dev-charlie]="10.105.0.10" )

usage() {
  echo "Usage: $0 <dev-name>"
  echo "  dev-name: dev-alice | dev-bryan | dev-charlie"
  exit 1
}

[[ $# -lt 1 ]] && usage
DEV=$1

[[ -z "${API_PORT[$DEV]+_}" ]] && { echo "Unknown developer: $DEV"; usage; }

echo "==> Onboarding $DEV on management cluster..."

# 1. Create namespace
kubectl create namespace "$DEV" --dry-run=client -o yaml | kubectl apply -f -

# 2. Create ServiceAccount
kubectl create serviceaccount "${DEV}-sa" -n "$DEV" --dry-run=client -o yaml | kubectl apply -f -

# 3. Create Role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${DEV}-role
  namespace: ${DEV}
rules:
  - apiGroups: ["kamaji.clastix.io"]
    resources: ["tenantcontrolplanes"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
EOF

# 4. Create RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${DEV}-rolebinding
  namespace: ${DEV}
subjects:
  - kind: ServiceAccount
    name: ${DEV}-sa
    namespace: ${DEV}
roleRef:
  kind: Role
  name: ${DEV}-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 5. Generate kubeconfig from ServiceAccount token
TOKEN=$(kubectl create token "${DEV}-sa" -n "$DEV" --duration=8760h)
SERVER="https://${MGMT_IP}:6443"

mkdir -p ./output
cat > "./output/${DEV}-mgmt.kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: kamaji-mgmt
    cluster:
      server: ${SERVER}
      insecure-skip-tls-verify: true
contexts:
  - name: ${DEV}-context
    context:
      cluster: kamaji-mgmt
      namespace: ${DEV}
      user: ${DEV}-sa
current-context: ${DEV}-context
users:
  - name: ${DEV}-sa
    user:
      token: ${TOKEN}
EOF

# 6. Create TenantControlPlane manifest
cat > "./output/${DEV}-tcp.yaml" <<EOF
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: ${DEV}
  namespace: ${DEV}
  labels:
    tenant.clastix.io: ${DEV}
spec:
  dataStore: default
  controlPlane:
    deployment:
      replicas: 1
    service:
      serviceType: NodePort
  kubernetes:
    version: ${K8S_VERSION}
    kubelet:
      cgroupfs: systemd
    admissionControllers:
      - ResourceQuota
      - LimitRanger
  networkProfile:
    address: "${MGMT_IP}"
    port: ${API_PORT[$DEV]}
    serviceCidr: ${SVC_CIDR[$DEV]}
    podCidr: ${POD_CIDR[$DEV]}
    dnsServiceIPs:
      - ${DNS_SVC[$DEV]}
  addons:
    coreDNS: {}
    kubeProxy: {}
    konnectivity:
      server:
        port: ${PROXY_PORT[$DEV]}
EOF

echo ""
echo "✓ Developer $DEV onboarded successfully!"
echo ""
echo "Files created in ./output/:"
echo "  ${DEV}-mgmt.kubeconfig  — send this to the developer"
echo "  ${DEV}-tcp.yaml         — TenantControlPlane manifest"
echo ""
echo "Next steps for $DEV:"
echo "  1. Copy ${DEV}-mgmt.kubeconfig to their WSL machine"
echo "  2. Run: ./setup-wsl.sh ${DEV} <path-to-${DEV}-mgmt.kubeconfig>"
