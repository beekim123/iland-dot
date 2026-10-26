"""Regenerate authored hub SFX and terrain-certified portal sites. Python stdlib only."""
from pathlib import Path
import math, wave, struct, random, json, importlib.util
HUB = Path(__file__).resolve().parents[1]
ROOT = HUB.parents[1]
spec = importlib.util.spec_from_file_location('landscape', ROOT/'art/v3/build_landscape.py')
landscape = importlib.util.module_from_spec(spec)
spec.loader.exec_module(landscape)
placements = json.loads((ROOT/'art/v3/assembly_placements.json').read_text())
points = []
ground_patches = {}
for ix in range(-16,17):
    for iy in range(-5,13):
        x,y = ix*.4, iy*.4
        if landscape.edge_distance(x,y)<2 or landscape.grass_mask(x,y)<.8: continue
        if min(math.hypot(x-a['position'][0],y-a['position'][1]) for a in placements)<1.35: continue
        hs = [landscape.terrain_height(x+dx,y+dy) for dx,dy in [(0,.6),(0,-.6),(.6,0),(-.6,0)]]
        if max(hs)-min(hs)>.55: continue
        points.append([round(x,3),round(landscape.terrain_height(x,y)+.012,3),round(-y,3)])
        ground_patches[f'{round(x*1000)}:{round(-y*1000)}'] = [round(landscape.terrain_height(x-1.3+ix2*.325,y+.725-iz2*.3625),5) for iz2 in range(5) for ix2 in range(9)]
(HUB/'portal_sites.json').write_text(json.dumps({'source':'art/v3/build_landscape.py; center terrain height + .012m; footprint .6m, grass>.8, shoreline>2m, vegetation/actor origin clearance>1.35m, height range<.55m','points':points,'ground_patches':ground_patches},indent=2))
for name,freq,dur in [('click',740,.11),('portal',440,.55),('bird',1600,.22),('plant',1050,.16),('water',530,.23)]:
    random.seed(27); rate=22050; samples=[]
    for i in range(int(dur*rate)):
        t=i/rate; u=t/dur; env=math.sin(math.pi*u)**2*math.exp(-3*u)
        f=freq*(1+(.8*u if name in ['portal','bird'] else -.45*u))
        v=math.sin(2*math.pi*f*t)+.23*math.sin(2*math.pi*f*1.5*t)
        if name=='plant': v+=.2*(random.random()*2-1)
        samples.append(int(15000*env*v))
    with wave.open(str(HUB/'audio'/f'{name}.wav'),'wb') as wav:
        wav.setparams((1,2,rate,0,'NONE','not compressed'))
        wav.writeframes(struct.pack('<'+'h'*len(samples),*samples))
print(f'Wrote {len(points)} certified portal sites and 5 original SFX')
