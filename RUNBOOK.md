# Kamaji Demo Runbook

## Overview

Kamaji runs Kubernetes control planes as pods on a single management cluster, enabling developers to self-provision isolated clusters on demand. This runbook covers the full end-to-end flow — from infrastructure setup to developer self-service.

**Where each part is executed:**

| Part | Who | Executed on |
|------|-----|-------------|
| Part 1.1 — Setup management cluster | Ops | SSH into EC2 #1 |
| Part 1.2 — Setup worker node | Ops | SSH into EC2 #2 |
| Part 1.3 — Get ops kubeconfig | Ops | Ops laptop |
| Part 1.4 — Onboard developers | Ops | Ops laptop (or EC2 #1) |
| Part 2 — Developer WSL setup | Developer | Developer WSL |
| Part 3 — Self-service flow | Developer | Developer WSL |

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              EC2 #1 — Management Cluster                 │
│              54.169.253.180                              │
│                                                          │
│  k3s + cert-manager + Kamaji controller + etcd           │
│  Kamaji Console → http://54.169.253.180:30080/ui         │
│                                                          │
│  ┌─────────────────┐  ┌─────────────────┐               │
│  │  dev-alice TCP  │  │  dev-bryan TCP  │  ...          │
│  │  :31001 (API)   │  │  :31003 (API)   │               │
│  │  :31002 (proxy) │  │  :31004 (proxy) │               │
│  └────────┬────────┘  └────────┬────────┘               │
└───────────┼────────────────────┼────────────────────────┘
            │  kubeadm join      │  kubeadm join
┌───────────▼────────┐  ┌────────▼───────────────────────┐
│  dev-alice WSL     │  │  dev-bryan WSL                 │
│  (worker node)     │  │  (worker node)                 │
└────────────────────┘  └────────────────────────────────┘
```

---

## Infrastructure

| Machine  | Role               | IP             | Spec                          |
|----------|--------------------|----------------|-------------------------------|
| EC2 #1   | Management cluster | 54.169.253.180 | t3.medium, Ubuntu 22.04       |
| EC2 #2   | Standby worker     | 54.169.64.59   | t3.medium, Ubuntu 22.04       |
| WSL      | Developer worker   | Dynamic        | Ubuntu 22.04, systemd enabled |

SSH key: `C:\Users\frederick.foong\Downloads\kamaji.pem`

```bash
# Copy PEM to Linux filesystem (WSL NTFS can't hold correct permissions)
cp /mnt/c/Users/frederick.foong/Downloads/kamaji.pem /tmp/kamaji.pem
chmod 600 /tmp/kamaji.pem

# Convenience aliases
alias ssh-mgmt="ssh -i /tmp/kamaji.pem ubuntu@54.169.253.180"
alias ssh-worker="ssh -i /tmp/kamaji.pem ubuntu@54.169.64.59"
```

---

## EC2 Security Groups

### EC2 #1 (Management) — inbound rules
| Port  | Protocol | Purpose                          |
|-------|----------|----------------------------------|
| 22    | TCP      | SSH                              |
| 6443  | TCP      | k3s API (ops + developer kubectl)|
| 30080 | TCP      | Kamaji Console UI                |
| 30888 | TCP      | Demo app NodePort                |
| 31001 | TCP      | dev-alice API server             |
| 31002 | TCP      | dev-alice konnectivity           |
| 31003 | TCP      | dev-bryan API server             |
| 31004 | TCP      | dev-bryan konnectivity           |
| 31005 | TCP      | dev-charlie API server           |
| 31006 | TCP      | dev-charlie konnectivity         |

### EC2 #2 (Worker) — inbound rules
| Port  | Protocol | Purpose                          |
|-------|----------|----------------------------------|
| 22    | TCP      | SSH                              |
| 10250 | TCP      | kubelet API                      |

---

## Scripts Reference

All scripts live in `kamaji/scripts/` (local) and `~/scripts/` (on EC2 #1).

| Script                          | Run by    | Executed on          | When               | Purpose                                    |
|---------------------------------|-----------|----------------------|--------------------|--------------------------------------------|
| `ops/setup-management.sh`       | Ops       | EC2 #1 (SSH)         | Once               | Full management cluster setup              |
| `ops/setup-worker.sh`           | Ops       | EC2 #2 (SSH)         | Once per worker    | Prepare standby worker node                |
| `ops/provision-developer.sh`    | Ops       | Ops laptop or EC2 #1 | Once per developer | Create RBAC + kubeconfig + TCP manifest    |
| `developer/setup-wsl.sh`        | Developer | Developer WSL        | Once               | Install prereqs, pre-pull images           |
| `developer/new-cluster.sh`      | Developer | Developer WSL        | Each test session  | Provision cluster + join WSL as worker     |
| `developer/deploy-app.sh`       | Developer | Developer WSL        | After new-cluster  | Deploy demo app                            |
| `developer/change-env.sh`       | Developer | Developer WSL        | During testing     | Change app colour/label live               |
| `developer/destroy-cluster.sh`  | Developer | Developer WSL        | End of session     | Delete cluster + reset WSL                 |

---

## Part 1 — Ops Setup (done once)

### Step 1.1 — Setup management cluster
> **Executed on: EC2 #1 (SSH in first)**

```bash
ssh -i /tmp/kamaji.pem ubuntu@54.169.253.180

# Upload scripts first, then run:
bash ~/scripts/ops/setup-management.sh 54.169.253.180 admin123
```

This installs: k3s → kubectl config → Helm → cert-manager → Kamaji → kubeadm → Kamaji Console → ops kubeconfig

**Verify:**
```bash
kubectl get nodes                      # management node Ready
kubectl -n kamaji-system get pods      # kamaji + 3x etcd Running
# Open browser: http://54.169.253.180:30080/ui
```

---

### Step 1.2 — Setup standby worker node
> **Executed on: EC2 #2 (SSH in first)**

```bash
ssh -i /tmp/kamaji.pem ubuntu@54.169.64.59
bash setup-worker.sh
```

This installs containerd, kubelet/kubeadm/kubectl v1.30, and pre-pulls all images.
Node sits idle — ready to join any tenant cluster in seconds.

---

### Step 1.3 — Get ops kubeconfig
> **Executed on: Ops laptop**

Copy the ops kubeconfig (auto-generated by `setup-management.sh` with the public IP already substituted):

```bash
scp -i /tmp/kamaji.pem ubuntu@54.169.253.180:/home/ubuntu/kamaji-ops.kubeconfig \
  ~/.kube/kamaji-mgmt.kubeconfig

export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig
kubectl get nodes   # verify access to management cluster
```

---

### Step 1.4 — Onboard developers
> **Executed on: Ops laptop** (or EC2 #1 if preferred)
> Requires: `KUBECONFIG` pointing to management cluster (Step 1.3)

```bash
export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig

bash scripts/ops/provision-developer.sh dev-alice
bash scripts/ops/provision-developer.sh dev-bryan
bash scripts/ops/provision-developer.sh dev-charlie
```

Each developer gets two files in `./output/`:
- `<dev-name>-mgmt.kubeconfig` — restricted kubectl access to their namespace only
- `<dev-name>-tcp.yaml` — their TenantControlPlane manifest

| Developer   | API Port | Konnectivity | Pod CIDR      | Svc CIDR      |
|-------------|----------|--------------|---------------|---------------|
| dev-alice   | 31001    | 31002        | 10.100.0.0/16 | 10.101.0.0/16 |
| dev-bryan   | 31003    | 31004        | 10.102.0.0/16 | 10.103.0.0/16 |
| dev-charlie | 31005    | 31006        | 10.104.0.0/16 | 10.105.0.0/16 |

Send each developer their two files (email, Slack, shared drive).

---

## Part 2 — Developer Setup (done once per developer)
> **Executed on: Developer WSL**

Developer receives from Ops:
- `dev-alice-mgmt.kubeconfig`
- `dev-alice-tcp.yaml`

Copy them to the Windows Downloads folder, then run in WSL:

```bash
bash /mnt/c/Users/<user>/Documents/RFK/kamaji/scripts/developer/setup-wsl.sh \
  dev-alice \
  /mnt/c/Users/<user>/Downloads/dev-alice-mgmt.kubeconfig \
  /mnt/c/Users/<user>/Downloads/dev-alice-tcp.yaml
```

What it does:
1. Checks systemd is running and swap is off
2. Installs containerd, kubelet, kubeadm, kubectl v1.30
3. Pre-pulls all required images (~3 min first time, instant after)
4. Saves mgmt kubeconfig to `~/.kube/mgmt.kubeconfig`
5. Saves TCP manifest to `~/.kube/<dev-name>-tcp.yaml`
6. Copies all developer scripts to `~/kamaji-scripts/`
7. Saves developer identity to `~/.kamaji-dev`

**WSL systemd check** — if not already enabled, add to `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```
Then restart WSL from Windows PowerShell: `wsl --shutdown`

---

## Part 3 — Developer Self-Service Flow (each test session)
> **Executed on: Developer WSL**
> All commands run from `~/kamaji-scripts/`

### Step 3.1 — Provision cluster

```bash
cd ~/kamaji-scripts
./new-cluster.sh
```

What happens:
1. Creates TenantControlPlane on management cluster (~16 seconds)
2. Fetches tenant kubeconfig to `~/.kube/<dev>-tenant.kubeconfig`
3. Resets any previous WSL node state
4. Joins WSL as worker node (~30 seconds, images already cached)
5. Installs Calico CNI
6. Waits for node Ready

**Expected output:**
```
✓ Control plane ready in 16 seconds
✓ Cluster ready for dev-alice!
  Control plane: https://54.169.253.180:31001
  Worker node:   rzb-sg-e290
Next: run ./deploy-app.sh to deploy the demo application
```

---

### Step 3.2 — Deploy demo app

```bash
./deploy-app.sh
# With custom colour and label:
./deploy-app.sh '#1a73e8' Development
```

**Expected output:**
```
✓ Demo app deployed for dev-alice!
  Access URL: http://172.23.13.83:30888
```

Open the URL in your browser — shows developer name, background colour, environment badge.

---

### Step 3.3 — Change environment (simulate promotion)

```bash
./change-env.sh '#f57c00' Staging
./change-env.sh '#e53935' Production
./change-env.sh '#2e7d32' Testing
```

Colour presets:
| Colour | Hex       | Suggested label |
|--------|-----------|-----------------|
| Blue   | `#1a73e8` | Development     |
| Green  | `#2e7d32` | Testing         |
| Orange | `#f57c00` | Staging         |
| Red    | `#e53935` | Production      |
| Purple | `#6a1b9a` | Hotfix          |

Refresh browser — colour and label update instantly without reprovisioning the cluster.

---

### Step 3.4 — Destroy cluster

```bash
./destroy-cluster.sh
```

What happens:
1. Deletes TenantControlPlane from management cluster
2. Resets WSL kubelet state (ready for next session)
3. Removes tenant kubeconfig

**Expected output:**
```
✓ Cluster destroyed for dev-alice.
  WSL is clean and ready for the next session.
  Run ./new-cluster.sh to provision a new cluster.
```

---

## Demo Talking Points

### Show multiple control planes on one node
> **Run on: EC2 #1 or ops laptop**

```bash
# All tenant control planes are just pods on the management cluster
kubectl get pods -n dev-alice
kubectl get pods -n dev-bryan
kubectl get pods -n dev-charlie

kubectl get tcp --all-namespaces
```

> "Each developer has a fully isolated Kubernetes cluster. All the control planes run as pods on this single EC2 — not separate VMs."

---

### Show tenant isolation
> **Run on: EC2 #1 or ops laptop**

```bash
kubectl --kubeconfig=~/.kube/dev-alice-tenant.kubeconfig get pods -A
kubectl --kubeconfig=~/.kube/dev-bryan-tenant.kubeconfig get pods -A
```

> "dev-alice can't see dev-bryan's workloads. Completely isolated clusters, same management node."

---

### Show provisioning speed
> **Run on: Developer WSL**

```bash
time ./new-cluster.sh
# Expected: ~2 min total (16s control plane + ~30s worker join)
# vs. 15+ minutes for a new EKS cluster
```

> "From zero to a working Kubernetes cluster in under 2 minutes."

---

## Verification Checklist

```bash
# On EC2 #1 or ops laptop
kubectl -n kamaji-system get pods              # kamaji + 3x etcd Running
kubectl get tcp --all-namespaces               # all developer TCPs Ready

# On developer WSL
kubectl --kubeconfig=~/.kube/<dev>-tenant.kubeconfig get nodes    # WSL node Ready
kubectl --kubeconfig=~/.kube/<dev>-tenant.kubeconfig get pods -A  # calico + coredns Running

# Browser
# http://54.169.253.180:30080/ui  →  admin@kamaji.demo / admin123
```

---

## Cleanup

### Developer destroys their cluster
> **Run on: Developer WSL**
```bash
cd ~/kamaji-scripts && ./destroy-cluster.sh
```

### Ops removes a developer
> **Run on: Ops laptop or EC2 #1**
```bash
kubectl delete namespace dev-alice   # removes TCP, RBAC, secrets, kubeconfig
```

### Full teardown
> **Run on: EC2 #1**
```bash
helm uninstall console -n kamaji-system
helm uninstall kamaji -n kamaji-system
helm uninstall cert-manager -n cert-manager

# Terminate EC2 instances via AWS console
```
