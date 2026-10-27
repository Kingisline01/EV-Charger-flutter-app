# 🚀 ChargeShare Ubuntu Server Self-Hosting & Deployment Guide

This guide walks you through building the **ChargeShare** Flutter app (Web, Android APK, App Bundle) and deploying the complete backend stack (PostgreSQL 15 + PostGIS + pg_cron, Kong API Gateway, Supabase Auth/Storage/Realtime, and Nginx reverse proxy) on your own Ubuntu server.

---

## 1. Hardware & OS Requirements

| Component | Minimum | Recommended |
|---|---|---|
| **Operating System** | Ubuntu 20.04 / 22.04 / 24.04 LTS | Ubuntu 24.04 LTS |
| **CPU** | 2 vCPU | 4 vCPU |
| **RAM** | 2 GB (with swap enabled) | 4 GB - 8 GB |
| **Disk Storage** | 25 GB NVMe / SSD | 50 GB NVMe |
| **Public Ports** | 22 (SSH), 80 (HTTP), 443 (HTTPS) | Internal ports (5432, 8000, 3000) locked to localhost |

---

## 2. DNS Setup (Point Your Domain)

Add the following `A` records in your DNS provider (Cloudflare, Namecheap, Route 53, GoDaddy, Hostinger, etc.) pointing to your Ubuntu server's public IP:

```text
yourdomain.com        A    <YOUR_SERVER_IP>
api.yourdomain.com    A    <YOUR_SERVER_IP>
studio.yourdomain.com A    <YOUR_SERVER_IP>
```

> **Note:** If you do not have a domain yet, you can still test immediately using your server IP address! The deployment script automatically creates a fallback self-signed SSL certificate so Nginx starts without errors.

---

## 3. One-Command Automated Server Deployment

1. **SSH into your Ubuntu server:**
   ```bash
   ssh root@<YOUR_SERVER_IP>
   ```

2. **Clone your repository to `/opt/chargeshare` (or upload your project files):**
   ```bash
   git clone <YOUR_GIT_REPO_URL> /opt/chargeshare
   cd /opt/chargeshare
   ```

3. **(Optional) Configure your domain in `.env.production`:**
   If you have a domain name, configure it before running or let the script use default placeholders:
   ```bash
   cp deploy/.env.production.example deploy/.env.production
   nano deploy/.env.production
   # Set DOMAIN_NAME=yourdomain.com, API_EXTERNAL_URL=https://api.yourdomain.com
   ```

4. **Make the deployment script executable and run it:**
   ```bash
   chmod +x deploy/deploy-ubuntu.sh deploy/build-mobile.sh
   sudo ./deploy/deploy-ubuntu.sh
   ```

### What `deploy-ubuntu.sh` does automatically:
- Installs Docker Engine, Docker Compose, Git, UFW firewall, Nginx, Certbot, and Python 3.
- Configures the UFW firewall: only ports 22, 80, and 443 are open to the internet; internal ports (5432, 8000, 3000) are protected.
- Generates cryptographically secure random passwords and **valid HS256 JWT tokens** for `ANON_KEY` and `SERVICE_ROLE_KEY`.
- Starts the containerized Supabase stack (PostgreSQL, Kong, GoTrue Auth, Realtime, Storage, Studio).
- Automatically applies database migrations:
  - `0001_init.sql` (Core tables, PostGIS, exclusion constraints, pricing tiers)
  - `0002_auth_payments_security.sql` (Row-Level Security, location fuzzing, refunds, anti-abuse)
  - `0003_seed_chennai.sql` (Chennai EV hubs: Anna Nagar, OMR, T. Nagar, Guindy, Besant Nagar, Velachery)
- Deploys Nginx reverse proxy with rate limiting, WebSocket proxying, and fallback SSL.
- Installs a systemd auto-restart unit (`chargeshare-stack.service`) so the stack restarts automatically on server boot.

---

## 4. Enable Free SSL via Let's Encrypt (Certbot)

After running the deployment script and confirming your DNS has propagated to the server IP:

```bash
sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com -d studio.yourdomain.com
```

Certbot will replace the initial self-signed certificates with real HTTPS certificates and configure automatic renewal timers.

---

## 5. Building & Deploying the App

### A. Flutter Web App (Hosted on your Ubuntu Server)

You can build the web app on your local computer (Windows / macOS / Linux) and sync it to the Ubuntu server with a single command:

**On Windows (PowerShell):**
```powershell
# Build web app and sync directly to Ubuntu server:
.\deploy\build.ps1 -Target web -BackendUrl https://api.yourdomain.com -DeployServer root@<YOUR_SERVER_IP>
```

**On Linux / macOS / Git Bash:**
```bash
# Build web app:
flutter build web --release \
  --dart-define=SUPABASE_URL=https://api.yourdomain.com \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY_FROM_SERVER> \
  --dart-define=DEMO_MODE=false

# Sync to Ubuntu server:
scp -r build/web/* root@<YOUR_SERVER_IP>:/var/www/chargeshare/web/
```

Your web app is now immediately live at `https://yourdomain.com`!

---

### B. Mobile Apps (Android APK & App Bundle)

**On Windows (PowerShell):**
```powershell
# Build release APK:
.\deploy\build.ps1 -Target apk -BackendUrl https://api.yourdomain.com

# Build Google Play App Bundle (AAB):
.\deploy\build.ps1 -Target bundle -BackendUrl https://api.yourdomain.com
```

**On Linux / macOS / Git Bash:**
```bash
# Release APK:
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://api.yourdomain.com \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY_FROM_SERVER> \
  --dart-define=DEMO_MODE=false
```

Output files:
- **APK (direct installation):** `build/app/outputs/flutter-apk/app-release.apk`
- **AAB (Play Store release):** `build/app/outputs/bundle/release/app-release.aab`

---

## 6. Server Management & Maintenance

### Check Container Status
```bash
cd /opt/chargeshare/deploy
docker compose --env-file .env.production ps
```

### View Live Logs
```bash
# Database logs
docker logs -f chargeshare-db

# API Gateway logs
docker logs -f chargeshare-kong

# Auth logs
docker logs -f chargeshare-auth
```

### Automated Nightly Database Backup (pg_dump)
Add a cron job to take daily compressed backups:
```bash
sudo crontab -e
```
Add this line (runs every night at 2:00 AM):
```cron
0 2 * * * docker exec chargeshare-db pg_dump -U postgres -d postgres -F c -b -v -f /var/lib/postgresql/data/backup-$(date +\%F).dump
```

### Restarting the Services
```bash
sudo systemctl restart chargeshare-stack
# or
docker compose --env-file /opt/chargeshare/deploy/.env.production restart
```
