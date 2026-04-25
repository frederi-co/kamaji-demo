# Demo — Tenant Lane Step 2: Join Cluster

> **Who**: Developer / Team Admin  
> **Where**: Developer WSL or EC2 worker  
> **When**: Each session

---

## Prerequisites

- Step 1 (setup) complete
- Control plane provisioned by Ops (Step 2 of Ops lane)

---

## Steps

**1. Join the cluster**
```bash
cd ~/kamaji-scripts
./join-cluster.sh
```

This will:
1. Verify control plane is Ready on management cluster
2. Fetch tenant kubeconfig from management cluster
3. Reset any previous node state
4. Join this machine as a worker node (~30 seconds)
5. Install Calico CNI
6. Wait for node to be Ready

Takes ~2 minutes total.

**Expected output:**
```
✓ Control plane is Ready
✓ Joined cluster for dev-alice!
  Control plane: https://52.221.159.116:31001
  Worker node:   <hostname>
```

---

## Verify

```bash
k get nodes
```

Expected:
```
NAME         STATUS   ROLES    AGE   VERSION
<hostname>   Ready    <none>   ...   v1.30.x
```

---

## Notes

- Re-running `join-cluster.sh` is safe — it resets previous state automatically
- If control plane is not Ready, contact Ops
