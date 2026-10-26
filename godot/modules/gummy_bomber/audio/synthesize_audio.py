"""Original Sunny Shell / Gummy Bomber synthesis. No samples or third-party music.
Run with Python + numpy to deterministically regenerate all 44.1kHz PCM WAVs.
"""
from pathlib import Path
import wave, json
import numpy as np
SR=44100
OUT=Path(__file__).parent
rng=np.random.default_rng(4712)
def write(name, data):
    data=np.asarray(data)
    peak=float(np.max(np.abs(data)))
    if peak>0.88: data=data*(0.88/peak)
    with wave.open(str(OUT/(name+'.wav')), 'wb') as w:
        w.setnchannels(1 if data.ndim==1 else data.shape[1]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data*32767).astype('<i2').tobytes())
    return {'seconds':round(len(data)/SR,3),'peak':round(float(np.max(np.abs(data))),4)}
def tone(freq,dur,vol=.3):
    t=np.arange(int(dur*SR))/SR
    env=(1-np.exp(-t*130))*np.exp(-t*7/max(dur,.1))
    return vol*env*(np.sin(2*np.pi*freq*t)+.22*np.sin(2*np.pi*freq*2*t)+.08*np.sin(2*np.pi*freq*3*t))
def chirp(start,end,dur,vol=.3):
    t=np.arange(int(dur*SR))/SR
    phase=2*np.pi*(start*t+(end-start)*t*t/(2*dur))
    env=np.sin(np.pi*t/dur)**1.5
    return np.sin(phase)*env*vol
def sequence(notes,step=.08):
    a=np.zeros(int((len(notes)*step+.35)*SR))
    for i,n in enumerate(notes):
        q=tone(440*2**((n-69)/12),.28,.22); s=int(i*step*SR); a[s:s+len(q)]+=q
    return a
meta={}
meta['place']=write('place',chirp(420,170,.12,.3))
# Soft bubble pop instead of a violent/explosive sound.
pop=chirp(720,85,.22,.38); pop+=rng.normal(0,.025,len(pop))*np.hanning(len(pop))
meta['pop']=write('pop',pop)
meta['chain']=write('chain',sequence([79,83,86],.045))
meta['hit']=write('hit',sequence([67,63,60],.085))
meta['pickup']=write('pickup',sequence([76,81,88],.065))
meta['wave']=write('wave',sequence([72,76,79,84,88],.10))
meta['ui']=write('ui',tone(880,.10,.20))
# 16-bar original pentatonic candy-waltz/arcade loop, 120 BPM, 4/4.
# Instruments: bell-pluck, soft sine bass, gentle shakers. Exactly 32 sec.
beat=.5; duration=32.; music=np.zeros((int(duration*SR),2))
def add(note,at,dur,amp,pan=0,kind='bell'):
    f=440*2**((note-69)/12); t=np.arange(int(dur*SR))/SR
    if kind=='bass':
        env=np.minimum(t/.01,1)*np.exp(-t*4); q=(np.sin(2*np.pi*f*t)+.13*np.sin(4*np.pi*f*t))*env*amp
    else: q=tone(f,dur,amp)
    idx=(np.arange(len(q))+int(at*SR))%len(music)
    music[idx,0]+=q*np.sqrt((1-pan)/2); music[idx,1]+=q*np.sqrt((1+pan)/2)
chords=[(48,[72,76,79]),(53,[72,77,81]),(57,[72,76,81]),(55,[71,74,79])]*4
melodies=[[76,79,84,81,79,76,74,72],[77,81,84,86,84,81,79,77],[81,84,88,84,81,79,76,79],[79,74,71,74,79,81,79,74]]
for bar,(bass,chord) in enumerate(chords):
    for b in range(4):
        add(bass+(12 if b%2 else 0),bar*2+b*.5,.45,.13,0,'bass')
        add(chord[b%3]-12,bar*2+b*.5+.25,.4,.065,-.45)
    melody=melodies[bar%4]
    for i,n in enumerate(melody):
        add(n,bar*2+i*.25,.36,.095 if i%2==0 else .063,.28)
    for i in range(8):
        count=int(.045*SR); q=rng.normal(0,.012,count)*np.exp(-np.arange(count)/SR*100)
        start=int((bar*2+i*.25)*SR); music[start:start+count,0]+=q;music[start:start+count,1]+=q*.8
# Very subtle room echo, wraparound preserves seamless musical decay.
music+=np.roll(music,int(.15*SR),axis=0)*.12
meta['music_loop']=write('music_loop',music)
(OUT/'audio_manifest.json').write_text(json.dumps({'sample_rate':SR,'license':'Original project-owned synthesized audio','music_bpm':120,'music_bars':16,'loop_seconds':32,'files':meta},indent=2)+'\n')
print(json.dumps(meta,indent=2))
