# Demo — Tenant Lane Step 1: Set Up Worker Node

> **Who**: Developer / Team Admin  
> **Where**: Developer WSL or EC2 worker  
> **When**: Once per machine

---

## Prerequisites

- Received `<tenant>-mgmt.kubeconfig` from Ops
- WSL with Ubuntu 22.04 (or EC2 worker already running)
- systemd enabled in WSL (WSL only)

---

## Option A — WSL Worker

### Enable systemd (if not already done)

Add to `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```

Restart WSL from PowerShell:
```powershell
wsl --shutdown
```

**1. Clone the repo**
```bash
git clone https://github.com/frederi-co/kamaji-demo.git ~/kamaji-demo
```

**2. Run WSL setup**
```bash
bash ~/kamaji-demo/scripts/developer/setup-wsl.sh <tenant> \
  /mnt/c/Users/<username>/Downloads/<tenant>-mgmt.kubeconfig
```

This will:
- Install containerd, kubelet, kubeadm, kubectl
- Pre-pull all required images (~3 min first time)
- Save kubeconfig to `~/.kube/<tenant>.mgmt.kubeconfig`
- Download and cache Calico manifest
- Copy scripts to `~/kamaji-scripts/`
- Save tenant identity to `~/.kamaji-dev`

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

**3. Copy kubeconfig from ops onto the EC2**
```bash
# Ops runs from their machine:
scp -i /path/to/key.pem <tenant>-mgmt.kubeconfig ubuntu@<ec2-ip>:/tmp/<tenant>-mgmt.kubeconfig
```

**4. Run EC2 worker setup**
```bash
bash ~/kamaji-demo/scripts/developer/setup-ec2-worker.sh <tenant> /tmp/<tenant>-mgmt.kubeconfig
```

This will:
- Disable swap
- Install containerd, kubelet, kubeadm, kubectl
- Pre-pull all required images (~3 min first time)
- Save kubeconfig to `~/.kube/<tenant>.mgmt.kubeconfig`
- Download and cache Calico manifest
- Copy scripts to `~/kamaji-scripts/`
- Save tenant identity to `~/.kamaji-dev`

*Repeat steps 1–4 for each additional EC2 node joining the same tenant cluster.*

---

## Verify

```bash
cat ~/.kamaji-dev          # should output: <tenant>
ls ~/kamaji-scripts/       # should list the developer scripts
```
