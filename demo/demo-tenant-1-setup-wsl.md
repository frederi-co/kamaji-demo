# Demo — Tenant Lane Step 1: Set Up Worker Node

> **Who**: Developer / Team Admin  
> **Where**: Developer WSL or EC2 worker  
> **When**: Once per machine

---

## Prerequisites

- Received `dev-alice-mgmt.kubeconfig` from Ops
- WSL with Ubuntu 22.04 (or EC2 worker already running)
- systemd enabled in WSL

---

## Enable systemd (WSL only — if not already done)

Add to `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```

Restart WSL from PowerShell:
```powershell
wsl --shutdown
```

---

## Option A — WSL Worker

**1. Clone the repo**
```bash
git clone https://github.com/frederi-co/kamaji-demo.git ~/kamaji-demo
```

**2. Run WSL setup**
```bash
bash ~/kamaji-demo/scripts/developer/setup-wsl.sh dev-alice \
  /mnt/c/Users/<username>/Downloads/dev-alice-mgmt.kubeconfig
```

This will:
- Install containerd, kubelet, kubeadm, kubectl
- Pre-pull all required images (~3 min first time)
- Save kubeconfig to `~/.kube/dev-alice.mgmt.kubeconfig`
- Copy scripts to `~/kamaji-scripts/`
- Save developer identity to `~/.kamaji-dev`

**3. Set up kubectl tools**
```bash
bash ~/kamaji-demo/scripts/developer/setup-kubectl-tools.sh
source ~/.bashrc
```

---

## Option B — EC2 Worker

**1. SSH into EC2**
```bash
ssh -i /path/to/key.pem ubuntu@<ec2-ip>
```

**2. Clone the repo**
```bash
git clone https://github.com/frederi-co/kamaji-demo.git ~/kamaji-demo
```

**3. Run EC2 worker setup**
```bash
bash ~/kamaji-demo/scripts/developer/setup-ec2-worker.sh
```

**4. Copy kubeconfig from ops**
```bash
mkdir -p ~/.kube
# Ops runs: scp <kubeconfig> ubuntu@<ec2-ip>:/tmp/dev-alice-mgmt.kubeconfig
mv /tmp/dev-alice-mgmt.kubeconfig ~/.kube/dev-alice.mgmt.kubeconfig
```

**5. Set developer identity and copy scripts**
```bash
bash ~/kamaji-demo/scripts/developer/setup-wsl.sh dev-alice ~/.kube/dev-alice.mgmt.kubeconfig
```

---

## Verify

```bash
cat ~/.kamaji-dev          # should output: dev-alice
ls ~/kamaji-scripts/       # should list the developer scripts
```
