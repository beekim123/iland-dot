#!/usr/bin/env python3
"""Validate the actual shipped WAV payloads against their reproducible manifest."""
from pathlib import Path
import hashlib, json, math, wave
import numpy as np
root=Path(__file__).resolve().parent
manifest=json.loads((root/'audio_manifest.json').read_text())
for name, meta in manifest['files'].items():
    path=root/name
    assert hashlib.sha256(path.read_bytes()).hexdigest()==meta['sha256'], name+' checksum'
    with wave.open(str(path),'rb') as w:
        assert w.getframerate()==44100 and w.getsampwidth()==2 and w.getcomptype()=='NONE', name+' format'
        assert w.getnchannels()==meta['channels'], name+' channels'
        count=w.getnframes(); duration=count/w.getframerate()
        samples=np.frombuffer(w.readframes(count),dtype='<i2').reshape((-1,w.getnchannels()))
    assert abs(duration-meta['duration_seconds'])<1e-6,name+' duration'
    assert np.isfinite(samples).all() and np.max(np.abs(samples.astype(np.int32)))<32767,name+' clipping'
    assert abs(samples.astype(np.float64).mean())<1,name+' DC offset'
    if meta.get('loop'):
        assert 32<duration<48,name+' score length'
        seam=float(np.max(np.abs(samples[0].astype(float)-samples[-1])))/32767
        assert seam<0.002,name+' loop seam'
    else:
        assert np.max(np.abs(samples[0]))==0 and np.max(np.abs(samples[-1]))==0,name+' one-shot fade'
print('BLOOM AUDIO PASS:',len(manifest['files']),'original WAVs; checksums, PCM format, duration, DC, clipping, fades and loop seam verified.')
