"""Original numeric score and synthesis, authored with AI assistance. No external recordings."""
from pathlib import Path
import math, wave, struct, json, hashlib
ROOT=Path(__file__).parent
RATE=22050

def save(name,samples):
    with wave.open(str(ROOT/(name+'.wav')),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h',int(max(-.9,min(.9,s))*32767)) for s in samples))

def note(buf,at,duration,midi,gain=.12):
    f=440*2**((midi-69)/12)
    for i in range(int(duration*RATE)):
        j=int(at*RATE)+i
        if j>=len(buf):break
        t=i/RATE;env=min(1,t/.008)*math.exp(-t*8/duration)*max(0,min(1,(duration-t)/.05))
        buf[j]+=gain*env*(math.sin(2*math.pi*f*t)+.22*math.sin(2*math.pi*2*f*t)+.07*math.sin(2*math.pi*3*f*t))
beat=.5; song=[0.0]*int(32*RATE)
melody=[72,76,79,76,74,77,81,77,71,74,79,74,72,76,79,84]
for bar in range(16):
    root=[48,53,55,48][bar%4]
    note(song,bar*2,.9,root,.16)
    note(song,bar*2+1,.75,root+7,.10)
    for step in range(4):note(song,bar*2+step*.5,.4,melody[(bar*3+step)%len(melody)],.12)
save('fruit_loop',song)
for name,sequence in {'bite':[79,84], 'salad':[76,79,84], 'end':[67,64,60], 'win':[72,76,79,84,88]}.items():
    samples=[0.0]*int((len(sequence)*.09+.3)*RATE)
    for i,midi in enumerate(sequence):note(samples,i*.09,.25,midi,.22)
    save(name,samples)
manifest={p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in ROOT.glob('*.wav')}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
