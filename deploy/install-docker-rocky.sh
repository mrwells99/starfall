#!/usr/bin/env bash
# Install Docker CE + the compose plugin on Rocky Linux 9 (or RHEL/AlmaLinux 9).
# Idempotent. Run as root.
#
#   sudo bash deploy/install-docker-rocky.sh
#
# Deliberately uses Docker's own repo rather than the distro's `podman-docker`
# shim: docker compose v2, healthchecks and `--init` all behave as documented
# here, and the CI workflow assumes real Docker.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "install-docker-rocky.sh must run as root (or via sudo)." >&2
    exit 1
fi

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        rocky|rhel|almalinux|centos) ;;
        *) echo "This script targets Rocky/RHEL/Alma. Detected '${ID:-unknown}'." >&2; exit 1 ;;
    esac
fi

echo "==> Removing distro podman/docker shims if present"
dnf remove -y podman-docker runc >/dev/null 2>&1 || true

echo "==> Adding Docker CE repository"
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null \
    || dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/centos/docker-ce.repo

echo "==> Installing Docker Engine and the compose plugin"
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Configuring the daemon"
install -d -m 0755 /etc/docker
# Log caps are set here as well as in compose so that *any* container on this
# host — including one started by hand while debugging — cannot fill the disk.
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "no-new-privileges": true,
  "userland-proxy": false
}
JSON

echo "==> Enabling and starting Docker"
systemctl enable --now docker
sleep 2
docker version --format '{{.Server.Version}}'
docker compose version

echo
echo "==> Docker installed."
echo "SELinux: $(getenforce 2>/dev/null || echo 'not present')"
echo "Ringfall mounts no host volumes, so no :z/:Z relabelling is required."
