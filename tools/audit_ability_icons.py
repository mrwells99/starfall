"""Audit distinct active ability names for accidental reused icon paths/content."""
from pathlib import Path
import collections
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
def audit():
    reference = (ROOT / 'docs/CLASS_ABILITIES.md').read_text()
    names = {n.strip() for n in re.findall(r'^\| (?:[1-7]|Shift\+[1-5]) \| ([^|]+) \|', reference, re.M)}
    paths = dict(re.findall(r'"([^"]+)": "res://([^"]+)"', (ROOT / 'scripts/ability_art.gd').read_text()))
    hashes = collections.defaultdict(list)
    for name in sorted(names):
        path = ROOT / paths[name]
        assert path.is_file(), f'Missing icon: {name}'
        hashes[hashlib.sha256(path.read_bytes()).hexdigest()].append(name)
    duplicates = [items for items in hashes.values() if len(items) > 1]
    assert not duplicates, f'Distinct abilities share icons: {duplicates}'
    print(f'{len(names)} distinct active abilities: all icon files exist and have unique contents. Shared Mend is one ability.')
if __name__ == '__main__':
    audit()
