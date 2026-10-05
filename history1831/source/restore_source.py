"""Download/verify parts and assemble the current source ZIP. Python 3 standard library."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,urllib.request,os
BASE='https://yxiaoyu906-sketch.github.io/1/history1831/source/'
ROOT=Path(__file__).resolve().parent
manifest_path=ROOT/'source_manifest.json'
if not manifest_path.exists():
 with urllib.request.urlopen(BASE+'source_manifest.json',timeout=60) as r:manifest_path.write_bytes(r.read())
m=json.loads(manifest_path.read_text())
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(4194304),b''):h.update(b)
 return h.hexdigest()
def obtain(item):
 path=ROOT/item['file']
 if path.exists() and digest(path)==item['sha256']:return path
 tmp=path.with_suffix(path.suffix+'.download')
 for attempt in range(3):
  try:
   with urllib.request.urlopen(BASE+item['file']+'?v='+item['sha256'],timeout=60) as response,tmp.open('wb') as f:
    while True:
     b=response.read(1048576)
     if not b:break
     f.write(b)
   if tmp.stat().st_size!=item['bytes'] or digest(tmp)!=item['sha256']:raise ValueError('Checksum mismatch '+item['file'])
   os.replace(tmp,path);print('Verified',item['file'],flush=True);return path
  except Exception:
   if attempt==2:raise
with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(obtain,m['parts']))
out=ROOT/m['archive']
if out.exists() and digest(out)!=m['sha256']:raise RuntimeError('Different existing ZIP; move it before running again')
if not out.exists():
 tmp=out.with_suffix('.assembling')
 with tmp.open('wb') as f:
  for item in m['parts']:
   with (ROOT/item['file']).open('rb') as part:
    for b in iter(lambda:part.read(4194304),b''):f.write(b)
 if digest(tmp)!=m['sha256']:raise RuntimeError('Final ZIP checksum mismatch')
 os.replace(tmp,out)
print('Complete source ZIP:',out)
print('Extract the ZIP and open Godot/project.godot with Godot 4.7.2.')
