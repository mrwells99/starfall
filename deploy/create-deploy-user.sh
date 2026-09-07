#!/usr/bin/env bash
# Create the unprivileged CI deploy user.
#
#   sudo bash deploy/create-deploy-user.sh "ssh-ed25519 AAAA... ci@ringfall"
#
# The user is deliberately NOT in the `docker` group. Membership in that group
# is equivalent to root — any member can start a container that mounts / and
# writes to it. Instead this user gets passwordless sudo for exactly one
# root-owned wrapper script, which runs `docker compose pull` and
# `docker compose up -d` and nothing else.

set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
APP_DIR="${APP_DIR:-/opt/ringfall}"
WRAPPER="/usr/local/bin/ringfall-deploy"
STATUS_WRAPPER="/usr/local/bin/ringfall-status"
PUBKEY="${1:-}"

if [[ $EUID -ne 0 ]]; then
    echo "create-deploy-user.sh must run as root (or via sudo)." >&2
    exit 1
fi
if [[ -z "${PUBKEY}" ]]; then
    echo "Usage: create-deploy-user.sh '<ssh public key>'" >&2
    echo "Generate one with: ssh-keygen -t ed25519 -C ci@ringfall -f ringfall_deploy" >&2
    exit 1
fi
if [[ "${PUBKEY}" != ssh-* && "${PUBKEY}" != ecdsa-* ]]; then
    echo "That does not look like an SSH public key. Did you paste the private key by mistake?" >&2
    exit 1
fi

echo "==> Creating ${DEPLOY_USER}"
if ! id -u "${DEPLOY_USER}" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "${DEPLOY_USER}"
fi

echo "==> Installing authorized key"
install -d -m 0700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
touch "/home/${DEPLOY_USER}/.ssh/authorized_keys"
grep -qxF "${PUBKEY}" "/home/${DEPLOY_USER}/.ssh/authorized_keys" \
    || echo "${PUBKEY}" >> "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chmod 0600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"

echo "==> Preparing ${APP_DIR}"
# The deploy user owns the compose file and .env so scp can replace them, but
# has no rights over the Docker socket.
install -d -m 0755 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${APP_DIR}"

echo "==> Installing the deploy wrapper at ${WRAPPER}"
cat > "${WRAPPER}" <<WRAP
#!/usr/bin/env bash
# Root-owned. The deploy user may run ONLY this, via sudo, and it takes no
# arguments — there is nothing here for a caller to redirect at another target.
set -euo pipefail
cd "${APP_DIR}"

if [[ ! -f docker-compose.yml ]]; then
    echo "No docker-compose.yml in ${APP_DIR}" >&2
    exit 1
fi

echo "--- pulling ---"
docker compose pull
echo "--- starting ---"
docker compose up -d --remove-orphans

# Verification lives here rather than in CI so that a hand-run deploy is held to
# the same bar as an automated one.
expected=\$(docker compose config --services | wc -l)
echo "--- waiting for \${expected} healthy containers ---"
for attempt in \$(seq 1 30); do
    healthy=\$(docker ps --filter "label=com.docker.compose.project=\$(basename "${APP_DIR}")" \
                 --format '{{.Status}}' | grep -c '(healthy)' || true)
    if [[ "\${healthy}" -ge "\${expected}" ]]; then
        echo "All \${expected} containers healthy."
        docker image prune -f --filter "until=168h" >/dev/null || true
        docker compose ps
        exit 0
    fi
    sleep 5
done

echo "Only \${healthy}/\${expected} containers healthy after 150s." >&2
docker compose ps >&2
docker compose logs --tail=40 >&2
exit 1
WRAP
chmod 0755 "${WRAPPER}"
chown root:root "${WRAPPER}"

echo "==> Installing the read-only status wrapper at ${STATUS_WRAPPER}"
cat > "${STATUS_WRAPPER}" <<WRAP
#!/usr/bin/env bash
# Root-owned, read-only: container state and recent logs. Safe to grant broadly.
set -euo pipefail
cd "${APP_DIR}"
docker compose ps
echo
docker compose logs --tail="\${1:-40}" --no-color
WRAP
chmod 0755 "${STATUS_WRAPPER}"
chown root:root "${STATUS_WRAPPER}"

echo "==> Granting restricted sudo"
# Two exact commands, no wildcards. A wildcard here would let the deploy user
# pass arbitrary arguments to docker, which is close to handing over root.
cat > /etc/sudoers.d/ringfall-deploy <<SUDO
${DEPLOY_USER} ALL=(root) NOPASSWD: ${WRAPPER}
${DEPLOY_USER} ALL=(root) NOPASSWD: ${STATUS_WRAPPER}
SUDO
chmod 0440 /etc/sudoers.d/ringfall-deploy
visudo -cf /etc/sudoers.d/ringfall-deploy

echo
echo "==> Done. ${DEPLOY_USER} can run:"
echo "      sudo ${WRAPPER}    (pull + restart + health gate)"
echo "      sudo ${STATUS_WRAPPER}    (read-only status and logs)"
echo "    It is NOT in the docker group, which would be root-equivalent."
