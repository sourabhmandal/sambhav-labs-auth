# Zitadel on AWS Lightsail — Minimal Cost SSH Deployment

A simplified, low-overhead deployment setup for Zitadel on AWS Lightsail using **SSH**, with secrets pulled from AWS Secrets Manager (**`prod/sambhav-zitadel`**).

> [!TIP]
> **Minimal Infrastructure Cost**:
> - **No CloudFormation**: Zero template management or stack maintenance.
> - **No SSM Hybrid / Paid Tiers**: Direct SSH access to the Lightsail instance.
> - **No S3 / Automated Backup Costs**: No automated bucket creation or storage fees.
> - **Centralized Secrets**: Secrets are pulled from **`prod/sambhav-zitadel`** and written to `/opt/zitadel/.env` for `deploy.sh`.
> - **On-Demand Deployments**: Deployments run only when triggered via GitHub Actions (`workflow_dispatch`) or terminal SSH.

---

## Architecture

```
GitHub Actions (workflow_dispatch)
   │
   ├─ 1. Pulls secret "prod/sambhav-zitadel" from AWS Secrets Manager
   ├─ 2. Formats secret JSON into .env
   ├─ 3. Copies .env to Lightsail via SCP (/tmp/.env -> /opt/zitadel/.env)
   │
   └─ 4. Executes via SSH:
         sudo /opt/zitadel/scripts/deploy.sh <git_ref>
            ├─ Git pull / checkout requested ref
            ├─ Reads /opt/zitadel/.env
            ├─ docker compose -f zitadel-compose.yml pull
            ├─ docker compose -f zitadel-compose.yml up zitadel-init & setup
            ├─ docker compose -f zitadel-compose.yml up -d zitadel-api zitadel-login proxy
            └─ Verifies service health
```

---

## 4 Simple Steps to Setup & Deploy

### Step 1: Lightsail Instance & Firewall
1. Create a Lightsail instance:
   - **OS**: Ubuntu 24.04 LTS
   - **Plan**: 2 GB – 4 GB RAM recommended
2. Attach a **Static IP** to the instance.
3. Open firewall ports in Lightsail Networking:
   - **TCP 22** (SSH)
   - **TCP 80** (HTTP)
   - **TCP 443** (HTTPS)
4. Add an `A` record in your DNS provider (e.g., Cloudflare):
   - `auth.sambhavlabs.com` ➔ `<Lightsail-Static-IP>`

---

### Step 2: One-Time Server Setup
Connect to the server via SSH:
```bash
ssh ubuntu@<LIGHTSAIL_STATIC_IP>
```

Run the bootstrap setup to install Docker and clone the repository:
```bash
# Clone the repository to /opt/zitadel
sudo git clone https://github.com/19mandal97/sambhav-labs-auth.git /opt/zitadel

# Run the bootstrap script
sudo bash /opt/zitadel/scripts/bootstrap-server.sh
```

---

### Step 3: Secrets in AWS Secrets Manager
Ensure the secret named **`prod/sambhav-zitadel`** exists in AWS Secrets Manager (region `us-east-1`).

Key-values expected inside the secret:
```json
{
  "ZITADEL_DOMAIN": "auth.sambhavlabs.com",
  "ZITADEL_VERSION": "v2.67.0",
  "ZITADEL_MASTERKEY": "<32-character-alphanumeric-key>",
  "LOGIN_SESSION_COOKIE_SECRET": "<32-character-alphanumeric-key>",
  "ZITADEL_DATABASE_POSTGRES_DSN": "postgres://zitadel:<password>@<db-host>:5432/zitadel?sslmode=require",
  "ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME": "admin@sambhavlabs.com",
  "ZITADEL_FIRSTINSTANCE_ORG_HUMAN_EMAIL_ADDRESS": "admin@sambhavlabs.com",
  "ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD": "<temporary-admin-password>",
  "CF_DNS_API_TOKEN": "<cloudflare-dns-token>",
  "ACME_EMAIL": "admin@sambhavlabs.com"
}
```

---

### Step 4: Configure GitHub Secrets & Deploy

In your GitHub repository, go to **Settings** → **Secrets and variables** → **Actions** and add:

#### Repository Secrets:
| Secret Name | Description |
|---|---|
| `LIGHTSAIL_HOST` | Static IP of your Lightsail instance |
| `LIGHTSAIL_USERNAME` | `ubuntu` |
| `LIGHTSAIL_SSH_KEY` | Private SSH key with access to your Lightsail instance |
| `AWS_ACCESS_KEY_ID` | AWS Access Key with `secretsmanager:GetSecretValue` on `prod/sambhav-zitadel` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |

#### Repository Variables (Optional):
| Variable Name | Default |
|---|---|
| `AWS_REGION` | `us-east-1` |

#### Triggering Deployments:
1. Go to **Actions** → **Deploy Zitadel to Lightsail (SSH)**.
2. Click **Run workflow** (specify branch, tag, or commit; default `main`).
3. GitHub Actions will:
   - Pull `prod/sambhav-zitadel` from AWS Secrets Manager.
   - Format and transfer `.env` to `/opt/zitadel/.env`.
   - Execute `/opt/zitadel/scripts/deploy.sh` over SSH.
   - Wait for container health checks to confirm a healthy deployment.

---

## Manual Deployment (Directly from Server)

If you are logged into the Lightsail server via SSH, you can also pull the secrets and deploy anytime:

```bash
# Pull latest secrets from AWS Secrets Manager into .env
sudo /opt/zitadel/scripts/pull-secrets.sh

# Run deployment
sudo /opt/zitadel/scripts/deploy.sh main
```

---

## Operating & Troubleshooting

Inside `/opt/zitadel`:
- **Check container status**:
  ```bash
  sudo docker compose -f zitadel-compose.yml ps
  ```
- **Inspect Zitadel API logs**:
  ```bash
  sudo docker compose -f zitadel-compose.yml logs -f --tail 100 zitadel-api
  ```
- **Inspect Traefik proxy / SSL logs**:
  ```bash
  sudo docker compose -f zitadel-compose.yml logs -f proxy
  ```
- **Restart stack**:
  ```bash
  sudo docker compose -f zitadel-compose.yml restart
  ```