"""Original AI-assisted composition and deterministic synthesis; no sampled recordings."""
from pathlib import Path
import wave, math, array, random
OUT=Path(__file__).parent; SR=22050

def write(name, values):
    peak=max(max(values,default=0),-min(values,default=0),.01)
    gain=min(1,.83/peak)
    data=array.array('h',(int(max(-1,min(1,v*gain))*32767) for v in values))
    with wave.open(str(OUT/name),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(data.tobytes())
def tone(buf, start, dur, midi, amp):
    f=440*2**((midi-69)/12)
    for k in range(int(dur*SR)):
        n=int(start*SR)+k
        if n>=len(buf):break
        t=k/SR; env=min(t/.008,1)*math.exp(-t*5/dur)*(1-t/dur)
        buf[n]+=amp*env*(math.sin(2*math.pi*f*t)+.25*math.sin(4*math.pi*f*t))
# 16 bars of lilting 6/8 at dotted-quarter=96. Seam has a short rest.
beat=.625; duration=40.; buf=[0.] * int(duration*SR)
melody=[74,78,81,78,76,74,71,74, 76,79,83,81,79,76,74,71, 74,78,81,85,83,81,78,76, 79,78,76,74,71,73,74,74]
for bar in range(16):
    root=[50,55,47,57][bar%4]
    for b in range(4):
        t=bar*2.5+b*beat
        tone(buf,t,.48,root if b%2==0 else root+7,.12)
        tone(buf,t,.45,melody[(bar*2+b//2)%32]+(0 if b%2==0 else 7),.15 if b%2==0 else .055)
        if b%2: tone(buf,t,.12,root+24,.05)
write('theme.wav',buf)
for name,notes in {'pickup':[74,81],'delivery':[78,81,86],'complete':[74,78,81,86],'collision':[45,42],'reset':[69,74],'failed':[69,66,62]}.items():
    samples=[0.] * int((len(notes)*.13+.18)*SR)
    for j,n in enumerate(notes):tone(samples,j*.13,.24,n,.3)
    write(name+'.wav',samples)
print('Generated original 40-second loop and six cues')
