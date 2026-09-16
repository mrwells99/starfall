"""Verify or restore only the pinned Ember effect subset; no external dependencies."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile
ROOT = Path(__file__).resolve().parents[3]
MANIFEST = Path(__file__).with_name('sources.json')
def digest(data): return hashlib.sha256(data).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch-missing',action='store_true')
    args=parser.parse_args()
    record=json.loads(MANIFEST.read_text())
    downloads={}
    failures=[]
    for item in record['assets']:
        path=ROOT/item['path']
        if not path.exists() and args.fetch_missing:
            url=item['download_url']
            if url not in downloads:
                with urllib.request.urlopen(url,timeout=60) as response:
                    data=response.read(32*1024*1024+1)
                if len(data)>32*1024*1024:raise ValueError('Download exceeded 32 MiB')
                expected=next((a['sha256'] for a in record['archives'] if a['url']==url),None)
                if expected and digest(data)!=expected:raise ValueError('Archive checksum mismatch')
                downloads[url]=data
            data=downloads[url]
            if 'archive_member' in item:
                with zipfile.ZipFile(io.BytesIO(data)) as archive:data=archive.read(item['archive_member'])
            if digest(data)!=item['sha256']:raise ValueError('Asset checksum mismatch: '+str(path))
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open('xb') as output:output.write(data)
        if not path.is_file() or digest(path.read_bytes())!=item['sha256']:failures.append(item['path'])
    if failures:raise SystemExit('Missing or changed assets: '+', '.join(failures))
    print(f"Verified {len(record['assets'])} pinned effect textures")
if __name__=='__main__':main()
