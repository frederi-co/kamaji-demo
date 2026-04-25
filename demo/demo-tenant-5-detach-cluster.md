# Demo — Tenant Lane Step 5: Detach Cluster

> **Who**: Developer  
> **Where**: Developer WSL or EC2 worker  
> **When**: End of session (optional)

---

## Prerequisites

- Cluster joined and in use
- Tenant kubeconfig exists at `~/.kube/<tenant>-tenant.kubeconfig`

---

## Steps

**1. Detach the worker node**
```bash
cd ~/kamaji-scripts
./detach-cluster.sh
```

This will:
1. Delete node record from tenant cluster
2. Reset the worker node (`kubeadm reset`)
3. Remove CNI config
4. Remove tenant kubeconfig

**Expected output:**
```
✓ Node record removed
✓ WSL node reset
✓ Tenant kubeconfig removed

✓ Worker detached for dev-alice.
  Control plane remains running — contact ops to deprovision.
  WSL is clean and ready for the next session.

  Run ./join-cluster.sh to rejoin the cluster.
```

---

## Notes

- Control plane stays running on EC2 #1 — no action needed from Ops
- To start a new session, just run `./join-cluster.sh` again
- Shutting down WSL without detaching is also fine — `join-cluster.sh` resets state on next run
