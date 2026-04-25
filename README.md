# Kamaji Demo

A self-service Kubernetes environment powered by [Kamaji](https://kamaji.clastix.io). Tenants provision isolated clusters on demand — control planes run as pods on a single management cluster, workers join from their own machines (WSL or EC2).

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

### Ops

| Script | Purpose |
|--------|---------|
| `scripts/ops/setup-management.sh <ip> <password>` | Bootstrap management cluster on EC2 (run once) |
| `scripts/ops/setup-ops-wsl.sh` | Set up ops WSL machine (run once per ops user) |
| `scripts/ops/provision-tenant.sh <tenant-name>` | Provision tenant — creates RBAC, applies TCP, generates kubeconfig |
| `scripts/ops/deprovision-tenant.sh <tenant-name>` | Deprovision tenant — deletes TCP and namespace |
| `scripts/ops/update-kubeconfigs.sh` | Fetch all tenant kubeconfigs to local machine |

### Developer (self-service)

| Script | Purpose |
|--------|---------|
| `scripts/developer/setup-wsl.sh <tenant-name> <mgmt-kubeconfig>` | One-time WSL setup |
| `scripts/developer/setup-worker.sh` | One-time EC2 worker setup (alternative to WSL) |
| `scripts/developer/join-cluster.sh` | Join WSL/EC2 as worker to pre-provisioned control plane |
| `scripts/developer/deploy-app.sh [colour] [label]` | Deploy demo app |
| `scripts/developer/change-env.sh <colour> [label]` | Change app environment live |
| `scripts/developer/detach-cluster.sh` | Detach worker node and reset local state |

## Tenant Port Assignments

| Tenant          | API Port | Konnectivity | Pod CIDR       | Svc CIDR       |
|-----------------|----------|--------------|----------------|----------------|
| dev-alice       | 31001    | 31002        | 10.100.0.0/16  | 10.101.0.0/16  |
| dev-bryan       | 31003    | 31004        | 10.102.0.0/16  | 10.103.0.0/16  |
| project-charlie | 31005    | 31006        | 10.104.0.0/16  | 10.105.0.0/16  |

## Colour Presets

```bash
./change-env.sh blue       # Development
./change-env.sh green      # Testing
./change-env.sh orange     # Staging
./change-env.sh red        # Production
./change-env.sh purple     # Hotfix
```

## Quick Start

**Ops — provision a tenant:**
```bash
export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig
bash scripts/ops/provision-tenant.sh dev-alice
# Send output/dev-alice-mgmt.kubeconfig to the developer
```

**Developer — first time setup:**
```bash
bash scripts/developer/setup-wsl.sh dev-alice \
  /path/to/dev-alice-mgmt.kubeconfig
```

**Developer — each session:**
```bash
cd ~/kamaji-scripts
./join-cluster.sh    # ~2 minutes
./deploy-app.sh      # open browser at printed URL
./change-env.sh red  # simulate promotion
```

## Documentation

- [Developer Guide](docs/developer-guide.md) — full walkthrough for tenants
