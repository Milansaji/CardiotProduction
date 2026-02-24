#!/usr/bin/env bash
# ============================================================
#  deploy.sh — One-shot VPS setup for WhatsApp CRM
#  Run ONCE on a fresh Ubuntu 22.04 / Debian droplet:
#    chmod +x deploy.sh && sudo bash deploy.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Please run as root: sudo bash deploy.sh"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "App root: $APP_DIR"

# ── 1. System packages ────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq
apt-get install -y -qq curl git ufw build-essential
success "System packages ready"

# ── 2. Node.js 20 LTS ────────────────────────────────────────
if ! command -v node &>/dev/null || [[ $(node -v | cut -d. -f1 | tr -d 'v') -lt 18 ]]; then
    info "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi
success "Node $(node -v) | npm $(npm -v)"

# ── 3. PM2 (global) ──────────────────────────────────────────
if ! command -v pm2 &>/dev/null; then
    info "Installing PM2 globally..."
    npm install -g pm2
fi
success "PM2 $(pm2 --version)"

# ── 4. Environment files ──────────────────────────────────────
info "Checking environment files..."

check_env() {
    local dir="$1" label="$2"
    if [[ ! -f "$dir/.env" ]]; then
        if [[ -f "$dir/.env.example" ]]; then
            cp "$dir/.env.example" "$dir/.env"
            warn "$label/.env created from example — FILL IT IN NOW"
            warn "  nano $dir/.env"
            echo ""
            read -rp "Press ENTER after editing $dir/.env ..."
        else
            error "$dir/.env missing and no .env.example found!"
        fi
    else
        success "$label/.env exists"
    fi
}

check_env "$APP_DIR/backend"          "backend"
check_env "$APP_DIR/Frontend"         "Frontend"
check_env "$APP_DIR/cardiot-bot-main" "cardiot-bot-main"

# ── 5. Install dependencies ───────────────────────────────────
info "Installing backend dependencies..."
npm install --prefix "$APP_DIR/backend" --omit=dev
success "backend/node_modules ready"

info "Installing Frontend dependencies..."
npm install --prefix "$APP_DIR/Frontend"
success "Frontend/node_modules ready"

info "Installing cardiot-bot dependencies..."
npm install --prefix "$APP_DIR/cardiot-bot-main"
success "cardiot-bot-main/node_modules ready"

info "Installing root dependencies (pm2)..."
npm install --prefix "$APP_DIR" --omit=dev
success "Root node_modules ready"

# ── 6. Build Frontend ─────────────────────────────────────────
info "Building React frontend..."
npm run build --prefix "$APP_DIR/Frontend"
success "Frontend built → Frontend/dist/"

# ── 7. Create runtime directories ────────────────────────────
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/backend/uploads"
success "logs/ and backend/uploads/ ready"

# ── 8. Firewall ───────────────────────────────────────────────
info "Configuring UFW firewall..."
ufw --force enable
ufw allow ssh comment 'SSH'
ufw allow 3001/tcp comment 'Backend API'
ufw allow 3002/tcp comment 'Cardiot bot webhook'
ufw allow 8080/tcp comment 'React frontend'
ufw reload
success "Ports open: SSH, 3001 (backend), 3002 (bot), 8080 (frontend)"

# ── 9. Start PM2 ─────────────────────────────────────────────
info "Starting PM2 processes..."
cd "$APP_DIR"
pm2 delete ecosystem.config.cjs 2>/dev/null || true
pm2 start ecosystem.config.cjs --env production
pm2 save
success "PM2 processes running"
pm2 list

# ── 10. Startup hook (auto-start on reboot) ───────────────────
info "Installing PM2 startup hook..."
# Run as the non-root user who owns the files
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
STARTUP=$(pm2 startup systemd -u "$REAL_USER" --hp "/home/$REAL_USER" 2>&1 | grep '^sudo' | head -1 || true)
if [[ -n "$STARTUP" ]]; then
    eval "$STARTUP"
    success "PM2 will auto-start on reboot"
else
    warn "Run manually: pm2 startup  then paste the printed command"
fi

# ── Done ─────────────────────────────────────────────────────
VPS_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "YOUR_VPS_IP")
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Frontend${NC}     http://$VPS_IP:8080"
echo -e "  ${GREEN}Backend API${NC}  http://$VPS_IP:3001"
echo -e "  ${GREEN}Bot Webhook${NC}  http://$VPS_IP:3002/webhook"
echo ""
echo -e "  ${YELLOW}Set Meta webhook to:${NC} http://$VPS_IP:3001/webhook"
echo ""
echo -e "  Logs:         pm2 logs"
echo -e "  Status:       pm2 list"
echo -e "  Restart all:  pm2 restart all"
echo -e "  Update later: bash update.sh"
echo ""
