#!/usr/bin/env bash
# One-time addition for an existing Rocky 9 host; no game restart or tag change.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo on the game server." >&2; exit 1; }
APP_DIR="${APP_DIR:-/opt/starfall}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
dnf install -y --setopt=install_weak_deps=False python3
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$APP_DIR/downloads"
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi
echo "Downloads folder and host firewall ready. Also allow TCP 80/443 in the cloud firewall."
echo "The next successful main deployment starts HTTPS downloads."
echo "TCP 80/443 must be free for Starfall's Caddy service; inspect existing listeners below."
ss -ltnp '( sport = :80 or sport = :443 )'
