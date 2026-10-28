# Volcano Escape — Dispatch at Dawn

Original AI-assisted composition and implementation authored for this module. No pre-existing song, melody, sound recording or previous game's theme was sampled or adapted. `generate_audio.py` is the complete deterministic source: D Dorian plucked partials, alternating bass, seeded soft noise taps, 24 bars at 96 BPM (60 seconds). Nine short instrument-based event cues supplement but never replace visible information.

This is procedural additive synthesis, not an acoustic performance or an image/music generation service recording. Audio QA is numerical, **not subjective listening approval**: sample count, duration, DC offset, peak/RMS, zero hard clipping, SHA-256 in `audio_manifest.json`. Mix bounded to six simultaneous cues plus one music player, alerts rate-limited, explicit paused state and immediate idempotent retirement including OS close. No fade timer whose completion depends on resumed game processing.

All composition/code in this folder is original project content. Font is separate SIL OFL licensed Noto Sans CJK; see ../ui/OFL.txt.
