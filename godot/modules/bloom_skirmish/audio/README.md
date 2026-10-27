# 绒芽争园 · original audio

`A Little Room to Bloom` is an original 16-bar, 108 BPM, G-major light-garden score. A new melody is played by soft wooden plucks, spare bell accents, round pizzicato bass, a seed-shaker texture, finger woodblocks and a soft hand-drum. Duration: **35.555556 seconds**, stereo 44.1 kHz signed 16-bit PCM. Circular reflections preserve tails at the loop seam. No third-party music, recordings, sample packs or sound fonts were used.

All music and SFX were authored and synthesized specifically for this project with the included `synthesize_audio.py`. These original project assets may be used, modified and redistributed with the project; no third-party audio license obligations. The source is deterministic (seed 20261027), so the shipped WAVs can be regenerated rather than merely described.

```sh
python3 godot/modules/bloom_skirmish/audio/synthesize_audio.py # Python 3 + NumPy
```

`audio_manifest.json` contains durations, sample format, authored cue descriptions, SHA-256 hashes, peak/RMS levels, clipping counts and measured loop seam difference. Every output has zero clipped samples. The score peaks at -3.61 dBFS / -22.65 dBFS RMS; one-shot cues leave additional mix headroom. Keep music below game cues and bound simultaneous shot voices.

| File | Cue |
|---|---|
| music_loop.wav | Cheerful seamless score; enable forward loop on the loaded AudioStreamWAV |
| shoot.wav | Soft pressurized wet squirt: filtered turbulence + irregular liquid resonances |
| hit.wav | Low wet plop/splat with spreading droplets |
| pod.wav | Two woody launch notes |
| bloom.wav | Broad nectar splash and widening stereo droplet scatter |
| dash.wav | Airy leaf swish and spring chirp |
| defeat.wav | Gentle descending phrase |
| victory.wav | Original ascending major victory cadence |
| respawn.wav | Three-note return chirp |
| round_start.wav | Four-note start signal |
| ui_click.wav | Light wood tap |
| countdown.wav | Short clear countdown bell |
| ready.wav | Seed reserve / ability-ready chirp |

Pause/exit and sound settings belong to the runtime. Stop all players on module exit, and do not let paused music or firing loops leak into the island host.

## Liquid-feedback revision (v2)

Only `shoot.wav`, `hit.wav` and `bloom.wav` changed. Their names and runtime integration remain stable. The music and the other nine SFX (ten WAV files total) are byte-identical to the original approved set. The new cues use independently seeded filtered turbulence and inharmonic collapsing-bubble oscillators, not sampled water recordings; the former dry tap / musical bloom arpeggio is removed from these three cues.

- Shoot: 0.22 s, -4.29 dBFS peak / -21.94 dBFS RMS.
- Hit: 0.34 s, -3.74 dBFS peak / -21.54 dBFS RMS.
- Bloom: 1.05 s, -2.85 dBFS peak / -24.28 dBFS RMS, stereo scatter of 22 decaying droplets.

Automated checks cover PCM format, duration, checksum, zero endpoint fades, negligible DC offset and no clipping. A clean regeneration reproduces all WAV hashes. These are waveform/reproduction checks, **not a subjective listening pass**: monitored audio was unavailable in the cloud environment. The pressure/splat/splash descriptions state the intended sound design; final perceptual balance should be assessed in actual playback alongside the fluid visuals.
