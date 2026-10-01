#!/usr/bin/env python3
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root=Path(__file__).resolve().parents[1]
out=root.parent/'LockIn-Deliverables';out.mkdir(exist_ok=True)
def pack(dest,source,prefix):
 with ZipFile(dest,'w',ZIP_DEFLATED) as z:
  for p in sorted(source.rglob('*')):
   rel=p.relative_to(source)
   if not p.is_file() or any(x in {'Build','.build','.git','__pycache__','node_modules','.DS_Store'} for x in rel.parts):continue
   z.write(p,str(Path(prefix)/rel))
pack(out/'LockIn-Mac.zip',root,'LockIn')
pack(out/'LockIn-Browser-Extension.zip',root/'BrowserExtensions/Chrome','LockIn-Browser-Extension')
docs=root.parent/'README.md'
(out/'README.txt').write_text(docs.read_text() if docs.is_file() else (root/'README.md').read_text())
print('Created LockIn-Mac.zip, LockIn-Browser-Extension.zip, README.txt')
