#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Pulls Zitadel secrets from AWS Secrets Manager directly into .env
# Secret name: prod/sambhav-zitadel
# ==============================================================================

SECRET_NAME="${SECRET_NAME:-prod/sambhav-zitadel}"
REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ENV="${TARGET_ENV:-$(cd "${SCRIPT_DIR}/.." && pwd)/.env}"

echo "==> Fetching '${SECRET_NAME}' from AWS Secrets Manager (${REGION})..."

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: 'aws' CLI is not installed." >&2
  exit 1
fi

RAW_SECRET=$(aws secretsmanager get-secret-value \
  --region "${REGION}" \
  --secret-id "${SECRET_NAME}" \
  --query SecretString \
  --output text)

if [ -z "${RAW_SECRET}" ] || [ "${RAW_SECRET}" = "None" ]; then
  echo "Error: Secret '${SECRET_NAME}' was empty or not found." >&2
  exit 1
fi

TMP_ENV=$(mktemp)
trap 'rm -f "${TMP_ENV}"' EXIT

python3 -c '
import json, sys, shlex

raw_json = sys.argv[1]
data = json.loads(raw_json)

# Check critical variables
if "ZITADEL_MASTERKEY" in data and len(data["ZITADEL_MASTERKEY"]) != 32:
    print("Warning: ZITADEL_MASTERKEY is not 32 characters!", file=sys.stderr)

with open(sys.argv[2], "w") as f:
    for k, v in sorted(data.items()):
        val_str = str(v)
        if "\n" in val_str or "\r" in val_str:
            continue
        f.write(f"{k}={shlex.quote(val_str)}\n")
' "${RAW_SECRET}" "${TMP_ENV}"

chmod 600 "${TMP_ENV}"
mv -f "${TMP_ENV}" "${TARGET_ENV}"
trap - EXIT

echo "==> Successfully wrote secrets to ${TARGET_ENV}"
