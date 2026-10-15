#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Lightsail Server Bootstrap Script (One-Time Setup via SSH)
# Minimal infra, zero extra cost. Installs Docker and configures directories.
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)." >&2
  exit 1
fi

REPO_SSH_URL="${REPO_SSH_URL:-git@github.com:19mandal97/sambhav-labs-auth.git}"
TARGET_DIR="/opt/zitadel"

echo "==> Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release git jq

# 1. Install Docker & Docker Compose Plugin
if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  usermod -aG docker ubuntu || true
else
  echo "--> Docker is already installed."
fi

# 2. Setup deploy key for GitHub repository access
if [ ! -f /root/.ssh/id_ed25519 ]; then
  echo "==> Generating SSH deploy key for GitHub access..."
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "zitadel-lightsail-deploy"
  ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts
  chmod 600 /root/.ssh/known_hosts /root/.ssh/id_ed25519
fi

# 3. Clone repository
mkdir -p "${TARGET_DIR}"
if [ ! -d "${TARGET_DIR}/.git" ]; then
  echo "==> Cloning repo into ${TARGET_DIR}..."
  git clone "${REPO_SSH_URL}" "${TARGET_DIR}" || echo "Note: Add deploy key below to GitHub first, then clone manually."
fi

# 4. Prepare Traefik letsencrypt directory
mkdir -p "${TARGET_DIR}/letsencrypt"
touch "${TARGET_DIR}/letsencrypt/acme.json"
chmod 600 "${TARGET_DIR}/letsencrypt/acme.json"

# 5. Create default .env if missing
if [ ! -f "${TARGET_DIR}/.env" ]; then
  if [ -f "${TARGET_DIR}/.env.example" ]; then
    cp "${TARGET_DIR}/.env.example" "${TARGET_DIR}/.env"
    chmod 600 "${TARGET_DIR}/.env" 2>/dev/null || true
    echo "--> Created ${TARGET_DIR}/.env from .env.example."
  elif [ -f "${TARGET_DIR}/config/env.example" ]; then
    cp "${TARGET_DIR}/config/env.example" "${TARGET_DIR}/.env"
    chmod 600 "${TARGET_DIR}/.env" 2>/dev/null || true
    echo "--> Created ${TARGET_DIR}/.env from config/env.example."
  fi
fi

# 6. Ensure proper ownership for ubuntu user
if id -u ubuntu >/dev/null 2>&1; then
  chown -R ubuntu:ubuntu "${TARGET_DIR}"
  chmod 600 "${TARGET_DIR}/.env" 2>/dev/null || true
  chmod 600 "${TARGET_DIR}/letsencrypt/acme.json" 2>/dev/null || true
fi

echo ""
echo "=============================================================================="
echo " Server Bootstrap Completed!"
echo "=============================================================================="
echo "1. Public SSH Deploy Key (Add to GitHub Repo -> Settings -> Deploy keys):"
cat /root/.ssh/id_ed25519.pub
echo ""
echo "2. Edit your environment variables in:"
echo "   nano ${TARGET_DIR}/.env"
echo "=============================================================================="
