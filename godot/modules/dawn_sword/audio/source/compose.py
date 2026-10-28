#!/usr/bin/env python3
"""Original synthesized chamber-adventure score; no recorded or borrowed samples."""
from pathlib import Path
import hashlib, json, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 24000
RNG = np.random.default_rng(281028)

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
    beat=60/(128 if boss else 96); bars=8 if boss else 16
    out=np.zeros(round(bars*4*beat*SR))
    chords=([50,53,57],[46,50,53],[43,46,50],[45,49,52]) if boss else ([50,54,57],[47,50,54],[43,47,50],[45,49,52])
    melody=([74,72,69,65,67,69,72,73],[74,69,67,65,62,65,67,69]) if boss else ([74,78,81,78,76,74,71,73],[74,76,78,81,83,81,78,76],[79,78,76,74,71,74,76,78],[76,73,69,73,76,78,76,73])
    for bar in range(bars):
        time=bar*4*beat; chord=chords[bar%4]
        for n in chord: put(out,voice(n+12,4.1*beat,'strings'),time,.13)
        for b in range(4):
            put(out,voice(chord[0]-12,.8*beat,'bell'),time+b*beat,.17)
            put(out,drum(low=b%2==0),time+b*beat,.10 if boss else .055)
            put(out,voice(chord[b%3]+12,.65*beat,'bell'),time+(b+.5)*beat,.12)
        phrase=melody[bar%len(melody)]
        for i,n in enumerate(phrase):
            put(out,voice(n,.58*beat,'flute'),time+i*.5*beat,.20 if boss else .17)
    return out

def effect(name):
    seconds={'fire':.85,'victory':1.7,'defeat':1.2,'warning':.65,'heal':.8}.get(name,.28)
    t=np.arange(int(seconds*SR))/SR; noise=RNG.normal(size=len(t))
    if name in ('swing','roll'): return noise*np.exp(-t*16)*np.sin(np.pi*np.minimum(t/.09,1))*.25
    if name in ('hit','block','hurt'): return (np.sin(2*np.pi*(100*t+75*t*t))+.18*noise)*np.exp(-t*20)
    if name=='fire': return np.convolve(noise,np.ones(9)/9,'same')*(1-np.exp(-20*t))*np.exp(-3*t)
    notes={'victory':[62,66,69,74], 'defeat':[62,60,57,50], 'heal':[74,78,81,86], 'warning':[69,69,69], 'jump':[62,69]}.get(name,[74,81])
    out=np.zeros(len(t))
    for i,n in enumerate(notes):
        start=int(i*seconds/(len(notes)+1)*SR); x=voice(n,min(.42,seconds-start/SR),'bell'); out[start:start+len(x)]+=x*.6
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
    records += [save(n,effect(n)) for n in ['swing','hit','block','hurt','jump','roll','heal','fire','warning','defeat','victory']]
    assert all(x['peak']<.99 for x in records)
    (ROOT/'manifest.json').write_text(json.dumps({'original':True,'method':'Python additive synthesis; original composed notes, no external samples','subjective_listening_verified':False,'files':records},indent=2)+'\n')
