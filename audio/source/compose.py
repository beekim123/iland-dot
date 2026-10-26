#!/usr/bin/env python3
"""Sunny Shell Island: original score + deterministic sample-free synthesis.
Run with Python 3 + numpy. No downloads, recordings or generative models.
"""
from pathlib import Path
import numpy as np
import json, wave, hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'export'; OUT.mkdir(exist_ok=True)
SR=44100; BPM=80; BEAT=60/BPM; BARS=16; SECONDS=BARS*4*BEAT; N=round(SECONDS*SR)
rng=np.random.default_rng(20261026)
mix=np.zeros((N,2),np.float64)
events=[]

def add(signal,beat,pan,amp):
    ix=(round(beat*BEAT*SR)+np.arange(len(signal)))%N
    gains=np.array([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)])
    mix[ix] += signal[:,None]*gains[None,:]*amp

def note(kind,midi,beat,duration,amp,pan=0):
    freq=440*2**((midi-69)/12)
    t=np.arange(round(duration*SR))/SR
    attack=1-np.exp(-t/.004)
    if kind=='pan':
        y=sum(a*np.sin(2*np.pi*freq*r*t)*np.exp(-t/tau) for r,a,tau in [(1,1,.48),(2,.22,.22),(3.01,.09,.12),(4.03,.035,.08)])*attack
    elif kind=='pluck':
        y=sum((.65**(k-1)/k)*np.sin(2*np.pi*freq*k*t)*np.exp(-t/(.27/k**.25)) for k in range(1,8))*attack
    else:
        y=(np.sin(2*np.pi*freq*t)+.14*np.sin(2*np.pi*freq*2*t))*attack*np.exp(-t/.65)
    y *= np.minimum(1,(duration-t)/.055)
    add(y,beat,pan,amp)
    events.append(dict(instrument=kind,midi=midi,beat=round(beat,4),duration_seconds=duration,amplitude=amp,pan=pan))

def drum(kind,beat,amp,pan):
    t=np.arange(int(.19*SR))/SR
    if kind=='shaker':
        noise=rng.normal(size=len(t)); noise=np.r_[0,np.diff(noise)]*.25
        y=noise*(1-np.exp(-t/.002))*np.exp(-t/.021)
    else:
        y=np.sin(2*np.pi*(145*t+1.3*(1-np.exp(-t/.018))))*np.exp(-t/.046)*(1-np.exp(-t/.0015))
    y*=np.minimum(1,(.19-t)/.015)
    add(y,beat,pan,amp)
    events.append(dict(instrument=kind,beat=round(beat,4),amplitude=amp,pan=pan))

# Individually composed 16-bar melody. Entries are beat offset, MIDI, length in beats.
melody=[
 [(0,76,1), (1.5,79,.5),(2,81,.75),(3,79,.7)],
 [(.5,76,.75),(1.5,72,1),(3,74,.6)],
 [(0,77,1), (1.5,81,.5),(2.5,79,.7),(3.5,76,.4)],
 [(0,74,1.5),(2,79,.75),(3,74,.8)],
 [(0,76,.75),(1,79,.7),(2.5,84,1)],
 [(.5,83,.7),(1.5,79,.7),(3,76,.6)],
 [(0,81,1),(1.5,79,.7),(2.5,77,.7)],
 [(0,74,1),(1.5,71,.6),(2.5,74,1)],
 [(0,79,.75),(1,76,.7),(2.5,81,1)],
 [(0,84,1),(1.5,81,.6),(2.5,79,.8)],
 [(.5,77,.8),(1.5,76,.6),(2.5,72,1)],
 [(0,74,1),(1.5,79,.7),(3,83,.6)],
 [(0,81,1),(1.5,77,.7),(2.5,74,.8)],
 [(.5,79,.7),(1.5,76,.7),(3,72,.6)],
 [(0,77,1),(1.5,81,.7),(2.5,79,.7)],
 [(0,74,1),(1.5,71,.7),(3,74,.7)]
]
chords=[('Cmaj7',[60,64,67,71],36),('Am7',[57,60,64,67],33),('Fmaj7',[57,60,64,65],29),('G6',[55,59,62,64],31),
 ('Cmaj7',[60,64,67,71],36),('Em7',[55,59,62,64],28),('F6',[57,60,62,65],29),('G',[55,59,62,67],31),
 ('Cmaj7',[60,64,67,71],36),('Am7',[57,60,64,67],33),('Fmaj7',[57,60,64,65],29),('G6',[55,59,62,64],31),
 ('Dm7',[57,60,62,65],26),('Em7',[55,59,62,64],28),('F6',[57,60,62,65],29),('G',[55,59,62,67],31)]
for bar,(name,chord,root) in enumerate(chords):
    base=bar*4
    for off,key,length in melody[bar]:
        note('pan',key,base+off,min(1.7,length*BEAT+.5),.30,-.15)
    for off,vel in [(0,.095),(1.5,.068),(2.5,.083)]:
        for k,key in enumerate(chord): note('pluck',key,base+off+k*.023,.82,vel,.28)
    for off,key in [(0,root),(2,root+7)]: note('bass',key,base+off,1.30,.16,0)
    for i in range(8): drum('shaker',base+i*.5+(.035 if i%2 else 0),.035 if i%2 else .022,.4)
    for off in [1,3]: drum('hand',base+off,.065,-.35)
# Small circular stereo room reflections preserve tails across the loop boundary.
dry=mix.copy()
for seconds,gain in [(.079,.12),(.143,.07),(.227,.04)]: mix += np.roll(dry[:,::-1],round(seconds*SR),axis=0)*gain
mix-=mix.mean(axis=0)
mix *= min(.57/np.abs(mix).max(), .115/np.sqrt(np.mean(mix**2)))

# Ocean: periodic spectral noise, without repeating short recordings/blocks.
freq=np.fft.rfftfreq(N,1/SR)
def sea_layer(seed):
    r=np.random.default_rng(seed)
    envelope=(np.maximum(freq,40)/180)**(-.75) * (1-np.exp(-(freq/80)**2))*np.exp(-(freq/2200)**2)
    z=(r.normal(size=len(freq))+1j*r.normal(size=len(freq)))*envelope
    z[0]=0; z[-1]=z[-1].real
    y=np.fft.irfft(z,n=N); return y/np.std(y)
t=np.arange(N)/SR
swell=.55+.23*np.cos(2*np.pi*6*t/SECONDS)+.13*np.cos(2*np.pi*11*t/SECONDS+.7)+.07*np.sin(2*np.pi*3*t/SECONDS)
left=sea_layer(324)*swell; right=.7*left+.45*sea_layer(325)*np.roll(swell,SR//2)
sea=np.column_stack([left,right]); sea-=sea.mean(axis=0); sea*=.062/np.sqrt(np.mean(sea**2))

report={}
def save(name,y,loop):
    assert np.all(np.isfinite(y)) and np.max(np.abs(y))<.99
    pcm=np.rint(y*32767).astype('<i2'); path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
    q=pcm.astype(float)/32768
    block=SR//4
    hashes=[hashlib.sha256(pcm[i:i+block].tobytes()).hexdigest() for i in range(0,len(pcm)-block+1,block)]
    report[path.name]=dict(seconds=len(q)/SR,sample_rate=SR,channels=2,bits=16,peak_dbfs=float(20*np.log10(np.abs(q).max())),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(q*q)))),clipped_samples=int((np.abs(pcm.astype(np.int32))>=32767).sum()),dc_offset=q.mean(axis=0).tolist(),seam_step_abs=np.abs(q[0]-q[-1]).tolist() if loop else None,internal_step_99_9_percentile=float(np.quantile(np.abs(np.diff(q,axis=0)),.999)),quarter_second_blocks=len(hashes),unique_quarter_second_blocks=len(set(hashes)),identical_first_last_second=bool(np.array_equal(pcm[:SR],pcm[-SR:])),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    if loop: assert max(report[path.name]['seam_step_abs'])<report[path.name]['internal_step_99_9_percentile']
    assert len(hashes)==len(set(hashes))
save('sunny_shell_island_loop',mix,True)
save('ocean_ambience_loop',sea,True)
audition=(mix*10**(-3/20)+sea*10**(-12/20))[:SR*15].copy()
audition[:int(.1*SR)]*=np.linspace(0,1,int(.1*SR))[:,None]
audition[-SR:]*=np.linspace(1,0,SR)[:,None]
save('sunny_shell_island_audition',audition,False)
(ROOT/'source'/'score.json').write_text(json.dumps(dict(title='Sunny Shell Island / 晴贝小岛',bpm=BPM,time_signature='4/4',bars=BARS,seed=20261026,chords=[x[0] for x in chords],events=events),indent=2)+'\n')
(OUT/'audio_qa.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
