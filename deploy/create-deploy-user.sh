#!/usr/bin/env bash
# Create the unprivileged CI deploy user.
#
#   sudo bash deploy/create-deploy-user.sh "ssh-ed25519 AAAA... ci@starfall"
#
# The user is deliberately NOT in the `docker` group. Membership in that group
# is equivalent to root — any member can start a container that mounts / and
# writes to it. Instead this user gets passwordless sudo for exactly one
# root-owned wrapper script, which runs `docker compose pull` and
# `docker compose up -d` and nothing else.

set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
APP_DIR="${APP_DIR:-/opt/starfall}"
WRAPPER="/usr/local/bin/starfall-deploy"
STATUS_WRAPPER="/usr/local/bin/starfall-status"
# Joined from every argument, not just $1: an unquoted key on the command line
# arrives as three words (type, blob, comment) and taking only $1 would silently
# install the string "ssh-ed25519" as the authorized key.
PUBKEY="$*"

if [[ $EUID -ne 0 ]]; then
    echo "create-deploy-user.sh must run as root (or via sudo)." >&2
    exit 1
fi
if [[ -z "${PUBKEY}" ]]; then
    echo "Usage: create-deploy-user.sh '<ssh public key>'" >&2
    echo "Generate one with: ssh-keygen -t ed25519 -C ci@starfall -f starfall_deploy" >&2
    exit 1
fi
# This check MUST come first: `ssh-keygen -l` happily fingerprints a private
# key and exits 0, so the validation below would pass one straight through and
# write the secret into authorized_keys.
if [[ "${PUBKEY}" == *"PRIVATE KEY"* ]]; then
    echo "That is a PRIVATE key. Pass the .pub half instead." >&2
    exit 1
fi
# Validate with ssh-keygen rather than a prefix match — a prefix match accepts
# the bare word "ssh-ed25519", which is exactly the failure this guards against.
_keycheck="$(mktemp)"
trap 'rm -f "${_keycheck}"' EXIT
printf '%s\n' "${PUBKEY}" > "${_keycheck}"
if ! ssh-keygen -l -f "${_keycheck}" >/dev/null 2>&1; then
    echo "Not a valid SSH public key:" >&2
    echo "  ${PUBKEY}" >&2
    echo >&2
    echo "Quote it — an unquoted key splits into separate arguments:" >&2
    echo "  bash create-deploy-user.sh \"\$(cat ~/starfall_deploy.pub)\"" >&2
    exit 1
fi
# A public key file is one line; a private key is many. Belt and braces.
if [[ "$(printf '%s' "${PUBKEY}" | wc -l)" -gt 0 ]]; then
    echo "A public key is a single line; this has more. Pass the .pub half." >&2
    exit 1
fi
echo "==> Key fingerprint: $(ssh-keygen -l -f "${_keycheck}")"

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
cat > /etc/sudoers.d/starfall-deploy <<SUDO
${DEPLOY_USER} ALL=(root) NOPASSWD: ${WRAPPER}
${DEPLOY_USER} ALL=(root) NOPASSWD: ${STATUS_WRAPPER}
SUDO
chmod 0440 /etc/sudoers.d/starfall-deploy
visudo -cf /etc/sudoers.d/starfall-deploy

echo
echo "==> Done. ${DEPLOY_USER} can run:"
echo "      sudo ${WRAPPER}    (pull + restart + health gate)"
echo "      sudo ${STATUS_WRAPPER}    (read-only status and logs)"
echo "    It is NOT in the docker group, which would be root-equivalent."
