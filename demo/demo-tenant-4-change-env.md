# Demo — Tenant Lane Step 4: Change Environment

> **Who**: Developer  
> **Where**: Developer WSL or EC2 worker  
> **When**: After deploying app

---

## Prerequisites

- Step 3 (deploy app) complete
- Demo app accessible in browser

---

## Steps

**Change environment using colour name:**
```bash
cd ~/kamaji-scripts
./change-env.sh blue        # Development
./change-env.sh orange      # Staging
./change-env.sh red         # Production
./change-env.sh green       # Testing
./change-env.sh purple      # Hotfix
```

**With a custom label:**
```bash
./change-env.sh red "Production v2.1"
```

---

## Colour Presets

| Colour | Hex       | Default Label |
|--------|-----------|---------------|
| blue   | `#1a73e8` | Development   |
| green  | `#2e7d32` | Testing       |
| orange | `#f57c00` | Staging       |
| red    | `#e53935` | Production    |
| purple | `#6a1b9a` | Hotfix        |

---

## Expected output:
```
✓ Environment updated to 'Production' (#e53935)
  Refresh your browser: http://<worker-ip>:30888
```

Refresh the browser — colour and label update instantly without reprovisioning the cluster.
