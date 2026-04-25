# Demo — Ops Lane Step 5: Deprovision Tenant

> **Who**: Ops  
> **Where**: Ops WSL  
> **When**: When tenant no longer needs their cluster

---

## Prerequisites

- Ops WSL set up with management cluster access
- Developer has detached their worker (or is aware cluster will be deleted)

---

## Steps

**1. Deprovision the tenant**
```bash
bash ~/kamaji-scripts/deprovision-tenant.sh dev-alice
```

This will:
- Delete the TenantControlPlane
- Delete the namespace (cascades to ServiceAccount, Role, RoleBinding, secrets)

**2. Verify**
```bash
kubectl get tcp --all-namespaces
kubectl get namespace dev-alice
```

Expected: `dev-alice` no longer appears in either list.
