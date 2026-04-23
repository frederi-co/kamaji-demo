# Ops Guide — Kamaji Management Cluster

This guide covers the full ops workflow — from bootstrapping the management cluster to onboarding developers.

---

## Infrastructure

| Machine  | Role               | IP             | Spec                    |
|----------|--------------------|----------------|-------------------------|
| EC2 #1   | Management cluster | 54.169.253.180 | t3.medium, Ubuntu 22.04 |
| EC2 #2   | Standby worker     | 54.169.64.59   | t3.medium, Ubuntu 22.04 |

SSH key: `C:\Users\frederick.foong\Downloads\kamaji.pem`

```bash
# Copy PEM to Linux filesystem before use
cp /mnt/c/Users/frederick.foong/Downloads/kamaji.pem /tmp/kamaji.pem
chmod 600 /tmp/kamaji.pem

# Convenience aliases
alias ssh-mgmt="ssh -i /tmp/kamaji.pem ubuntu@54.169.253.180"
alias ssh-worker="ssh -i /tmp/kamaji.pem ubuntu@54.169.64.59"
```

---

## EC2 Security Groups

### EC2 #1 (Management) — inbound rules

| Port  | Protocol | Purpose                    |
|-------|----------|----------------------------|
| 22    | TCP      | SSH                        |
| 6443  | TCP      | k3s API server             |
| 30080 | TCP      | Kamaji Console UI          |
| 30888 | TCP      | Demo app NodePort          |
| 31001 | TCP      | dev-alice API server       |
| 31002 | TCP      | dev-alice konnectivity     |
| 31003 | TCP      | dev-bryan API server       |
| 31004 | TCP      | dev-bryan konnectivity     |
| 31005 | TCP      | dev-charlie API server     |
| 31006 | TCP      | dev-charlie konnectivity   |

### EC2 #2 (Worker) — inbound rules

| Port  | Protocol | Purpose          |
|-------|----------|------------------|
| 22    | TCP      | SSH              |
| 10250 | TCP      | kubelet API      |
| 30888 | TCP      | Demo app NodePort|

---

## Part 1 — Bootstrap Management Cluster

> Run once on a fresh EC2 #1.

```bash
ssh -i /tmp/kamaji.pem ubuntu@54.169.253.180

# Clone the repo
git clone https://github.com/frederi-co/kamaji-demo.git
cd kamaji-demo

# Run setup
bash scripts/ops/setup-management.sh 54.169.253.180 admin123
```

This installs: k3s → Helm → cert-manager → Kamaji → kubeadm → Kamaji Console

**Verify:**
```bash
kubectl get nodes                        # management node Ready
kubectl -n kamaji-system get pods        # kamaji + 3x etcd Running
# Browser: http://54.169.253.180:30080/ui  →  admin@kamaji.demo / admin123
```

---

## Part 2 — Bootstrap Standby Worker

> Run once on a fresh EC2 #2.

```bash
ssh -i /tmp/kamaji.pem ubuntu@54.169.64.59

git clone https://github.com/frederi-co/kamaji-demo.git
cd kamaji-demo

bash scripts/ops/setup-worker.sh
```

This installs containerd, kubelet/kubeadm/kubectl v1.30, and pre-pulls all images.

---

## Part 3 — Get Ops Kubeconfig

> Run on ops laptop after management cluster is up.

```bash
scp -i /tmp/kamaji.pem ubuntu@54.169.253.180:/home/ubuntu/kamaji-ops.kubeconfig \
  ~/.kube/kamaji-mgmt.kubeconfig

export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig
kubectl get nodes   # verify access
```

---

## Part 4 — Onboard Developers

> Run on ops laptop or EC2 #1. Requires KUBECONFIG pointing to management cluster.

```bash
export KUBECONFIG=~/.kube/kamaji-mgmt.kubeconfig

bash scripts/ops/provision-developer.sh dev-alice
bash scripts/ops/provision-developer.sh dev-bryan
bash scripts/ops/provision-developer.sh dev-charlie
```

Each developer gets two files in `./output/`:

| File                          | Send to developer |
|-------------------------------|-------------------|
| `dev-alice-mgmt.kubeconfig`   | Yes               |
| `dev-alice-tcp.yaml`          | Yes               |

### Developer Port Assignments

| Developer   | API Port | Konnectivity | Pod CIDR       | Svc CIDR       |
|-------------|----------|--------------|----------------|----------------|
| dev-alice   | 31001    | 31002        | 10.100.0.0/16  | 10.101.0.0/16  |
| dev-bryan   | 31003    | 31004        | 10.102.0.0/16  | 10.103.0.0/16  |
| dev-charlie | 31005    | 31006        | 10.104.0.0/16  | 10.105.0.0/16  |

---

## Day-to-Day Operations

### Check all tenant control planes

```bash
kubectl get tcp --all-namespaces
```

### Check pods for a specific developer

```bash
kubectl get pods -n dev-alice
kubectl get pods -n dev-bryan
kubectl get pods -n dev-charlie
```

### Open Kamaji Console

```
http://54.169.253.180:30080/ui
Login: admin@kamaji.demo / admin123
```

### Remove a developer

```bash
kubectl delete namespace dev-alice   # removes TCP, RBAC, secrets
```

---

## Cleanup

### Full teardown

```bash
helm uninstall console -n kamaji-system
helm uninstall kamaji -n kamaji-system
helm uninstall cert-manager -n cert-manager

# Terminate EC2 instances via AWS console
```

---

## Troubleshooting

**`permission denied` reading k3s kubeconfig**
```bash
export KUBECONFIG=/home/ubuntu/.kube/config
```

**Developer kubeconfig TLS error**
Re-run `provision-developer.sh` — the kubeconfig uses `insecure-skip-tls-verify` to bypass k3s certificate SAN mismatch.

**TCP stuck not Ready**
```bash
kubectl describe tcp <dev-name> -n <dev-name>
kubectl -n <dev-name> get pods
```

**containerd not running on worker**
```bash
sudo systemctl start containerd
sudo systemctl enable containerd
```
