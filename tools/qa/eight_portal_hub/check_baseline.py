"""Compare seven production modules against preserved original checkout; ignore derived imports."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
original=root.parent/'seven-game-integration'
ids=['gummy_bomber','bloom_skirmish','tide_gulp','beach_cleanup','volcano_escape','pelican_pedal','fruit_gummy_snake']
def manifest(base):
 return {str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).hexdigest() for game in ids for p in (base/'godot/modules'/game).rglob('*') if p.is_file() and p.suffix not in ['.import','.pyc'] and '__pycache__' not in p.parts}
a,b=manifest(original),manifest(root)
changed=[p for p in sorted(a.keys()|b.keys()) if a.get(p)!=b.get(p)]
print(json.dumps({'seven_module_files':len(a),'unchanged':a==b,'changed':changed},indent=2))
assert a==b, 'Seven existing module bytes changed'
