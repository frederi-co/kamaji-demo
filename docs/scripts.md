# Kamaji Scripts Reference

## Ops Scripts (`scripts/ops/`)

**`setup-management.sh`** — one-time setup of the management cluster on a fresh EC2
1. Install system prerequisites
2. Install k3s (Traefik disabled), copy kubeconfig
3. Configure kubectl bash completion and `k` alias
4. Install Helm
5. Install cert-manager
6. Install Kamaji controller
7. Install kubeadm v1.30
8. Install Kamaji Console, expose on NodePort 30080
9. Generate ops kubeconfig (with public IP)
10. Copy all ops + developer scripts to `~/scripts/`

---

**`provision-tenant.sh`** — onboard one tenant onto the management cluster
1. Create namespace
2. Create ServiceAccount
3. Create Role (scoped to TenantControlPlanes and Secrets)
4. Create RoleBinding
5. Generate kubeconfig from ServiceAccount token (1-year expiry)
6. Generate TenantControlPlane manifest (tenant-specific ports, pod/service CIDRs)
7. Apply TenantControlPlane to management cluster
8. Wait for control plane to be Ready

Outputs `./output/<dev>.mgmt.kubeconfig` — the only file handed off to the tenant.

---

**`deprovision-tenant.sh`** — tear down a tenant from the management cluster
1. Delete TenantControlPlane
2. Delete namespace (cascades to ServiceAccount, Role, RoleBinding, secrets)

---

**`setup-ops-wsl.sh`** — prepare a fresh ops WSL machine (run once per ops user)
1. Verify systemd is running
2. Install kubectl v1.30 (if not present)
3. Configure kubectl bash completion and `k` alias
4. Fetch ops kubeconfig from EC2 #1 via SCP
5. Set `KUBECONFIG` in `~/.bashrc`
6. Copy ops scripts to `~/kamaji-scripts/`
7. Fetch all tenant kubeconfigs via `update-kubeconfigs.sh`
8. Verify management cluster access

---

**`update-kubeconfigs.sh`** — fetch all tenant kubeconfigs from management cluster
1. List all active TenantControlPlanes
2. Skip any TCP not in Ready state
3. Fetch admin kubeconfig from each tenant's secret
4. Save to `~/.kube/<tenant>-tenant.kubeconfig`

---

## Developer Scripts (`scripts/developer/`)

**`setup-wsl.sh`** — prepare a WSL worker node (run once)
1. Verify systemd is running
2. Disable swap
3. Enable IP forwarding
4. Install containerd (if not present), configure with SystemdCgroup=true
5. Install kubelet, kubeadm, kubectl v1.30 (if not present)
6. Pre-pull images (pause, kube-proxy, Calico, python:3.11-slim)
7. Save mgmt kubeconfig to `~/.kube/<dev>.mgmt.kubeconfig`
8. Download and cache Calico manifest
9. Copy remaining developer scripts to `~/kamaji-scripts/`
10. Save developer identity to `~/.kamaji-dev`

---

**`setup-ec2-worker.sh`** — prepare an EC2 instance as a worker node and onboard a tenant (run once per node)
1. Disable swap
2. Install system prerequisites
3. Enable IP forwarding
4. Install containerd, configure with SystemdCgroup=true
5. Install kubelet, kubeadm, kubectl v1.30
6. Pre-pull images (pause, kube-proxy, Calico, python:3.11-slim)
7. Save mgmt kubeconfig to `~/.kube/<dev>.mgmt.kubeconfig`
8. Download and cache Calico manifest
9. Copy remaining developer scripts to `~/kamaji-scripts/`
10. Save tenant identity to `~/.kamaji-dev`

Usage: `setup-ec2-worker.sh <dev-name> <path-to-mgmt-kubeconfig>`

*Run on every new EC2 node joining the same cluster — machine prep and tenant onboarding in one step. Follow with `join-cluster.sh`.*

---

**`join-cluster.sh`** — join this machine as a worker to the pre-provisioned control plane
1. Verify control plane is Ready
2. Fetch tenant kubeconfig from management cluster secret
3. Generate kubeadm join token
4. Delete stale node record from tenant cluster (handles WSL IP change between sessions)
5. Stop kubelet
6. Reset any previous cluster state (`kubeadm reset`, remove CNI config, clear kubelet PKI)
7. Start containerd, disable swap, re-enable IP forwarding, set cgroup driver
8. Join cluster as worker node
9. Wait for node to register
10. Install Calico CNI
11. Wait for node to reach Ready

*Safe to re-run at any time — no need to detach first. Handles all WSL session state automatically.*

---

**`deploy-app.sh`** — deploy the demo web app onto the tenant cluster
1. Apply Deployment (Python HTTP server, env-driven background colour and environment label)
2. Apply NodePort Service on port 30888
3. Wait for rollout to complete
4. Print access URL

---

**`change-env.sh`** — simulate environment promotion by updating the running app
1. Resolve colour name to hex (blue=Development, green=Testing, orange=Staging, red=Production, purple=Hotfix)
2. Derive badge colour from environment label
3. Patch deployment env vars (`BG_COLOR`, `ENV_LABEL`, `ENV_COLOR`)
4. Wait for rollout to complete
5. Print refreshed URL

---

**`detach-cluster.sh`** — detach worker node and clean up local state
1. Delete node record from tenant cluster (warns and continues if control plane unreachable)
2. Reset WSL/EC2 node (`kubeadm reset`, remove CNI config)
3. Remove tenant kubeconfig

*Control plane stays running — ops runs `deprovision-tenant.sh` to tear it down.*

---

**`setup-kubectl-tools.sh`** — configure kubectl bash completion and alias (run once)
1. Install `bash-completion` if not present
2. Add `kubectl completion bash` to `~/.bashrc`
3. Add `alias k=kubectl` with autocomplete to `~/.bashrc`
