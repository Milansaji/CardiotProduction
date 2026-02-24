#!/usr/bin/env bash
# ============================================================
#  update.sh — Pull latest code and reload PM2 processes
#  Run after every git push to the VPS:
#    bash update.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Pulling latest code..."
cd "$APP_DIR"
git pull origin main
success "Code updated"

info "Updating backend deps..."
npm install --prefix "$APP_DIR/backend" --omit=dev
success "Backend deps OK"

info "Updating frontend deps & rebuilding..."
npm install --prefix "$APP_DIR/Frontend"
npm run build --prefix "$APP_DIR/Frontend"
success "Frontend rebuilt"

info "Updating cardiot-bot deps..."
npm install --prefix "$APP_DIR/cardiot-bot-main"
success "Bot deps OK"

info "Reloading PM2 (zero-downtime)..."
pm2 reload backend
pm2 reload cardiot-bot
pm2 reload frontend
pm2 save
success "All processes reloaded"

echo ""
success "Update complete! Run 'pm2 logs' to verify."
