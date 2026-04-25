# Demo — Ops Lane Step 1: Set Up Management Cluster

> **Who**: Ops  
> **Where**: SSH into EC2 #1  
> **When**: One-time setup

---

## Prerequisites

- EC2 #1 running (Ubuntu 22.04, t3.medium)
- EIP `52.221.159.116` associated to EC2 #1
- PEM file available at `/tmp/kamaji.pem`
- Security group ports open: 22, 6443, 30080, 30888, 31001–31006

---

## Steps

**1. SSH into EC2 #1**
```bash
ssh -i /tmp/kamaji.pem ubuntu@52.221.159.116
```

**2. Clone the repo**
```bash
git clone https://github.com/frederi-co/kamaji-demo.git ~/kamaji-demo
cd ~/kamaji-demo
```

**3. Run setup**
```bash
bash scripts/ops/setup-management.sh 52.221.159.116 admin123
```

Takes ~5 minutes. Installs: k3s → Helm → cert-manager → Kamaji → kubeadm → Kamaji Console

**4. Verify**
```bash
kubectl get nodes
kubectl -n kamaji-system get pods
```

Expected output:
```
NAME       STATUS   ROLES                  AGE
...        Ready    control-plane,master   ...

NAME                                      READY   STATUS
console-kamaji-console-...                1/1     Running
etcd-0                                    1/1     Running
etcd-1                                    1/1     Running
etcd-2                                    1/1     Running
kamaji-...                                1/1     Running
```

**5. Open Kamaji Console**

```
http://52.221.159.116:30080/ui
Login: admin@kamaji.demo / admin123
```
