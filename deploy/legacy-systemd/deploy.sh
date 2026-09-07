#!/usr/bin/env bash
# Repeatable manual deploy of Ringfall source to the droplet.
# Run from the project root on your dev machine.
#
# Once GitHub Actions is set up, the workflow will run the same rsync + restart
# steps in CI. This script is the manual equivalent and the reference for that.
#
# Env overrides:
#   RINGFALL_SSH=root@play.zerodesk.cloud
#   RINGFALL_PATH=/opt/ringfall
#   RINGFALL_SERVICE_USER=ringfall

set -euo pipefail

TARGET="${RINGFALL_SSH:-root@play.leafmods.com}"
REMOTE_PATH="${RINGFALL_PATH:-/opt/ringfall}"
SERVICE_USER="${RINGFALL_SERVICE_USER:-ringfall}"

if [[ ! -f project.godot ]]; then
    echo "deploy.sh must run from the project root (no project.godot found)." >&2
    exit 1
fi

echo "==> Syncing source to ${TARGET}:${REMOTE_PATH}"
rsync -avz --delete \
    --exclude='.git' \
    --exclude='.godot' \
    --exclude='artifacts' \
    --exclude='deploy/deploy.sh' \
    ./ "${TARGET}:${REMOTE_PATH}/"

echo "==> Reinstalling units, restarting every instance, tailing recent logs (single ssh session)"
ssh "${TARGET}" "
    set -e
    chown -R ${SERVICE_USER}:${SERVICE_USER} ${REMOTE_PATH}
    install -m 0644 ${REMOTE_PATH}/deploy/ringfall@.service /etc/systemd/system/ringfall@.service
    mkdir -p /etc/ringfall
    install -m 0644 ${REMOTE_PATH}/deploy/instances/*.env /etc/ringfall/
    systemctl daemon-reload

    instances=\$(ls /etc/ringfall/*.env | xargs -n1 basename | sed 's/\.env\$//')
    echo \"--- instances: \$(echo \$instances | tr '\n' ' ') ---\"

    # Stop everything before warming the import cache: six servers racing to
    # create .godot/ on a cold checkout corrupts it.
    for i in \$instances; do systemctl stop ringfall@\$i || true; done
    rm -rf ${REMOTE_PATH}/.godot
    sudo -u ${SERVICE_USER} env HOME=${REMOTE_PATH} /usr/local/bin/godot --headless --path ${REMOTE_PATH} --quit >/dev/null 2>&1 || true
    chown -R ${SERVICE_USER}:${SERVICE_USER} ${REMOTE_PATH}

    for i in \$instances; do systemctl start ringfall@\$i; done
    sleep 2
    systemctl --no-pager --plain list-units 'ringfall@*' || true
    echo '--- recent logs ---'
    journalctl -u 'ringfall@*' -n 40 --no-pager
"
