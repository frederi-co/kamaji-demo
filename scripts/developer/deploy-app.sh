#!/bin/bash
set -euo pipefail

[[ ! -f "$HOME/.kamaji-dev" ]] && { echo "Error: developer identity not found. Run setup-wsl.sh first."; exit 1; }
DEV=$(cat "$HOME/.kamaji-dev")
TENANT_KUBECONFIG="$HOME/.kube/${DEV}-tenant.kubeconfig"
[[ ! -f "$TENANT_KUBECONFIG" ]] && { echo "Error: no active cluster. Run new-cluster.sh first."; exit 1; }

BG_COLOR="${1:-#1a73e8}"
ENV_LABEL="${2:-Development}"
ENV_COLOR="${3:-#34a853}"
NODE_PORT=30888

echo "==> Deploying demo app for $DEV..."

kubectl --kubeconfig="$TENANT_KUBECONFIG" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: demo-app
          image: python:3.11-slim
          ports:
            - containerPort: 8080
          env:
            - name: TENANT_NAME
              value: "${DEV}"
            - name: BG_COLOR
              value: "${BG_COLOR}"
            - name: ENV_LABEL
              value: "${ENV_LABEL}"
            - name: ENV_COLOR
              value: "${ENV_COLOR}"
          command: ["python3", "-c"]
          args:
            - |
              import http.server, os
              class H(http.server.BaseHTTPRequestHandler):
                  def log_message(self, format, *args): pass
                  def do_GET(self):
                      self.send_response(200)
                      self.send_header('Content-type', 'text/html')
                      self.end_headers()
                      tenant = os.environ.get('TENANT_NAME', 'Unknown')
                      bg = os.environ.get('BG_COLOR', '#1a73e8')
                      env_label = os.environ.get('ENV_LABEL', 'Development')
                      env_color = os.environ.get('ENV_COLOR', '#34a853')
                      html = f"""<!DOCTYPE html>
              <html>
              <head>
                <title>{tenant}</title>
                <style>
                  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
                  body {{
                    background: {bg};
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    font-family: 'Segoe UI', sans-serif;
                    color: white;
                  }}
                  .card {{
                    background: rgba(255,255,255,0.15);
                    backdrop-filter: blur(10px);
                    border-radius: 20px;
                    padding: 60px 80px;
                    text-align: center;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.2);
                  }}
                  h1 {{ font-size: 4em; font-weight: 700; letter-spacing: -1px; }}
                  .subtitle {{ font-size: 1.3em; margin-top: 10px; opacity: 0.85; }}
                  .badge {{
                    display: inline-block;
                    background: {env_color};
                    color: white;
                    padding: 6px 20px;
                    border-radius: 50px;
                    font-size: 0.95em;
                    font-weight: 600;
                    margin-top: 24px;
                    letter-spacing: 1px;
                    text-transform: uppercase;
                  }}
                  .powered {{
                    margin-top: 40px;
                    font-size: 0.8em;
                    opacity: 0.5;
                    letter-spacing: 2px;
                    text-transform: uppercase;
                  }}
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>{tenant}</h1>
                  <div class="subtitle">Kubernetes Cluster — Powered by Kamaji</div>
                  <div class="badge">{env_label}</div>
                  <div class="powered">clastix / kamaji</div>
                </div>
              </body>
              </html>"""
                      self.wfile.write(html.encode())
              http.server.HTTPServer(('', 8080), H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: default
spec:
  type: NodePort
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 8080
      nodePort: ${NODE_PORT}
EOF

echo "  --> Waiting for pod to be ready..."
kubectl --kubeconfig="$TENANT_KUBECONFIG" rollout status deployment/demo-app --timeout=120s

IMDS_TOKEN=$(curl -sf --max-time 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
PUBLIC_IP=$(curl -sf --max-time 2 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
WSL_IP=${PUBLIC_IP:-$(ip route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')}
echo ""
echo "✓ Demo app deployed for $DEV!"
echo "  Access URL: http://${WSL_IP}:${NODE_PORT}"
echo ""
echo "To change the environment, run:"
echo "  ./change-env.sh '#e53935' Staging"
