#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES="$ROOT/art/previews/runtime/gif_frames_v4"
OUT="$ROOT/art/previews/runtime/sunny_shell_island_motion_v4.gif"
test -f "$FRAMES/capture.json"
test -f "$FRAMES/frame_119.png"
ffmpeg -y -v warning -framerate 12 -i "$FRAMES/frame_%03d.png" -filter_complex "[0:v]fps=10,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" -loop 0 "$OUT"
python3 - "$OUT" <<'PY'
from PIL import Image,ImageChops,ImageStat
from pathlib import Path
import sys,json,hashlib
p=Path(sys.argv[1]); im=Image.open(p)
frames=[]; ms=[]
for n in range(im.n_frames):
 im.seek(n);frames.append(im.convert('RGB').copy());ms.append(im.info.get('duration',0))
delta=[]
for a,b in zip(frames,frames[1:]):
 delta.append(sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3)
report={'file':str(p),'bytes':p.stat().st_size,'size':im.size,'frames':im.n_frames,'duration_ms':sum(ms),'loop':im.info.get('loop'),'unique_frames':len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}),'mean_adjacent_pixel_delta':sum(delta)/len(delta),'min_adjacent_pixel_delta':min(delta),'max_adjacent_pixel_delta':max(delta),'audio':'GIF contains no audio'}
assert im.n_frames==100 and report['unique_frames']==100
assert p.stat().st_size<10_000_000
assert 9900<=sum(ms)<=10100
(p.parent/'gif_v4_qa.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
sheet=Image.new('RGB',(640,400))
for k,n in enumerate([0,25,50,75]):
 f=frames[n].resize((320,200));sheet.paste(f,((k%2)*320,(k//2)*200))
sheet.save(p.parent/'gif_v4_contact_sheet.jpg',quality=90)
PY
