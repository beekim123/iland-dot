#!/usr/bin/env python3
"""Original score and game sounds for Bloom Skirmish / 绒芽争园.
No samples, sound libraries, generative model output or third-party compositions.
Reproduce with Python 3 + NumPy: python3 synthesize_audio.py
All score pitches, rhythm, synthesis, and spatialization authored for this game.
"""
from pathlib import Path
import hashlib, json, math, wave
import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parent
RNG = np.random.default_rng(20261027)
MANIFEST = {"title": "绒芽争园 · A Little Room to Bloom", "authorship": "Original procedural composition and sound design authored for this project; no sampled or third-party material.", "license": "Project-owned original assets; same usage and redistribution terms as the enclosing project.", "sample_rate": RATE, "format": "PCM signed 16-bit WAV", "generator": "synthesize_audio.py", "seed": 20261027, "files": {}}

def freq(midi): return 440 * 2 ** ((midi - 69) / 12)
def env(t, duration, attack=.006, decay=6):
    return np.minimum(t / attack, 1) * np.exp(-decay * t / duration) * np.minimum(np.maximum(duration-t, 0) / .02, 1)

def pluck(note, duration=.6, brightness=.65):
    t=np.arange(round(duration*RATE))/RATE
    f=freq(note)
    body=(np.sin(2*np.pi*f*t)*np.exp(-4.8*t/duration)
          + .35*brightness*np.sin(2*np.pi*f*2.005*t)*np.exp(-11*t/duration)
          + .18*brightness*np.sin(2*np.pi*f*3*t)*np.exp(-16*t/duration)
          + .07*np.sin(2*np.pi*f*.5*t)*np.exp(-7*t/duration))
    return body*np.minimum(t/.004,1)*np.minimum((duration-t)/.03,1)

def bell(note,duration=.7):
    t=np.arange(round(duration*RATE))/RATE; f=freq(note)
    return (np.sin(2*np.pi*f*t)*np.exp(-5*t/duration)+.26*np.sin(2*np.pi*f*2.76*t)*np.exp(-12*t/duration)+.08*np.sin(2*np.pi*f*5.4*t)*np.exp(-18*t/duration))*np.minimum(t/.006,1)*np.minimum((duration-t)/.025,1)

def bass(note,duration=.35):
    t=np.arange(round(duration*RATE))/RATE; f=freq(note)
    return (np.sin(2*np.pi*f*t)+.17*np.sin(4*np.pi*f*t)+.08*np.sin(6*np.pi*f*t))*env(t,duration,.008,3.5)

def noise(duration): return RNG.standard_normal(round(duration*RATE))
def shaker(duration=.08):
    n=noise(duration); t=np.arange(len(n))/RATE
    # Seed-shaker: highpassed dry texture, deliberately very quiet in score.
    n=np.r_[n[0],np.diff(n)]*.35
    return n*np.minimum(t/.005,1)*np.exp(-t/(duration*.22))

def wood(duration=.065,high=False):
    t=np.arange(round(duration*RATE))/RATE
    f=1180 if high else 690
    return (np.sin(2*np.pi*f*t)+.34*np.sin(2*np.pi*f*1.61*t))*env(t,duration,.001,6)

def soft_kick():
    d=.15; t=np.arange(round(d*RATE))/RATE
    phase=2*np.pi*(64*t+30*.021*(1-np.exp(-t/.021)))
    return np.sin(phase)*env(t,d,.002,5)

def stereo_add(buf, signal, time, gain=1, pan=0, wrap=False):
    idx=round(time*RATE)
    angle=(pan+1)*math.pi/4
    pair=np.array([math.cos(angle),math.sin(angle)])*gain
    signal=signal[:,None]*pair[None,:]
    if wrap:
        inds=(np.arange(len(signal))+idx)%len(buf)
        np.add.at(buf,inds,signal)
    else:
        end=min(idx+len(signal),len(buf))
        if end>idx: buf[idx:end]+=signal[:end-idx]

def finish(name, data, peak=.76, loop=False, details=None):
    data=np.asarray(data,dtype=np.float64)
    data-=data.mean(axis=0)
    # Tiny fades on one-shot sounds prevent nonzero endpoints / clicks.
    if not loop:
        n=min(256,len(data)//8)
        fade=np.linspace(0,1,n)
        if data.ndim==2: fade=fade[:,None]
        data[:n]*=fade; data[-n:]*=fade[::-1]
        # Remove any DC introduced by edge fades without disturbing zero endpoints.
        window=np.sin(np.linspace(0,np.pi,len(data)))**2
        if data.ndim==2: window=window[:,None]
        data-=window*(data.mean(axis=0)/window.mean(axis=0))
    maximum=np.max(np.abs(data))
    if maximum>0: data*=peak/maximum
    pcm=np.round(data*32767).astype('<i2')
    path=ROOT/(name+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1 if data.ndim==1 else data.shape[1]);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
    rms=float(np.sqrt(np.mean(data*data)))
    metadata={"duration_seconds":round(len(data)/RATE,6),"channels":1 if data.ndim==1 else data.shape[1],"peak_dbfs":round(20*math.log10(float(np.max(np.abs(data)))),3),"rms_dbfs":round(20*math.log10(rms),3),"clipped_samples":int(np.sum(np.abs(pcm)>=32767)),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"loop":loop}
    if loop: metadata["loop_seam_delta"]=float(np.max(np.abs(data[-1]-data[0])))
    if details: metadata.update(details)
    MANIFEST['files'][path.name]=metadata
    print(path.name,metadata['duration_seconds'],'sec',metadata['peak_dbfs'],'dBFS peak',metadata['rms_dbfs'],'dBFS rms')

def compose():
    bpm=108; beat=60/bpm; bars=16; length=round(beat*4*bars*RATE)
    out=np.zeros((length,2),dtype=np.float64)
    # Original 16-bar melody. Half-beat positions; deliberate rests give action SFX space.
    melody=[
      [(0,74),(1.5,79),(2.5,81),(3,83)],
      [(0,81),(1,79),(2,76),(3,74)],
      [(0,72),(1.5,76),(2.5,79),(3.5,76)],
      [(0,78),(1,76),(2,74),(3,69)],
      [(0,74),(1,79),(2,83),(3.5,86)],
      [(0,83),(1,81),(2.5,79),(3.5,76)],
      [(0,76),(1.5,79),(2.5,84),(3,83)],
      [(0,81),(1,78),(2.5,74)],
      [(0,83),(1.5,86),(2.5,83),(3,81)],
      [(0,79),(1,76),(2,74),(3.5,76)],
      [(0,79),(1,84),(2.5,83),(3.5,79)],
      [(0,78),(1.5,81),(2.5,78),(3,74)],
      [(0,74),(1,79),(2,81),(3,83)],
      [(0,86),(1.5,83),(2.5,81),(3.5,79)],
      [(0,76),(1,79),(2,84),(3,83)],
      [(0,81),(1,78),(2,74),(3,71)],
    ]
    chords=[(43,[67,71,74,78]),(40,[64,67,71,74]),(36,[64,67,72,76]),(38,[66,69,74,78])]
    for bar in range(bars):
        root,chord=chords[bar%4]
        start=bar*4*beat
        for step in range(8):
            swing=.027 if step%2 else 0
            at=start+step*.5*beat+swing
            stereo_add(out,shaker(),at,.021 if step%2 else .014,(-.55 if step%2 else .55),True)
            if step in [0,3,4,7]:
                note=chord[(step+bar)%4]
                stereo_add(out,pluck(note,.45,.4),at,.061,-.35,True)
        for when,note in melody[bar]:
            sig=pluck(note,.66,.62)
            stereo_add(out,sig,start+when*beat,.115,.12,True)
            # Delicate bell accents, not a continuous piercing top line.
            if when==0 and bar%2==0: stereo_add(out,bell(note+12,.85),start+when*beat,.022,.45,True)
        for when,note,g in [(0,root,.15),(1.5,root+12,.07),(2,root+7,.115),(3.5,root+12,.055)]:
            stereo_add(out,bass(note,.38),start+when*beat,g,-.05,True)
        for when in [0,2]: stereo_add(out,soft_kick(),start+when*beat,.060,0,True)
        for when in [1,3]: stereo_add(out,wood(.075,True),start+when*beat,.027,.42,True)
        if bar%4==3:
            for when in [3,3.5,3.75]: stereo_add(out,wood(.055,False),start+when*beat,.024,-.5,True)
    # Circular room reflections maintain seamless tails over the loop boundary.
    dry=out.copy()
    for delay,gain in [(.087,.11),(.173,.085),(.291,.05)]:
        out+=np.roll(dry[:,::-1],round(delay*RATE),axis=0)*gain
    finish('music_loop',out,.66,True,{"bpm":bpm,"bars":bars,"meter":"4/4","key":"G major","instrumentation":"Soft wooden plucks, bell accents, round pizzicato bass, seed shaker, finger woodblock and soft hand-drum","composition":"Original 16-bar melody with Gmaj7 / Em7 / Cmaj9 / D6 harmony; circular room tails; no sampled sources."})

def one_shots():
    # Preserve the established PRNG stream for every unchanged cue (especially
    # dash). These counts were consumed by v1 shoot/hit, now replaced below by
    # independently seeded liquid synthesis. Other shipped WAVs remain identical.
    RNG.standard_normal(round(.16*RATE))
    RNG.standard_normal(round(.23*RATE))
    buf=np.zeros((round(.54*RATE),2))
    stereo_add(buf,pluck(55,.3),0,.6,-.15);stereo_add(buf,pluck(62,.34),.095,.5,.15)
    finish('pod',buf,.68,details={"cue":"Two woody seed-pod launch notes."})
    RNG.standard_normal(round(.48*RATE)) # former bloom noise stream; keep dash stable
    t=np.arange(round(.30*RATE))/RATE;n=noise(.30)
    smooth=np.convolve(n,np.ones(15)/15,mode='same')
    dash=smooth*np.sin(np.pi*t/.30)**1.5+.10*np.sin(2*np.pi*(270*t+1500*t*t))*np.sin(np.pi*t/.30)**2
    finish('dash',dash,.58,details={"cue":"Airy leaf swish with upward spring chirp."})
    for name,notes,spacing,dur in [('defeat',[71,69,66,62],.21,1.6),('victory',[67,71,74,79,83,86],.13,2.1),('respawn',[62,67,71],.09,.85),('round_start',[67,71,74,79],.11,1.1)]:
        buf=np.zeros((round(dur*RATE),2))
        for i,n in enumerate(notes):
            sig=pluck(n,.85,.65) if name=='defeat' else bell(n,.9)
            stereo_add(buf,sig,i*spacing,.7,-.35+.7*i/(len(notes)-1))
        finish(name,buf,.72,details={"cue":name.replace('_',' ')+' original musical earcon'})
    finish('ui_click',wood(.08,True),.43,details={"cue":"Light UI wood tap."})
    finish('countdown',bell(79,.24),.57,details={"cue":"Clear short countdown bell."})
    buf=np.zeros((round(.58*RATE),2))
    stereo_add(buf,pluck(74,.35),0,.5,-.1);stereo_add(buf,bell(86,.44),.1,.32,.1)
    finish('ready',buf,.58,details={"cue":"Seed reserve / skill ready chirp."})

def liquid_band(rng, duration):
    """Soft band-limited turbulent air/water; no brittle white-noise attack."""
    n=rng.standard_normal(round(duration*RATE))
    short=np.hanning(19); short/=short.sum()
    long=np.hanning(111); long/=long.sum()
    return np.convolve(n,short,mode='same')-.70*np.convolve(n,long,mode='same')

def liquid_drop(start_hz, end_hz, duration, decay=.027):
    """An inharmonic collapsing-bubble chirp, deliberately not a musical note."""
    t=np.arange(round(duration*RATE))/RATE
    tau=duration*.24
    phase=2*np.pi*(end_hz*t+(start_hz-end_hz)*tau*(1-np.exp(-t/tau)))
    wave=np.sin(phase)+.19*np.sin(phase*1.71+.35)*np.exp(-t/.016)
    return wave*np.minimum(t/.0025,1)*np.exp(-t/decay)*np.minimum((duration-t)/.012,1)

def mono_add(buf, signal, time, gain=1):
    start=round(time*RATE); end=min(start+len(signal),len(buf))
    if end>start: buf[start:end]+=signal[:end-start]*gain

def liquid_feedback():
    # Independent cue seed prevents this rework from changing the score, dash,
    # or other game signals. Original synthesis only: no recordings/samples.
    rng=np.random.default_rng(2026102702)
    duration=.22; t=np.arange(round(duration*RATE))/RATE
    pressure=np.minimum(t/.006,1)*np.exp(-t/.063)*(0.82+.18*np.sin(2*np.pi*43*t)**2)
    squirt=liquid_band(rng,duration)*pressure*1.45
    for when,start,end,gain in [(0.0,1450,640,.29),(.028,940,390,.25),(.071,1770,990,.12),(.108,1180,550,.10)]:
        mono_add(squirt,liquid_drop(start,end,.10,.025),when,gain)
    finish('shoot',squirt,.61,details={"cue":"Soft pressurized wet squirt: band-limited turbulence, fluttering jet envelope and irregular collapsing-bubble resonances.","revision":"wet feedback v2","synthesis_seed":2026102702})

    duration=.34; t=np.arange(round(duration*RATE))/RATE
    splat=liquid_band(rng,duration)*np.minimum(t/.003,1)*np.exp(-t/.053)*1.18
    mono_add(splat,liquid_drop(390,115,.21,.038),0,.64)
    for when,start,end,gain in [(.014,1210,480,.22),(.035,1810,790,.17),(.064,840,330,.15),(.103,1530,620,.10),(.157,970,430,.065)]:
        mono_add(splat,liquid_drop(start,end,.11,.026),when,gain)
    finish('hit',splat,.65,details={"cue":"Wet impact plop/splat: a low liquid body, short spreading noise and irregular small droplets; no wooden tap.","revision":"wet feedback v2","synthesis_seed":2026102702})

    duration=1.05; buf=np.zeros((round(duration*RATE),2)); t=np.arange(round(duration*RATE))/RATE
    splash=liquid_band(rng,duration)*np.minimum(t/.008,1)*np.exp(-t/.16)*1.35
    stereo_add(buf,splash,0,.66,-.15)
    stereo_add(buf,liquid_drop(310,92,.30,.064),0,.58,.1)
    # The burst spreads outward in time and stereo position, with diminishing
    # tiny pattering drops. No former four-note bell arpeggio remains.
    for i in range(22):
        when=.014+float(rng.uniform(0,.55))
        start=float(rng.uniform(720,2250)); end=start*float(rng.uniform(.32,.64))
        gain=.15*(1-when/.8)*float(rng.uniform(.65,1.1))
        stereo_add(buf,liquid_drop(start,end,.15,.032),when,gain,float(rng.uniform(-.8,.8)))
    finish('bloom',buf,.72,details={"cue":"Broad nectar splash with a low watery bloom and a widening stereo scatter of 22 decaying droplets; no bell/pluck melody.","revision":"wet feedback v2","synthesis_seed":2026102702})

if __name__=='__main__':
    compose();one_shots();liquid_feedback()
    (ROOT/'audio_manifest.json').write_text(json.dumps(MANIFEST,ensure_ascii=False,indent=2)+'\n')
