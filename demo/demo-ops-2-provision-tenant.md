# Demo — Ops Lane Step 2: Provision Tenant

> **Who**: Ops  
> **Where**: Ops WSL  
> **When**: Once per tenant

---

## Prerequisites

- Ops WSL set up (`setup-ops-wsl.sh` already run)
- Management cluster running on EC2 #1
- `KUBECONFIG` pointing to `~/.kube/kamaji-mgmt.kubeconfig`

---

## Steps

**1. Provision the tenant**
```bash
bash ~/kamaji-scripts/provision-tenant.sh dev-alice
```

This will:
- Create namespace `dev-alice`
- Create ServiceAccount, Role, RoleBinding
- Generate TenantControlPlane manifest (ports, CIDRs)
- Apply TCP to management cluster
- Wait for control plane to be Ready (~16 seconds)
- Generate `dev-alice-mgmt.kubeconfig`

**2. Verify TCP is Ready**
```bash
kubectl get tcp --all-namespaces
```

Expected output:
```
NAMESPACE   NAME        VERSION   STATUS   CONTROL-PLANE ENDPOINT
dev-alice   dev-alice   v1.30.0   Ready    52.221.159.116:31001
```

**3. Verify output file**
```bash
ls ~/kamaji-demo/output/
```

Expected:
```
dev-alice-mgmt.kubeconfig
```
