# Sambhav Labs Auth (Zitadel on AWS Lightsail)

Production-ready deployment configuration for [Zitadel](https://zitadel.com/) identity and access management on **AWS Lightsail** with **Traefik** reverse proxy and automatic SSL via **Cloudflare DNS challenge**.

---

## Architecture Overview

- **Zitadel API (`zitadel-api`)**: Core IAM engine and authentication endpoints (HTTP/2 cleartext backend).
- **Zitadel Login UI (`zitadel-login`)**: Next.js login user interface.
- **Traefik Proxy (`proxy`)**: TLS termination with Let's Encrypt certificates using the Cloudflare DNS-01 ACME challenge.
- **External PostgreSQL**: Database backend (PostgreSQL 14+).
- **AWS Secrets Manager**: Centralized secret storage under secret name `prod/sambhav-zitadel`.
- **Deployment via SSH**: Triggered on-demand via GitHub Actions (`workflow_dispatch`) or terminal SSH.

---

## Quick Reference

### 1. Generating 32-Character Secrets
Zitadel requires a 32-character masterkey and cookie secret:
```bash
openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32; echo
```

### 2. Manual Deployment via SSH
From your local terminal:
```bash
ssh ubuntu@<LIGHTSAIL_STATIC_IP> "sudo /opt/zitadel/scripts/deploy.sh main"
```

### 3. Setup Guide
For the complete step-by-step installation and server bootstrap guide, read:
👉 **[auto-deploy-setup.md](auto-deploy-setup.md)**

---

## Repository Structure

```
├── .github/workflows/
│   └── deploy.yml           # Manual GitHub Actions workflow (workflow_dispatch via SSH)
├── config/
│   ├── db-init.sql          # External PostgreSQL database initialization
│   └── env.example          # Reference environment file (.env template)
├── scripts/
│   ├── bootstrap-server.sh  # One-time Lightsail instance setup
│   ├── deploy.sh            # Main deployment & healthcheck script
│   └── pull-secrets.sh      # Secrets Manager puller for prod/sambhav-zitadel
├── auto-deploy-setup.md     # Comprehensive deployment documentation
└── zitadel-compose.yml      # Docker Compose stack for Zitadel + Traefik
```

---

## Operating Commands on Lightsail

Run these commands inside `/opt/zitadel`:

- **Check Service Status**:
  ```bash
  sudo docker compose -f zitadel-compose.yml ps
  ```
- **Inspect Application Logs**:
  ```bash
  sudo docker compose -f zitadel-compose.yml logs -f --tail 100 zitadel-api
  ```
- **Inspect Traefik & ACME Logs**:
  ```bash
  sudo docker compose -f zitadel-compose.yml logs -f proxy
  ```
- **Restart Services**:
  ```bash
  sudo docker compose -f zitadel-compose.yml restart
  ```
