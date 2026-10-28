#!/usr/bin/env python3
"""Original synthesized playful percussion score; no recorded or borrowed samples."""
from pathlib import Path
import hashlib, json, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 24000
RNG = np.random.default_rng(281029)

def hz(n): return 440.0 * 2 ** ((n-69)/12)
def voice(n, seconds, kind='flute'):
    t=np.arange(int(seconds*SR))/SR
    f=hz(n); a=np.minimum(t/.025,1)*np.minimum((seconds-t)/.08,1)
    if kind=='strings':
        y=sum(np.sin(2*np.pi*f*k*t+0.016*np.sin(2*np.pi*4.5*t))*1/(k*k) for k in range(1,7))
        a=np.minimum(t/.08,1)*np.minimum((seconds-t)/.15,1)*.5
    elif kind=='bell':
        y=np.sin(2*np.pi*f*t)+.26*np.sin(2*np.pi*f*2.01*t)+.1*np.sin(2*np.pi*f*3*t)
        a*=np.exp(-3.4*t)
    else:
        y=np.sin(2*np.pi*f*t+.018*np.sin(2*np.pi*5*t))+.15*np.sin(4*np.pi*f*t)+.06*np.sin(6*np.pi*f*t)
    return y*a

def put(track, signal, start, gain=1):
    indices=(int(start*SR)+np.arange(len(signal)))%len(track)
    np.add.at(track,indices,signal*gain)

def drum(seconds=.22, low=True):
    t=np.arange(int(seconds*SR))/SR
    if low: return np.sin(2*np.pi*(52*t+12*(1-np.exp(-t*25))/25))*np.exp(-18*t)
    noise=RNG.normal(size=len(t)); return (noise-np.roll(noise,1))*.2*np.exp(-24*t)

def score(boss=False):
    beat=60/(156 if boss else 120); bars=8 if boss else 16
    out=np.zeros(round(bars*4*beat*SR))
    chords=([53,57,60],[50,53,57],[46,50,53],[48,52,55])
    phrases=([77,81,84,81,79,77],[74,77,81,79,77,74],[77,74,70,74,77,79],[76,79,82,79,76,72])
    offsets=[0,.75,1.5,2,2.75,3.5]
    for bar in range(bars):
        time=bar*4*beat; chord=chords[bar%4]
        for i,n in enumerate(phrases[bar%4]):
            put(out,voice(n,.55*beat,'bell'),time+offsets[i]*beat,.28)
            if boss: put(out,voice(n-12,.24*beat,'bell'),time+(offsets[i]+.25)*beat,.08)
        for b in range(4):
            put(out,voice(chord[0]-12,.55*beat,'bell'),time+b*beat,.27)
            put(out,drum(low=b%2==0),time+b*beat,.13)
            for n in chord: put(out,voice(n+12,.24*beat,'bell'),time+(b+.5)*beat,.10)
    return out

def effect(name):
    seconds={'charge':.7,'result':1.5,'defeat':.9,'warning':.65,'wave':.8}.get(name,.24)
    t=np.arange(int(seconds*SR))/SR; noise=RNG.normal(size=len(t))
    if name in ('swing','dash'): return noise*np.sin(np.pi*np.minimum(t/.06,1))*np.exp(-t*19)*.25
    if name in ('hit','impact','hurt'):
        return (np.sin(2*np.pi*(110*t+24*(1-np.exp(-t*30))/30))+.22*np.sin(2*np.pi*310*t)+.07*noise)*np.exp(-t*22)
    if name=='charge': return np.sin(2*np.pi*(190*t+230*t*t))*(.1+.9*t/seconds)*np.minimum((seconds-t)/.06,1)
    notes={'result':[65,69,72,77], 'defeat':[65,62,60,53], 'warning':[76,70,76], 'wave':[65,72,77], 'choose':[81,84]}.get(name,[77,84])
    out=np.zeros(len(t))
    for i,n in enumerate(notes):
        start=int(i*seconds/(len(notes)+1)*SR);x=voice(n,min(.38,seconds-start/SR),'bell');out[start:start+len(x)]+=x*.6
    return out

def save(name,data,loop=False):
    peak=float(np.max(np.abs(data))); data=data*.72/max(peak,.001)
    pcm=np.clip(data*32767,-32767,32767).astype('<i2')
    path=ROOT/(name+'.wav')
    with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
    return {'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'frames':len(data),'seconds':len(data)/SR,'sample_rate':SR,'peak':float(np.max(np.abs(data))),'rms':float(np.sqrt(np.mean(data*data))),'boundary_step':float(abs(data[-1]-data[0])),'loop':loop}

if __name__=='__main__':
    ROOT.mkdir(parents=True,exist_ok=True)
    records=[save('theme',score(),True),save('boss',score(True),True)]
    records += [save(n,effect(n)) for n in ['swing','hit','charge','warning','hurt','wave','result','dash','impact','choose','defeat']]
    assert all(x['peak']<.99 for x in records)
    (ROOT/'manifest.json').write_text(json.dumps({'original':True,'method':'Python additive synthesis; original composed notes, no external samples','subjective_listening_verified':False,'files':records},indent=2)+'\n')
