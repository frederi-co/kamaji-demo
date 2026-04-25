# Developer Guide — Kamaji Self-Service Clusters

This guide walks you through setting up your personal Kubernetes cluster and running the demo app.

---

## What You Need From Ops

Ops will assign you a tenant name (e.g. `dev-alice`) and send you one file named after it. This name is your identity throughout — it scopes your cluster, your RBAC access, and your kubeconfig.

| File                          | Purpose                                          |
|-------------------------------|--------------------------------------------------|
| `dev-alice-mgmt.kubeconfig`   | Your restricted access to the management cluster |

> Replace `dev-alice` with your own tenant name in all commands below.

Copy the file to your Windows Downloads folder.

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
  /mnt/c/Users/<your-username>/Downloads/dev-alice-mgmt.kubeconfig
```

This will:
- Install containerd, kubelet, kubeadm, kubectl
- Pre-pull all required images (~3 min first time)
- Save your kubeconfig and scripts to `~/kamaji-scripts/`

---

## Part 2 — Each Session

> Run these commands at the start of each test session.
> Re-running `join-cluster.sh` is safe — it resets any previous state automatically.

### Step 1 — Join your cluster

```bash
cd ~/kamaji-scripts
./join-cluster.sh
```

This does everything in one step:
1. Verifies your control plane is Ready on the management cluster
2. Generates a join token
3. Joins **your WSL machine** as the worker node (~30 seconds)
4. Installs Calico CNI and waits for the node to be Ready

Expected output:
```
✓ Control plane is Ready
✓ Joined cluster for dev-alice!
  Control plane: https://52.221.159.116:31001
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

### Step 4 — Detach worker (optional)

If you want to cleanly reset your WSL at the end of a session:

```bash
./detach-cluster.sh
```

This resets your WSL worker node. Your control plane stays running on the management cluster — just run `./join-cluster.sh` again next session to rejoin.

---

## Troubleshooting

**`systemd is not running` error**
Add `systemd=true` to `/etc/wsl.conf` and run `wsl --shutdown` from PowerShell.

**`developer identity not found` error**
Re-run `setup-wsl.sh` — the `~/.kamaji-dev` file is missing.

**`control plane is not Ready` error**
Contact ops — your control plane may not be provisioned yet.

**`containerd not running` after reset**
```bash
sudo systemctl start containerd
```
