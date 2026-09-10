"""Preserve current project text and inspect the verified Outlaw anatomy seed."""
from pathlib import Path
import hashlib, json, shutil
ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / 'artifacts/outlaw-forge-v2'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def backup():
    dest = STAGE / 'before'
    if (dest/'manifest.json').exists():
        print('OUTLAW_BACKUP_ALREADY_PRESENT'); return
    paths = [ROOT/'project.godot', ROOT/'.github/workflows/deploy.yml']
    for directory in ['scripts', 'tests', 'tools', 'docs']:
        paths += [p for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix in ['.gd','.uid','.py','.md','.json','.yml','.sh']]
    record = {}
    for path in paths:
        relative = path.relative_to(ROOT)
        target = dest/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path,target)
        record[relative.as_posix()] = digest(path)
    (dest/'manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print('OUTLAW_BACKUP_COMPLETE',len(record))
if __name__ == '__main__': backup()
