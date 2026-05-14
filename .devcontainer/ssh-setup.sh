#!/bin/bash
set -e

echo "=== SSH Setup for opencode ==="

if [ -f "/home/tim-external/volumeROS/.devcontainer/ssh/id_ed25519" ]; then
  cp /home/tim-external/volumeROS/.devcontainer/ssh/id_ed25519 ~/.ssh/id_ed25519
  cp /home/tim-external/volumeROS/.devcontainer/ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
  chmod 600 ~/.ssh/id_ed25519
  chmod 644 ~/.ssh/id_ed25519.pub
  echo "✓ SSH keys copied from workspace"
else
  echo "⚠ SSH keys not found in workspace. Run generation script first."
fi

ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true

cat > ~/.ssh/config << EOF
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  User git
  AddKeysToAgent yes
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

echo "Testing SSH connection to GitHub..."
ssh -T git@github.com || echo "⚠ SSH test failed - verify key is added to GitHub"

echo "=== SSH Setup Complete ==="
