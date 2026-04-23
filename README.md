# Kamaji Demo

A self-service Kubernetes developer environment powered by [Kamaji](https://kamaji.clastix.io). Developers provision isolated clusters on demand — control planes run as pods on a single management cluster, workers join from their own machines.

## Architecture

```
┌─────────────────────────────────────────────────┐
│           EC2 #1 — Management Cluster           │
│   k3s + cert-manager + Kamaji + etcd            │
│                                                 │
│   ┌──────────────┐  ┌──────────────┐            │
│   │  dev-alice   │  │  dev-bryan   │  ...       │
│   │  TCP :31001  │  │  TCP :31003  │            │
│   └──────┬───────┘  └──────┬───────┘            │
└──────────┼─────────────────┼───────────────────┘
           │ kubeadm join    │ kubeadm join
    ┌──────▼──────┐   ┌──────▼──────┐
    │  alice WSL  │   │   EC2 #2    │
    │ worker node │   │ worker node │
    └─────────────┘   └─────────────┘
```

## Scripts

### Ops (run once)

| Script | Purpose |
|--------|---------|
| `scripts/ops/setup-management.sh <ip> <password>` | Bootstrap management cluster on EC2 |
| `scripts/ops/setup-worker.sh` | Prepare a standby EC2 worker node |
| `scripts/ops/provision-developer.sh <dev-name>` | Onboard a developer — creates RBAC + kubeconfig + TCP manifest |

### Developer (self-service)

| Script | Purpose |
|--------|---------|
| `scripts/developer/setup-wsl.sh <dev-name> <mgmt-kubeconfig> [tcp-yaml]` | One-time WSL setup |
| `scripts/developer/new-cluster.sh` | Provision cluster + join WSL as worker |
| `scripts/developer/deploy-app.sh [colour] [label]` | Deploy demo app |
| `scripts/developer/change-env.sh <colour> [label]` | Change app environment live |
| `scripts/developer/destroy-cluster.sh` | Destroy cluster + reset WSL |

## Developer Port Assignments

| Developer   | API Port | Konnectivity | Pod CIDR       | Svc CIDR       |
|-------------|----------|--------------|----------------|----------------|
| dev-alice   | 31001    | 31002        | 10.100.0.0/16  | 10.101.0.0/16  |
| dev-bryan   | 31003    | 31004        | 10.102.0.0/16  | 10.103.0.0/16  |
| dev-charlie | 31005    | 31006        | 10.104.0.0/16  | 10.105.0.0/16  |

## Colour Presets

```bash
./change-env.sh blue       # Development
./change-env.sh green      # Testing
./change-env.sh orange     # Staging
./change-env.sh red        # Production
./change-env.sh purple     # Hotfix
```

## Quick Start

**Ops — onboard a developer:**
```bash
export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig
bash scripts/ops/provision-developer.sh dev-alice
# Send output/dev-alice-mgmt.kubeconfig and output/dev-alice-tcp.yaml to developer
```

**Developer — first time setup:**
```bash
bash scripts/developer/setup-wsl.sh dev-alice \
  /path/to/dev-alice-mgmt.kubeconfig \
  /path/to/dev-alice-tcp.yaml
```

**Developer — each session:**
```bash
cd ~/kamaji-scripts
./new-cluster.sh       # ~2 minutes
./deploy-app.sh        # open browser at printed URL
./change-env.sh red    # simulate promotion
./destroy-cluster.sh   # clean up
```
