#!/usr/bin/env bash
# One-shot bootstrap for a fresh Rocky Linux 9 droplet running Starfall on Docker.
#
#   scp -r deploy/ root@<droplet>:/tmp/starfall-deploy/
#   ssh root@<droplet> 'bash /tmp/starfall-deploy/bootstrap.sh "ssh-ed25519 AAAA... ci@starfall"'
#
# Idempotent — safe to re-run. Performs, in order:
#   1. base packages + firewall (the six Starfall UDP ports)
#   2. Docker CE           (install-docker-rocky.sh)
#   3. deploy user         (create-deploy-user.sh)
#   4. /opt/starfall skeleton so the first CI deploy has somewhere to land
#
# Read it before running: it installs packages, opens firewall ports, creates a
# user, and grants that user restricted passwordless sudo.

set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
APP_DIR="${APP_DIR:-/opt/starfall}"
# All arguments, not just $1 — see the note in create-deploy-user.sh.
PUBKEY="$*"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Must match DUEL_PORT / TEAM_PORT / LOBBY_PORTS in scripts/config.gd and the
# port list in .env. Clients dial these by number.
QUEUE_PORTS=(27840 27841)
LOBBY_PORTS=(27850 27851 27852 27853)
ALL_PORTS=("${QUEUE_PORTS[@]}" "${LOBBY_PORTS[@]}")

if [[ $EUID -ne 0 ]]; then
    echo "bootstrap.sh must run as root (or via sudo)." >&2
    exit 1
fi
if [[ -z "${PUBKEY}" ]]; then
    echo "Usage: bootstrap.sh '<ssh public key for the deploy user>'" >&2
    exit 1
fi

echo "==> [1/4] Base packages and firewall"
dnf install -y --setopt=install_weak_deps=False firewalld policycoreutils-python-utils curl ca-certificates
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=ssh >/dev/null || true
for port in "${ALL_PORTS[@]}"; do
    firewall-cmd --permanent --add-port="${port}/udp" >/dev/null || true
done
firewall-cmd --reload
echo "    opened UDP: ${ALL_PORTS[*]}"

echo "==> [2/4] Docker"
bash "${SCRIPT_DIR}/install-docker-rocky.sh"

# Docker writes its own iptables rules for published ports and normally bypasses
# firewalld's zones. Putting the docker bridge in the trusted zone keeps the two
# from fighting; the ports above remain the boundary that matters.
firewall-cmd --permanent --zone=trusted --add-interface=docker0 >/dev/null 2>&1 || true
firewall-cmd --reload

echo "==> [3/4] Deploy user"
bash "${SCRIPT_DIR}/create-deploy-user.sh" "${PUBKEY}"   # quoted: one argument

echo "==> [4/4] Application directory"
install -d -m 0755 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${APP_DIR}"

# Written inline, not copied from ../.env.example: this script is normally
# scp'd on its own as deploy/, so a relative path to the repo root would not
# resolve — and a missing .env fails the first deploy at the pull step.
# Keep these defaults in step with .env.example and scripts/config.gd.
if [[ -f "${SCRIPT_DIR}/../.env.example" ]]; then
    SEED_SOURCE="${SCRIPT_DIR}/../.env.example"
else
    SEED_SOURCE=""
fi

if [[ -f "${APP_DIR}/.env" ]]; then
    echo "    ${APP_DIR}/.env already exists — left untouched"
elif [[ -n "${SEED_SOURCE}" ]]; then
    install -m 0640 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${SEED_SOURCE}" "${APP_DIR}/.env"
    echo "    seeded ${APP_DIR}/.env from .env.example"
else
    cat > "${APP_DIR}/.env" <<ENVFILE
# Seeded by bootstrap.sh. See .env.example in the repository for the annotated
# version. STARFALL_TAG is rewritten by each deploy.
STARFALL_IMAGE=${STARFALL_IMAGE:-ghcr.io/mrwells99/starfall}
STARFALL_TAG=latest

BIND_ADDRESS=0.0.0.0
DUEL_PORT=27840
TEAM_PORT=27841
LOBBY1_PORT=27850
LOBBY2_PORT=27851
LOBBY3_PORT=27852
LOBBY4_PORT=27853

DUEL_MIN_PLAYERS=2
TEAM_MIN_PLAYERS=2
REMATCH_DELAY=8

STARFALL_CPU_LIMIT=0.75
STARFALL_MEM_LIMIT=512M
ENVFILE
    chown "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}/.env"
    chmod 0640 "${APP_DIR}/.env"
    echo "    wrote default ${APP_DIR}/.env"
fi
echo "    >>> confirm STARFALL_IMAGE in ${APP_DIR}/.env matches your GHCR path"

echo
echo "==> Bootstrap complete."
echo
echo "Remaining manual steps:"
echo "  1. Point DNS: A record play.leafmods.com -> $(curl -4 -s --max-time 5 ifconfig.me || echo '<this droplet IP>')"
echo "  2. If the GHCR package is private, log the host in once:"
echo "       echo <PAT> | sudo docker login ghcr.io -u <github-user> --password-stdin"
echo "  3. Add the GitHub secrets listed in DEPLOYMENT.md, then push to main."
echo
echo "Verify after the first deploy:"
echo "  sudo docker compose -f ${APP_DIR}/docker-compose.yml ps"
echo "  ss -ulnp | grep 278        # expect six listeners"
