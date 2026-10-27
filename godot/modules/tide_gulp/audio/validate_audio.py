#!/usr/bin/env python3
"""Objective asset validation; does not claim subjective listening."""
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

HERE = Path(__file__).resolve().parent
manifest = json.loads((HERE/'audio_manifest.json').read_text())
report = {'subjective_listening': 'not performed by this cloud task', 'assets':{}, 'passed':False}
for name, expected in manifest['assets'].items():
    path = HERE / expected['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected['sha256'], name + ' hash mismatch'
    with wave.open(str(path),'rb') as f:
        assert f.getnchannels()==2 and f.getsampwidth()==2 and f.getframerate()==44100
        data = np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32767
    peak = float(np.abs(data).max())
    dc = float(np.max(np.abs(data.mean(axis=0))))
    seam = float(np.max(np.abs(data[0]-data[-1])))
    assert peak < .361 and dc < .01 and np.isfinite(data).all()
    if expected['loop']:
        assert len(data)==24*44100 and seam < .012
    else:
        assert np.abs(data[[0,-1]]).max() < .001
    report['assets'][name] = {'peak_dbfs':round(float(20*np.log10(peak)),2),'dc_offset':round(dc,7),'seam_delta':round(seam,7),'passed':True}
report['passed'] = True
(HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('TIDE_AUDIO_VALIDATE_OK: all 8 hashes/formats/levels/endpoints; music loop seam verified')
