#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Zitadel Deployment Script (Minimal Cost / SSH Execution)
# Updates git ref, ensures .env, starts containers, and verifies health.
# ==============================================================================

GIT_REF="${1:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

echo "==> [$(date -u +%FT%TZ)] Starting deployment for ref: '${GIT_REF}' in ${PROJECT_DIR}"

cd "${PROJECT_DIR}"

# 1. Determine Docker Compose command
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Error: Neither 'docker compose' nor 'docker-compose' found on the system." >&2
  exit 1
fi

# 2. Update repository to requested ref
echo "==> Pulling latest changes from git..."
git fetch origin
git checkout "${GIT_REF}"
if git show-ref --verify --quiet "refs/remotes/origin/${GIT_REF}"; then
  git merge --ff-only "origin/${GIT_REF}" || true
fi

CURRENT_SHA=$(git rev-parse HEAD)
echo "==> Checked out commit: ${CURRENT_SHA}"

# 3. Pull / verify secrets in .env
if [ -f "${SCRIPT_DIR}/pull-secrets.sh" ] && command -v aws >/dev/null 2>&1; then
  echo "==> Updating .env from AWS Secrets Manager..."
  bash "${SCRIPT_DIR}/pull-secrets.sh" || echo "Notice: AWS Secrets Manager pull skipped; using local .env"
fi

if [ ! -f ".env" ]; then
  echo "Error: .env file not found in ${PROJECT_DIR}." >&2
  echo "Please create it from .env.example or run scripts/pull-secrets.sh." >&2
  exit 1
fi

# 4. Ensure Traefik certificates directory permissions
mkdir -p letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

# 5. Pull updated container images
echo "==> Pulling Docker images..."
$DC -f zitadel-compose.yml pull

# 6. Run database initialization and setup
echo "==> Running Zitadel init and setup..."
$DC -f zitadel-compose.yml up zitadel-init
$DC -f zitadel-compose.yml up zitadel-setup

# 7. Start Zitadel API, Login UI, and Traefik proxy
echo "==> Starting Zitadel services..."
$DC -f zitadel-compose.yml up -d --remove-orphans zitadel-api zitadel-login proxy

# 8. Health check verification
echo "==> Verifying service health..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  API_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' zitadel-api 2>/dev/null || echo '"starting"')
  LOGIN_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' zitadel-login 2>/dev/null || echo '"starting"')

  if [ "$API_STATUS" = '"healthy"' ] && [ "$LOGIN_STATUS" = '"healthy"' ]; then
    echo "==> All Zitadel services are healthy!"
    break
  fi

  echo "Waiting for healthcheck... (API: ${API_STATUS}, Login: ${LOGIN_STATUS}) [$((RETRY_COUNT+1))/${MAX_RETRIES}]"
  sleep 5
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
  echo "Warning: Healthcheck timed out. Inspecting current container status:"
  $DC -f zitadel-compose.yml ps
  exit 1
fi

echo "==> Deployment completed successfully for commit ${CURRENT_SHA}!"
