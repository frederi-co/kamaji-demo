#!/bin/bash
set -euo pipefail

echo "==> Setting up kubectl tools..."

# 1. Install bash-completion if not present
if ! dpkg -l bash-completion &>/dev/null; then
  echo "  --> Installing bash-completion..."
  sudo apt-get update -q
  sudo apt-get install -y bash-completion
fi
echo "  ✓ bash-completion ready"

# 2. Configure kubectl bash completion and k alias
if ! grep -q 'kubectl completion bash' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" << 'EOF'

# kubectl autocomplete
source <(kubectl completion bash)

# k alias with autocomplete
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
  echo "  ✓ kubectl bash completion and k alias added to ~/.bashrc"
else
  echo "  ✓ kubectl bash completion already configured"
fi

echo ""
echo "✓ Done. Run 'source ~/.bashrc' to apply changes in this session."
