# Demo — Ops Lane Step 4: Monitor via Kamaji Console

> **Who**: Ops  
> **Where**: Browser / Ops WSL  
> **When**: After tenants are provisioned

---

## Kamaji Console

```
URL:   http://52.221.159.116:30080/ui
Login: admin@kamaji.demo / admin123
```

Shows all TenantControlPlanes, their status, and Kubernetes version.

---

## CLI Monitoring

**Check all tenant control planes:**
```bash
kubectl get tcp --all-namespaces
```

**Check pods for a specific tenant:**
```bash
kubectl get pods -n dev-alice
```

**Check worker nodes on a tenant cluster:**
```bash
kubectl --kubeconfig=~/.kube/dev-alice-tenant.kubeconfig get nodes
```

**Check all workloads on a tenant cluster:**
```bash
kubectl --kubeconfig=~/.kube/dev-alice-tenant.kubeconfig get pods -A
```

**Refresh all tenant kubeconfigs:**
```bash
bash ~/kamaji-scripts/update-kubeconfigs.sh
```
