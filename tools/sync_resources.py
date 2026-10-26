#!/usr/bin/env python3
"""Sync only the active, explicit approved asset manifest; never glob old exports."""
from pathlib import Path
import shutil, hashlib, json
root=Path(__file__).resolve().parents[1]
active=json.loads((root/'docs/active_asset_manifest.json').read_text())
report=[]
for item in active['files']:
 src=root/item['source'];dst=root/item['destination']
 if not src.is_file(): raise FileNotFoundError(src)
 dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists() or src.read_bytes()!=dst.read_bytes():shutil.copy2(src,dst)
 report.append({**item,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'bytes':dst.stat().st_size})
(root/'docs/resource_manifest.json').write_text(json.dumps({'revision':active['revision'],'files':report},indent=2))
print(json.dumps(report,indent=2))
