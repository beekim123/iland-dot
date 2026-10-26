#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test "$(find frames_quick -name 'frame_*.png' | wc -l)" -eq 48
ffmpeg -y -v warning -framerate 12 -pattern_type glob -i 'frames_quick/frame_*.png' -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -movflags +faststart seagull_fly_preview.mp4
ffmpeg -y -v warning -framerate 12 -pattern_type glob -i 'frames_quick/frame_*.png' -filter_complex 'split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' -loop 0 seagull_fly_preview.gif
python3 - <<'PY'
from PIL import Image,ImageChops,ImageStat
import json,hashlib,os
im=Image.open('seagull_fly_preview.gif'); frames=[];ms=[]
for i in range(im.n_frames): im.seek(i);frames.append(im.convert('RGB').copy());ms.append(im.info.get('duration',0))
r={'frames':len(frames),'duration_ms':sum(ms),'unique_frames':len(set(hashlib.sha256(f.tobytes()).hexdigest() for f in frames)),'size':im.size,'loop':im.info.get('loop'),'bytes':os.path.getsize('seagull_fly_preview.gif'),'source':'actual Blender Cycles armature-deformed frames, sampled at 12fps from 24fps action','audio':'none'}
assert len(frames)==48 and 3950<=sum(ms)<=4050 and r['unique_frames']>=40
open('preview_qa.json','w').write(json.dumps(r,indent=2));print(json.dumps(r))
sheet=Image.new('RGB',(960,720))
for k,n in enumerate([0,2,4,6]):sheet.paste(frames[n],((k%2)*480,(k//2)*360))
sheet.save('seagull_motion_contact.png')
PY
