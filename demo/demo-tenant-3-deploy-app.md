# Demo — Tenant Lane Step 3: Deploy App

> **Who**: Developer  
> **Where**: Developer WSL or EC2 worker  
> **When**: After joining cluster

---

## Prerequisites

- Step 2 (join cluster) complete
- Node showing as Ready

---

## Steps

**1. Deploy the demo app**
```bash
cd ~/kamaji-scripts
./deploy-app.sh
```

With a custom colour and label:
```bash
./deploy-app.sh '#1a73e8' Development
```

This will:
1. Deploy a Python HTTP server as a Kubernetes Deployment
2. Expose it via NodePort on port 30888
3. Wait for rollout to complete
4. Print the access URL

**Expected output:**
```
✓ Demo app deployed for dev-alice!
  Access URL: http://<worker-ip>:30888
```

---

## Verify

Open the URL in a browser — shows:
- Tenant name
- Background colour
- Environment badge (e.g. "Development")
- "Powered by Kamaji"

```bash
k get pods
k get svc
```
