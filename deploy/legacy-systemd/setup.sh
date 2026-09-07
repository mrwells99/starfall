#!/usr/bin/env bash
# Bootstrap a fresh droplet for hosting Starfall.
# Supported distros: Ubuntu 22.04+/Debian 12+, Rocky/AlmaLinux/RHEL 9+, Fedora.
# Run once as root (or with sudo) on the droplet. Idempotent — safe to re-run.
#
# Review this script before running it — it installs packages, creates a
# system user, opens the Starfall UDP ports in the firewall, and installs a
# templated systemd unit plus one environment file per server instance.
#
# Usage:
#   scp -r deploy/ root@<droplet>:/tmp/starfall-deploy/
#   ssh root@<droplet> 'bash /tmp/starfall-deploy/setup.sh'
#
# Override via env vars if needed:
#   GODOT_VERSION=4.5.1-stable
#   GODOT_URL=<full url to Godot linux zip>
#   INSTALL_DIR=/opt/starfall
#   SERVICE_USER=starfall

set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1-stable}"
GODOT_URL="${GODOT_URL:-https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip}"
INSTALL_DIR="${INSTALL_DIR:-/opt/starfall}"
SERVICE_USER="${SERVICE_USER:-starfall}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "setup.sh must run as root (or via sudo)." >&2
    exit 1
fi

# Detect distro family so we can pick the right package manager / firewall tool.
DISTRO_ID="unknown"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
fi
case "${DISTRO_ID}" in
    ubuntu|debian)          FAMILY="debian" ;;
    rocky|rhel|almalinux|centos|fedora) FAMILY="rhel" ;;
    *)
        echo "Unsupported distro '${DISTRO_ID}'. Edit setup.sh to add support." >&2
        exit 1
        ;;
esac
echo "==> Detected ${DISTRO_ID} (family: ${FAMILY})"

echo "==> Installing base packages"
case "${FAMILY}" in
    debian)
        apt-get update
        apt-get install -y --no-install-recommends unzip rsync wget ca-certificates ufw fontconfig
        ;;
    rhel)
        dnf install -y unzip rsync wget ca-certificates firewalld fontconfig
        ;;
esac

# 27840/27841 are the duel and 3v3 queues; 27850-27853 are the private lobby
# pool. These must stay in step with scripts/config.gd.
QUEUE_PORTS=(27840 27841)
LOBBY_PORTS=(27850 27851 27852 27853)
ALL_PORTS=("${QUEUE_PORTS[@]}" "${LOBBY_PORTS[@]}")

echo "==> Opening firewall (SSH + UDP ${ALL_PORTS[*]})"
case "${FAMILY}" in
    debian)
        ufw allow 22/tcp || true
        for port in "${ALL_PORTS[@]}"; do
            ufw allow "${port}/udp" || true
        done
        ufw --force enable || true
        ;;
    rhel)
        systemctl enable --now firewalld
        firewall-cmd --permanent --add-service=ssh || true
        for port in "${ALL_PORTS[@]}"; do
            firewall-cmd --permanent --add-port="${port}/udp" || true
        done
        firewall-cmd --reload
        ;;
esac

echo "==> Creating service user ${SERVICE_USER}"
if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --home-dir "${INSTALL_DIR}" --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

echo "==> Preparing install dir ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"

echo "==> Installing Godot ${GODOT_VERSION}"
current_version="$(/usr/local/bin/godot --version 2>/dev/null || true)"
if [[ "${current_version}" != *"${GODOT_VERSION%-stable}"* ]]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    wget -q -O "${tmp}/godot.zip" "${GODOT_URL}"
    unzip -q "${tmp}/godot.zip" -d "${tmp}"
    binary="$(find "${tmp}" -maxdepth 2 -name 'Godot_v*' -type f -executable | head -n1)"
    if [[ -z "${binary}" ]]; then
        echo "Could not find Godot binary in downloaded zip." >&2
        exit 1
    fi
    install -m 0755 "${binary}" /usr/local/bin/godot
fi
/usr/local/bin/godot --version

echo "==> Installing systemd template and instance configs"
install -m 0644 "${SCRIPT_DIR}/starfall@.service" /etc/systemd/system/starfall@.service
mkdir -p /etc/starfall
install -m 0644 "${SCRIPT_DIR}/instances/"*.env /etc/starfall/
systemctl daemon-reload
for env_file in "${SCRIPT_DIR}/instances/"*.env; do
    instance="$(basename "${env_file}" .env)"
    systemctl enable "starfall@${instance}"
done

echo
echo "==> Setup complete."
if [[ "${FAMILY}" == "rhel" ]] && command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
    echo
    echo "Note: SELinux is Enforcing. If the service fails to start, check:"
    echo "  sudo ausearch -m avc -ts recent"
    echo "For a quick isolation test only: 'sudo setenforce 0' (then re-enable with 'setenforce 1')."
fi
echo
echo "Next steps (from your dev machine):"
echo "  1. First deploy:   ./deploy/deploy.sh   (syncs source and starts every instance)"
echo "  2. Check status:   ssh root@<droplet> systemctl status 'starfall@*'"
echo "  3. Watch logs:     ssh root@<droplet> journalctl -u 'starfall@*' -f"
