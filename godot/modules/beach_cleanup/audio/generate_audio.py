"""Original AI-assisted deterministic synthesis. No samples or borrowed melody."""
from pathlib import Path
import numpy as np
import wave, json
ROOT=Path(__file__).parent
SR=24000
rng=np.random.default_rng(267031)
def save(name,a,loop=False):
    peak=float(np.max(np.abs(a)))
    if peak>.82: a=a*.82/peak
    pcm=(np.clip(a,-1,1)*32767).astype('<i2')
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())
    return {'file':name+'.wav','seconds':len(a)/SR,'peak':float(np.max(np.abs(a))),'loop':loop}
def tone(freq,dur,amp=.2):
    t=np.arange(round(SR*dur))/SR
    env=(1-np.exp(-t*120))*np.exp(-t*3.8)*(np.clip((dur-t)/.08,0,1))
    return amp*env*(np.sin(2*np.pi*freq*t)+.21*np.sin(2*np.pi*freq*2.01*t)+.065*np.sin(2*np.pi*freq*3*t))
def note(midi):return 440*2**((midi-69)/12)
# Sixteen 3-beat bars, 72 bpm: sandwood mallet + low plucked fifths.
beat=60/72; duration=48*beat; music=np.zeros(round(duration*SR))
def place(buf,at,sound,wrap=False):
    start=round(at*SR)
    for off in range(0,len(sound),SR*4):
        ix=(start+np.arange(off,min(off+SR*4,len(sound))))
        if wrap: np.add.at(buf,ix%len(buf),sound[off:off+len(ix)])
        else:
            valid=ix<len(buf);buf[ix[valid]]+=sound[off:off+len(ix)][valid]
chords=[(50,57,62,66),(55,62,67,69),(47,54,59,62),(52,59,64,67)]
melodies=[[74,69,66,69],[74,76,71,69],[71,66,62,66],[71,69,67,64]]
for bar in range(16):
    chord=chords[bar%4]; t0=bar*3*beat
    place(music,t0,tone(note(chord[0]-12),2.3,.16),True)
    for j,pitch in enumerate(chord[1:]):place(music,t0+(j*.5+.5)*beat,tone(note(pitch),1.8,.095),True)
    melody=melodies[(bar//4+bar)%4]
    for j in range(2):place(music,t0+(j*1.5+.25)*beat,tone(note(melody[(bar+j)%4]),1.7,.10),True)
# Continuous periodic sea-breath; deterministic filtered noise, crossfaded seam.
noise=rng.normal(0,1,len(music));kernel=np.ones(180)/180
surf=np.convolve(noise,kernel,'same');t=np.arange(len(music))/SR
music+=surf*(.075+.055*np.sin(2*np.pi*t/duration*5))
n=1200; music[:n]*=np.linspace(.4,1,n);music[-n:]*=np.linspace(1,.4,n)
records=[save('shore_theme',music,True)]
for name,pitches,dur in [('pickup',[76,81],.23),('clamp_lift',[50,57],.28),('unload',[62,66,69],.65),('ecology',[74,78,81],1.0),('complete',[62,66,69,74,78],2.1),('capacity',[57,55],.42),('click',[83],.08)]:
    a=np.zeros(round(SR*dur))
    for i,pitch in enumerate(pitches): place(a,i*dur/(len(pitches)+1),tone(note(pitch),dur-i*dur/(len(pitches)+1),.23 if name!='click' else .12))
    if name=='clamp_lift':
        a+=rng.uniform(-.045,.045,len(a))*np.exp(-np.arange(len(a))/SR*19)
    records.append(save(name,a))
(ROOT/'audio_manifest.json').write_text(json.dumps({'authoring':'Original AI-assisted deterministic DSP, new melody and synthesis for Beach Cleanup. No external samples.','sample_rate':SR,'seed':267031,'files':records},indent=2)+'\n')
