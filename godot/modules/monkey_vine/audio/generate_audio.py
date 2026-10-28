"""Original AI-assisted composition and synthesis, no samples or third-party assets.
Run Python 3 to reproduce mono PCM WAV at 22050 Hz. License: CC0-1.0.
"""
import math, wave, struct
from pathlib import Path
ROOT=Path(__file__).parent
SR=22050

def render(name, duration, notes):
    samples=[0.0]*int(SR*duration)
    for start, length, pitch, gain, kind in notes:
        freq=440*2**((pitch-69)/12)
        for j in range(int(length*SR)):
            i=int(start*SR)+j
            if i>=len(samples): break
            t=j/SR
            env=min(1,t/.008)*math.exp(-t/(length*.28))*(min(1,(length-t)/.04))
            tone=math.sin(2*math.pi*freq*t)+(.28*math.sin(2*math.pi*freq*2.01*t) if kind=='wood' else .12*math.sin(2*math.pi*freq*3*t))
            samples[i]+=gain*tone*env
    with wave.open(str(ROOT/name),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes(b''.join(struct.pack('<h',int(max(-.9,min(.9,s))*32767)) for s in samples))

# 16 seconds / 8 bars, pentatonic canopy marimba with soft plucked bass.
melody=[72,76,79,76,74,79,81,79,76,72,74,76,79,76,74,72,
        69,72,76,79,81,79,76,74,72,76,74,69,72,74,76,72]
notes=[]
for i,p in enumerate(melody): notes.append((i*.5,.42,p,.16,'wood'))
for i,p in enumerate([48,48,53,53,55,55,48,48]):
    notes.append((i*2,.85,p,.12,'pluck'))
    notes.append((i*2+1,.55,p+7,.07,'pluck'))
render('canopy_loop.wav',16,notes)
sequences={'grab':[79,84],'release':[76,81,88],'collect':[84,88,91], 'land':[48,55], 'checkpoint':[72,76,79,84], 'fail':[64,60,55], 'respawn':[60,67,72], 'segment_clear':[72,76,79,84,88], 'break_warning':[91,79,91], 'vine_break':[67,55]}
for name,pitches in sequences.items(): render(name+'.wav',max(.5,len(pitches)*.105+.2),[(i*.105,.22,p,.20,'wood') for i,p in enumerate(pitches)])
