# Developer Guide — Kamaji Self-Service Clusters

This guide walks you through setting up your personal Kubernetes cluster and running the demo app.

---

## What You Need From Ops

Ops will assign you a developer username (e.g. `dev-alice`) and send you two files named after it. This username is your identity throughout — it scopes your cluster, your RBAC access, and your kubeconfig.

| File                          | Purpose                                          |
|-------------------------------|--------------------------------------------------|
| `dev-alice-mgmt.kubeconfig`   | Your restricted access to the management cluster |
| `dev-alice-tcp.yaml`          | Your cluster definition                          |

> Replace `dev-alice` with your own username in all commands below.

Copy both files to your Windows Downloads folder.

---

## Part 1 — One-Time WSL Setup

> Skip this section if you have already run setup before. Go straight to [Part 2](#part-2--each-session).
>
> Run once when you first get your files from ops.

### 1.1 — Enable systemd

Check if systemd is running:
```bash
ps -p 1 -o comm=
```

If the output is **not** `systemd`, add this to `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```

Then restart WSL from PowerShell:
```powershell
wsl --shutdown
```

### 1.2 — Clone the repo

```bash
git clone https://github.com/frederi-co/kamaji-demo.git
cd kamaji-demo
```

### 1.3 — Run setup

```bash
bash scripts/developer/setup-wsl.sh dev-alice \
  /mnt/c/Users/<your-username>/Downloads/dev-alice-mgmt.kubeconfig \
  /mnt/c/Users/<your-username>/Downloads/dev-alice-tcp.yaml
```

This will:
- Install containerd, kubelet, kubeadm, kubectl
- Pre-pull all required images (~3 min first time)
- Save your kubeconfig and scripts to `~/kamaji-scripts/`

---

## Part 2 — Each Session

> Run these commands at the start of each test session.

### Step 1 — Provision your cluster

```bash
cd ~/kamaji-scripts
./new-cluster.sh
```

This does everything in one step:
1. Creates your tenant control plane on the management cluster (~16 seconds)
2. Generates a join token
3. Joins **your WSL machine** as the worker node (~30 seconds)
4. Installs Calico CNI and waits for the node to be Ready

Expected output:
```
✓ Control plane ready in 16 seconds
✓ Cluster ready for dev-alice!
  Control plane: https://54.169.253.180:31001
  Worker node:   <your-hostname>
```

Takes ~2 minutes total.

---

### Step 2 — Deploy the demo app

```bash
./deploy-app.sh
```

With a custom colour and label:
```bash
./deploy-app.sh '#1a73e8' Development
```

Open the printed URL in your browser — it shows your name, background colour, and environment badge.

---

### Step 3 — Change environment

Simulate promoting your app across environments:

```bash
./change-env.sh blue        # Development
./change-env.sh orange      # Staging
./change-env.sh red         # Production
./change-env.sh green       # Testing
./change-env.sh purple      # Hotfix
```

Refresh your browser — colour and label update instantly without reprovisioning.

| Colour   | Label       |
|----------|-------------|
| blue     | Development |
| green    | Testing     |
| orange   | Staging     |
| red      | Production  |
| purple   | Hotfix      |

---

### Step 4 — Destroy your cluster

At the end of your session:

```bash
./destroy-cluster.sh
```

This deletes your cluster and resets WSL — ready for the next session.

---

## Troubleshooting

**`systemd is not running` error**
Add `systemd=true` to `/etc/wsl.conf` and run `wsl --shutdown` from PowerShell.

**`developer identity not found` error**
Re-run `setup-wsl.sh` — the `~/.kamaji-dev` file is missing.

**`no active cluster` error**
Run `./new-cluster.sh` first before deploying the app.

**`containerd not running` after reset**
```bash
sudo systemctl start containerd
```
