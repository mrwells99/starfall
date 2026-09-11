#!/usr/bin/env bash
# One-time root installation. Future deploys use a root-owned, fixed hook.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo on the game server." >&2; exit 1; }
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python3 -m py_compile "$source_dir/image_retention.py"
install -d -m 0755 /usr/local/libexec
install -d -m 0700 /var/lib/starfall-image-retention
install -m 0755 -o root -g root "$source_dir/image_retention.py" /usr/local/libexec/starfall-image-retention
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
import tempfile
wrapper = Path('/usr/local/bin/starfall-deploy')
original = wrapper.read_text()
before = 'if ! /usr/local/libexec/starfall-image-retention before; then echo "Image cleanup skipped; continuing deployment." >&2; fi\n'
after = '        if ! /usr/local/libexec/starfall-image-retention after; then echo "Image cleanup skipped; continuing deployment." >&2; fi'
updated = original
if '/usr/local/libexec/starfall-image-retention before' not in original:
    anchor = 'echo "--- pulling ---"\ndocker compose pull'
    if updated.count(anchor) != 1:
        raise SystemExit('Unexpected deploy wrapper; no wrapper changes made. Review before installing hooks.')
    updated = updated.replace(anchor, before + anchor)
if '/usr/local/libexec/starfall-image-retention after' not in original:
    anchor = '        docker image prune -f --filter "until=168h" >/dev/null || true'
    if updated.count(anchor) != 1:
        raise SystemExit('Unexpected deploy wrapper; no wrapper changes made. Review before installing hooks.')
    updated = updated.replace(anchor, after)
subprocess.run(['bash', '-n'], input=updated, text=True, check=True)
if updated != original:
    backup = wrapper.with_name('starfall-deploy.before-retention')
    if not backup.exists():
        backup.write_text(original)
        backup.chmod(0o700)
    fd, temp = tempfile.mkstemp(prefix='.starfall-deploy-', dir=wrapper.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(updated)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(temp, 0o755)
        os.replace(temp, wrapper)
    finally:
        if os.path.exists(temp): os.unlink(temp)
print('Automatic image cleanup installed before pulls and after healthy deployment.')
print('Active images, rollback image, client downloads and volumes are preserved.')
PY
