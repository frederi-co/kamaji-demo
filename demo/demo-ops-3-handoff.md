# Demo — Ops Lane Step 3: Hand Off to Developer

> **Who**: Ops  
> **Where**: Ops WSL  
> **When**: After provisioning tenant

---

## Prerequisites

- Tenant provisioned (Step 2 complete)
- `dev-alice-mgmt.kubeconfig` exists in `~/kamaji-demo/output/`

---

## Files to Send

| File | Purpose |
|------|---------|
| `dev-alice-mgmt.kubeconfig` | Developer's access to management cluster |

**Scripts already available in the repo** (developer clones the repo themselves):
- `setup-wsl.sh` — one-time WSL setup
- `setup-ec2-worker.sh` — one-time EC2 worker setup (if using EC2)
- `setup-kubectl-tools.sh` — kubectl bash completion and k alias
- `join-cluster.sh` — join worker to control plane
- `detach-cluster.sh` — detach worker when done

---

## Steps

**1. Copy kubeconfig to a shared location**

Via SCP to developer's machine:
```bash
scp ~/kamaji-demo/output/dev-alice-mgmt.kubeconfig <developer-machine>:~/Downloads/
```

Or share via email, Slack, or shared drive.

**2. Confirm developer has received the file**

Developer should place it at:
```
C:\Users\<username>\Downloads\dev-alice-mgmt.kubeconfig
```

**3. Direct developer to the developer guide**
```
https://github.com/frederi-co/kamaji-demo/blob/main/docs/developer-guide.md
```
