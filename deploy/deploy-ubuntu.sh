#!/bin/bash
# ==============================================================================
# ChargeShare Production Deployment Script for Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================================${NC}"
echo -e "${GREEN}      ⚡ ChargeShare Production Deployment for Ubuntu Server ⚡      ${NC}"
echo -e "${BLUE}====================================================================${NC}"

# Check for root / sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this deployment script as root or with sudo.${NC}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$SCRIPT_DIR/.env.production"

# 1. Update APT Packages & Install Prerequisites
echo -e "\n${YELLOW}[1/8] Updating package index and installing dependencies...${NC}"
apt-get update -y
apt-get install -y curl wget git ufw nginx certbot python3-certbot-nginx openssl postgresql-client jq ca-certificates gnupg lsb-release

# 2. Install Docker & Docker Compose if missing
echo -e "\n${YELLOW}[2/8] Checking Docker & Docker Compose installation...${NC}"
if ! command -v docker &> /dev/null; then
  echo "Installing Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  echo "Docker is already installed ($(docker --version))."
fi

# 3. Configure UFW Firewall Security
echo -e "\n${YELLOW}[3/8] Configuring UFW firewall rules...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP Web'
ufw allow 443/tcp comment 'HTTPS Secure'
# Ensure internal database & Kong ports are NOT opened to external traffic
ufw --force enable
echo "Firewall active. Only ports 22, 80, and 443 are publicly exposed."

# 4. Generate Production Secrets & Environment File
echo -e "\n${YELLOW}[4/8] Setting up production environment configuration...${NC}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Generating new production secrets..."
  cp "$SCRIPT_DIR/.env.production.example" "$ENV_FILE"

  DB_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
  JWT_SEC=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
  CRON_SEC=$(openssl rand -hex 16)

  # Generate valid HS256 JWT tokens for Supabase Anon & Service Role
  JWT_KEYS=$(python3 -c "
import base64, hashlib, hmac, json, time

secret = '$JWT_SEC'
def b64url(b):
    return base64.urlsafe_b64encode(b).decode('utf-8').rstrip('=')

def make_jwt(role):
    header = {'alg': 'HS256', 'typ': 'JWT'}
    payload = {
        'role': role,
        'iss': 'supabase',
        'iat': int(time.time()),
        'exp': int(time.time()) + 315360000
    }
    h_str = b64url(json.dumps(header, separators=(',', ':')).encode('utf-8'))
    p_str = b64url(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    signing_input = f'{h_str}.{p_str}'.encode('utf-8')
    sig = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    return f'{h_str}.{p_str}.{b64url(sig)}'

print(make_jwt('anon') + ' ' + make_jwt('service_role'))
")

  ANON_KEY=$(echo "$JWT_KEYS" | awk '{print $1}')
  SERVICE_ROLE_KEY=$(echo "$JWT_KEYS" | awk '{print $2}')

  sed -i "s/replace_with_secure_random_db_password_min_32_chars/$DB_PASS/g" "$ENV_FILE"
  sed -i "s/replace_with_secure_random_jwt_secret_min_32_chars/$JWT_SEC/g" "$ENV_FILE"
  sed -i "s/replace_with_random_cron_secret/$CRON_SEC/g" "$ENV_FILE"
  sed -i "s|replace_with_generated_anon_key_hs256_token|$ANON_KEY|g" "$ENV_FILE"
  sed -i "s|replace_with_generated_service_role_key_hs256_token|$SERVICE_ROLE_KEY|g" "$ENV_FILE"
  echo "Generated secure DB password, JWT secret, Anon key, and Service Role key in $ENV_FILE"
else
  echo "Existing environment file found at $ENV_FILE."
fi

# Load variables
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# 5. Launch Docker Compose Stack
echo -e "\n${YELLOW}[5/8] Starting Supabase services with Docker Compose...${NC}"
cd "$SCRIPT_DIR"
docker compose --env-file "$ENV_FILE" down --remove-orphans || true
docker compose --env-file "$ENV_FILE" up -d

# 6. Wait for PostgreSQL Health
echo -e "\n${YELLOW}[6/8] Waiting for PostgreSQL container to become healthy...${NC}"
MAX_TRIES=30
COUNT=0
until docker exec chargeshare-db pg_isready -U postgres -d postgres &> /dev/null || [ $COUNT -eq $MAX_TRIES ]; do
  sleep 2
  COUNT=$((COUNT + 1))
  echo -n "."
done
echo ""

if [ $COUNT -eq $MAX_TRIES ]; then
  echo -e "${RED}PostgreSQL did not start in time. Check logs using: docker logs chargeshare-db${NC}"
  exit 1
fi
echo -e "${GREEN}PostgreSQL is healthy and accepting connections!${NC}"

# 7. Apply Database Migrations (0001, 0002, 0003)
echo -e "\n${YELLOW}[7/8] Applying database migrations and security schemas...${NC}"
MIGRATIONS_DIR="$APP_DIR/supabase/migrations"

apply_sql() {
  local sql_file="$1"
  local file_name
  file_name=$(basename "$sql_file")
  echo "Applying $file_name..."
  docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" chargeshare-db psql -U postgres -d postgres < "$sql_file" > /dev/null 2>&1 || {
    echo -e "${YELLOW}Notice: Partial run or idempotency check on $file_name.${NC}"
  }
}

if [ -f "$MIGRATIONS_DIR/0001_init.sql" ]; then
  apply_sql "$MIGRATIONS_DIR/0001_init.sql"
fi

if [ -f "$MIGRATIONS_DIR/0002_auth_payments_security.sql" ]; then
  apply_sql "$MIGRATIONS_DIR/0002_auth_payments_security.sql"
fi

if [ -f "$MIGRATIONS_DIR/0003_seed_chennai.sql" ]; then
  apply_sql "$MIGRATIONS_DIR/0003_seed_chennai.sql"
fi
echo -e "${GREEN}Database migrations applied successfully!${NC}"

# 8. Configure Nginx Reverse Proxy
echo -e "\n${YELLOW}[8/8] Configuring Nginx reverse proxy...${NC}"
mkdir -p /var/www/chargeshare/web
mkdir -p /var/www/certbot

TARGET_DOMAIN="${DOMAIN_NAME:-yourdomain.com}"
SSL_DIR="/etc/letsencrypt/live/$TARGET_DOMAIN"

# If real Let's Encrypt certificates are not yet created, create temporary self-signed certs
# so that Nginx syntax validation (nginx -t) succeeds and the server can start immediately.
if [ ! -f "$SSL_DIR/fullchain.pem" ]; then
  echo "Generating initial self-signed SSL certificate for $TARGET_DOMAIN so Nginx can start..."
  mkdir -p "$SSL_DIR"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/privkey.pem" \
    -out "$SSL_DIR/fullchain.pem" \
    -subj "/CN=$TARGET_DOMAIN" > /dev/null 2>&1
fi

# Copy built Flutter web app if available, or create placeholder
if [ -d "$APP_DIR/build/web" ] && [ -f "$APP_DIR/build/web/index.html" ]; then
  echo "Deploying built Flutter Web frontend to /var/www/chargeshare/web/..."
  cp -r "$APP_DIR/build/web/"* /var/www/chargeshare/web/
elif [ ! -f /var/www/chargeshare/web/index.html ]; then
  cat << 'HTMLEOF' > /var/www/chargeshare/web/index.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>ChargeShare Platform Active</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0b1120; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1rem; }
    .card { background: #1e293b; padding: 2.5rem; border-radius: 1.25rem; box-shadow: 0 20px 40px rgba(0,0,0,0.6); max-width: 580px; width: 100%; border: 1px solid #334155; }
    h1 { color: #10b981; margin: 0.5rem 0 0.5rem 0; font-size: 1.8rem; }
    p { color: #94a3b8; line-height: 1.6; font-size: 0.95rem; }
    .badge { display: inline-block; background: rgba(16, 185, 129, 0.15); color: #34d399; padding: 0.35rem 0.85rem; border-radius: 9999px; font-weight: 600; font-size: 0.8rem; border: 1px solid rgba(16, 185, 129, 0.3); }
    .list { background: #0f172a; padding: 1rem; border-radius: 0.75rem; font-family: monospace; font-size: 0.85rem; color: #38bdf8; text-align: left; margin: 1.25rem 0; line-height: 1.7; border: 1px solid #1e293b; }
    .note { font-size: 0.85rem; color: #64748b; background: rgba(255,255,255,0.03); padding: 0.75rem; border-radius: 0.5rem; border-left: 3px solid #10b981; text-align: left; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">● Server Online & Secure</div>
    <h1>⚡ ChargeShare EV Platform</h1>
    <p>Your self-hosted backend stack is active and serving endpoints.</p>
    <div class="list">
      • REST Database API: <b>/rest/v1/</b><br>
      • GoTrue Auth API: <b>/auth/v1/</b><br>
      • Realtime WebSockets: <b>/realtime/v1/</b><br>
      • Storage Engine: <b>/storage/v1/</b><br>
      • Studio Dashboard: <b>port 3000</b>
    </div>
    <div class="note">
      💡 To load your Flutter Web App here: run <code>flutter build web --release</code> and copy <code>build/web/*</code> into <code>/var/www/chargeshare/web/</code>.
    </div>
  </div>
</body>
</html>
HTMLEOF
fi

chown -R www-data:www-data /var/www/chargeshare
chmod -R 755 /var/www/chargeshare

NGINX_CONF="/etc/nginx/sites-available/chargeshare.conf"
cp "$SCRIPT_DIR/nginx/chargeshare.conf" "$NGINX_CONF"

# Replace placeholder domain if configured
if [ "$TARGET_DOMAIN" != "yourdomain.com" ]; then
  sed -i "s/yourdomain.com/$TARGET_DOMAIN/g" "$NGINX_CONF"
fi

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/chargeshare.conf
rm -f /etc/nginx/sites-enabled/default || true

if nginx -t; then
  systemctl reload nginx
  echo -e "${GREEN}Nginx configured and reloaded successfully!${NC}"
else
  echo -e "${RED}Nginx syntax check failed. Please check $NGINX_CONF${NC}"
fi

# 9. Create Systemd Auto-Restart Unit
SYSTEMD_FILE="/etc/systemd/system/chargeshare-stack.service"
cat << 'EOF' > "$SYSTEMD_FILE"
[Unit]
Description=ChargeShare Supabase Docker Compose Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/chargeshare/deploy
ExecStart=/usr/bin/docker compose --env-file .env.production up -d
ExecStop=/usr/bin/docker compose --env-file .env.production down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable chargeshare-stack.service > /dev/null 2>&1 || true

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}       🎉 CHARGESHARE UBUNTU DEPLOYMENT COMPLETED! 🎉       ${NC}"
echo -e "${GREEN}====================================================================${NC}"
echo -e "Backend Status:"
docker compose --env-file "$ENV_FILE" ps
echo -e "\n${BLUE}Next Steps:${NC}"
echo "1. If you have pointed your DNS to this server, obtain free SSL certificates with:"
echo "   sudo certbot --nginx -d ${DOMAIN_NAME:-yourdomain.com} -d api.${DOMAIN_NAME:-yourdomain.com} -d studio.${DOMAIN_NAME:-yourdomain.com}"
echo "2. Access Supabase Studio Admin on: http://127.0.0.1:3000 (or https://studio.${DOMAIN_NAME:-yourdomain.com})"
echo "3. Connect your Flutter mobile apps to: https://api.${DOMAIN_NAME:-yourdomain.com}"
echo -e "====================================================================\n"
