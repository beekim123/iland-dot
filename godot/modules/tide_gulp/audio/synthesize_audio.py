#!/usr/bin/env python3
"""Original Tide Gulp score + sounds; no samples or outside music.

Deterministic additive/filtered-noise synthesis with NumPy, 44.1 kHz PCM16.
Music is a 24-second circular composition: wrap-added notes plus periodic
pad phases make the loop seam continuous (not merely two faded ends).
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

HERE = Path(__file__).resolve().parent
SR = 44100
RNG = np.random.default_rng(271026)

def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)

def env(n, attack=.02, release=.09):
    e = np.ones(n)
    a, r = min(n, int(attack * SR)), min(n, int(release * SR))
    if a: e[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if r: e[-r:] *= np.sin(np.linspace(np.pi / 2, 0, r)) ** 2
    return e

def bell(note, duration=.7, amplitude=.2):
    t = np.arange(int(duration * SR)) / SR
    f = hz(note)
    tone = np.sin(2*np.pi*f*t) + .24*np.sin(2*np.pi*f*2*t)*np.exp(-6*t) + .09*np.sin(2*np.pi*f*3*t)*np.exp(-9*t)
    return amplitude * tone * np.exp(-4*t/max(duration, .1)) * env(len(t), .008, .08)

def flute(note, duration=1.0, amplitude=.1):
    t = np.arange(int(duration * SR)) / SR
    phase = 2*np.pi*hz(note)*t + .018*np.sin(2*np.pi*4.2*t)
    return amplitude * (np.sin(phase) + .10*np.sin(2*phase) + .035*np.sin(3*phase)) * env(len(t), .12, .23)

def bubble(start, end, duration=.18, amplitude=.2):
    t = np.arange(int(duration*SR))/SR
    rate = (end-start)/duration
    phase = 2*np.pi*(start*t+.5*rate*t*t)
    return amplitude * (np.sin(phase)+.12*np.sin(2*phase)) * env(len(t), .006, duration*.7)

def add_stereo(dest, sound, start, pan=0.0, wrap=False):
    i = int(round(start*SR))
    stereo = sound[:,None] * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)])[None,:]
    if wrap:
        np.add.at(dest, (np.arange(len(stereo))+i) % len(dest), stereo)
    elif i < len(dest):
        end = min(len(dest), i+len(stereo))
        dest[i:end] += stereo[:end-i]

def score():
    duration = 24.0
    audio = np.zeros((int(duration*SR), 2))
    # Eight unhurried 3/4 bars at 60 quarter-notes per minute.
    chords = [(60,64,67), (57,60,64), (65,69,72), (55,59,62), (60,64,67), (57,60,64), (65,67,72), (55,60,64)]
    melody = [(0,76,1.0), (1.5,79,.8), (3,81,1.2), (4.5,79,.7), (6,76,1.4), (8,72,.8), (9,74,1.2), (11,67,.7), (12,72,1.0), (13.5,76,1.2), (15,79,1.4), (17,76,.8), (18,74,1.0), (19.5,72,1.2), (21,67,1.0), (22.5,72,1.4)]
    for bar, notes in enumerate(chords):
        for beat, note in enumerate(notes):
            add_stereo(audio, bell(note+12, 1.6, .095), bar*3+beat, (-.27, .20, -.10)[beat], True)
        add_stereo(audio, flute(notes[0]-12, 2.95, .045), bar*3, 0, True)
    for idx, (start, note, duration_note) in enumerate(melody):
        add_stereo(audio, flute(note, duration_note, .055), start+.10, .12*np.sin(idx), True)
    # Very quiet periodic water bed, frequencies selected on exact loop bins.
    t = np.arange(len(audio))/SR
    for cycles, amp in [(3120,.005),(4656,.003),(6240,.002)]:
        periodic = amp*np.sin(2*np.pi*(cycles/duration)*t)*(1+.12*np.sin(2*np.pi*t/duration))
        audio[:,0] += periodic
        audio[:,1] += periodic
    return audio

def sfx():
    sounds = {}
    for name, duration in [('swallow',.28),('growth',1.20),('dash',.36),('warning',.65),('tide',1.45),('death',1.45),('button',.16)]:
        sounds[name] = np.zeros((int(duration*SR),2))
    add_stereo(sounds['swallow'], bubble(350,780,.21,.23), 0)
    add_stereo(sounds['swallow'], bell(88,.12,.08), .10, .12)
    for i,n in enumerate([72,76,79,84]): add_stereo(sounds['growth'], bell(n,.65,.18), i*.16, (i-1.5)*.12)
    t = np.arange(int(.32*SR))/SR
    noise = RNG.normal(0,1,len(t))
    smooth = np.convolve(noise, np.ones(25)/25, mode='same')
    dash = (smooth*.24 + np.sin(2*np.pi*(180*t+260*t*t))*.10)*env(len(t),.02,.22)
    add_stereo(sounds['dash'], dash, 0)
    for i in range(2): add_stereo(sounds['warning'], bell(67,.30,.17), i*.26)
    for i,n in enumerate([60,67,72,76]): add_stereo(sounds['tide'], flute(n,.70,.12), i*.22, -.4+i*.25)
    for i,n in enumerate([76,72,67,60]): add_stereo(sounds['death'], bell(n,.77,.16), i*.19, .15-i*.1)
    add_stereo(sounds['button'], bubble(610,920,.11,.12), 0)
    return sounds

def main():
    assets = {'music_loop':score(), **sfx()}
    manifest = {'title':'逐潮小鱼 · 纸海小调', 'author':'Original project synthesis, 2026-10-27', 'rights':'Original composition and synthesis; no third-party samples or music.', 'generator':'synthesize_audio.py', 'seed':271026, 'sample_rate':SR, 'channels':2, 'music_structure':'8 bars in 3/4, 60 BPM, C major / A minor pentatonic colours; 24-second periodic loop.', 'playback':'Music -9 dB, sounds -5 dB, maximum 4 simultaneous SFX voices; pause silences all players.', 'validation_note':'Objective waveform/seam/level validation only. No claim of subjective audition in a cloud environment.', 'assets':{}}
    for name,audio in assets.items():
        max_peak = .30 if name == 'music_loop' else .36
        peak = float(np.max(np.abs(audio)))
        if peak > max_peak: audio *= max_peak/peak
        audio = np.clip(audio, -.95, .95)
        data = np.round(audio*32767).astype('<i2')
        path = HERE / f'{name}.wav'
        with wave.open(str(path),'wb') as f:
            f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR); f.writeframes(data.tobytes())
        floating = data.astype(float)/32767
        peak = float(np.max(np.abs(floating)))
        rms = float(np.sqrt(np.mean(floating**2)))
        seam = float(np.max(np.abs(floating[-1]-floating[0])))
        manifest['assets'][name] = {'file':path.name, 'duration_seconds':len(data)/SR, 'peak':round(peak,6), 'peak_dbfs':round(20*np.log10(max(peak,1e-9)),2), 'rms_dbfs':round(20*np.log10(max(rms,1e-9)),2), 'clipped_samples':int(np.sum(np.abs(data)>=32767)), 'seam_delta':round(seam,7), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'loop':name=='music_loop'}
        assert peak <= .361 and np.isfinite(audio).all()
        if name == 'music_loop':
            assert seam < .012, f'Unexpected loop seam {seam}'
        else:
            assert np.max(np.abs(floating[[0,-1]])) < .001
    (HERE/'audio_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('TIDE_AUDIO_SYNTH_OK: 8 original stereo WAV files; no clipping; seamless periodic loop')

if __name__ == '__main__': main()
