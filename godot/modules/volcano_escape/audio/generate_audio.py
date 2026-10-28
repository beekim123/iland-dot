"""AI-assisted original composition. Deterministic synthesis, no samples/themes.
60 seconds: 24 bars in 4/4 at 96 BPM. D Dorian rescue-dispatch motif.
"""
from pathlib import Path
import numpy as np, wave, json, hashlib
P=Path(__file__).parent; SR=22050
rng=np.random.default_rng(27062026)
def note(m): return 440*2**((m-69)/12)
def tone(m,d,kind='bell'):
 t=np.arange(int(d*SR))/SR; f=note(m)
 if kind=='bass': s=np.sin(2*np.pi*f*t)+.14*np.sin(4*np.pi*f*t)
 else: s=np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*2*t)+.08*np.sin(2*np.pi*f*3*t)
 env=np.minimum(1,t/.012)*np.exp(-t/(d*.45))*np.minimum(1,(d-t)/.025)
 return s*env
manifest={}
def save(name,x,loop=False):
 peak=float(np.max(np.abs(x))); x=x/max(1,peak/.82)
 pcm=np.int16(np.clip(x,-1,1)*32767)
 with wave.open(str(P/(name+'.wav')),'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
 manifest[name]={'seconds':len(x)/SR,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'dc':float(np.mean(x)),'clipped_samples':int(np.sum(np.abs(pcm)>=32767)),'sha256':hashlib.sha256((P/(name+'.wav')).read_bytes()).hexdigest(),'loop':loop}
 return x
beat=.625; music=np.zeros(SR*60)
def add(at,x,amp):
 start=round(at*SR); end=min(len(music),start+len(x)); music[start:end]+=x[:end-start]*amp
motifs=[[74,77,81,79,76,74,72,76],[74,76,79,81,84,81,79,76],[72,74,77,79,81,79,77,74],[69,72,76,79,77,76,72,74]]
for bar in range(24):
 root=[50,53,48,55][bar%4]; at=bar*4*beat
 for b in range(4):
  add(at+b*beat,tone(root+(12 if b%2 else 0),.43,'bass'),.14)
  t=np.arange(int(.075*SR))/SR
  tick=rng.normal(0,1,len(t))*np.exp(-t*75)*.018
  add(at+b*beat,tick,1)
 for i,m in enumerate(motifs[bar%4]):
  if (bar+i)%5!=3: add(at+i*beat/2,tone(m+(12 if 16<=bar<20 else 0),.26),.12 if bar<20 else .09)
 # Quiet offbeat response, never alarm-like prolonged sirens.
 if bar%2==1: add(at+2.5*beat,tone(86,.32),.055)
# Boundary has silence at exact seam, short fades prevent discontinuity.
music[:220]*=np.linspace(0,1,220); music[-1102:]*=np.linspace(1,0,1102)
save('dispatch_loop',music,True)
for name,notes,d in [('alert',[81,77,81],.16),('interact',[74,81],.09),('rock',[50,43],.18),('shelter',[69,74,77],.14),('evac',[74,77,81,86],.18),('click',[81],.055),('beacon',[77,84,86],.12),('damage',[62,57],.12),('rescue',[69,72,74],.23)]:
 x=np.concatenate([tone(m,d)*(.24 if name!='rock' else .32) for m in notes]);save(name,x)
(P/'audio_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
assert len(music)==60*SR
assert all(v['clipped_samples']==0 and abs(v['dc'])<.002 and v['peak']<.9 for v in manifest.values())
print('PASS: 60s loop; 9 cues; finite PCM; no clipping; DC < .002; peak < .9')
