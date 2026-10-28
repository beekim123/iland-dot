# Interface/audio focused checks — 2026-10-27

Engine: explicitly `../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`; headless only. Command from repo root:

```
HOME=/tmp/beach-ui-home XDG_DATA_HOME=/tmp/beach-ui-home XDG_CONFIG_HOME=/tmp/beach-ui-home XDG_CACHE_HOME=/tmp/beach-ui-home ../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot --script res://modules/beach_cleanup/ui/test_interface.gd
```

PASS `BEACH_UI_AUDIO_TEST`: logical layout fits exactly at 1280×720, 1024×768, 960×540, 640×360; twelve occupied cargo slots; E depot prompt; pause, return/replay confirmations and Escape cancel; completion retains supplied before/after textures and confirmation cancellation restores it; effects remain bounded to eight voices after 200 requests; WeakRef deletion on normal/paused shutdown, simulated 400ms process step, actual paused tree at Engine.max_fps=5, and immediate parent deletion. Final run no parse errors or leaked-object/resource warnings after allowing audio server drain. Chinese static HUD glyph audit: zero missing.

Not performed: native visual rendering/inspection, actual sound listening, human keyboard/mouse gameplay, runtime full completion. Arithmetic viewport bounds are not evidence of pixel-perfect readability. Preview fixture: `--script res://modules/beach_cleanup/ui/preview_interface.gd`, optional user args `-- --pause` or `-- --completion`; completion fixture without runtime camera textures intentionally has empty frames. Actual runtime must provide identical-camera captures.

No borrowed visual design or prior theme. Font utility/license reuse only. Initial test exited before audio server drain and reported WAV playback refs; subsequent retirement explicitly clears stream references and test waits 300ms after deletion, including real paused 5FPS case. No host quit behavior altered.

## Screenshot-led density revision

Inspected `build/previews/beach-game-first.png` (existing captured gameplay): initial HUD was oversized. Revised main signs to 220×76 and 200×86 logical pixels, merged ecology into the left sign, shortened controls to 32px-high buttons, and reduced footer from full-width 920×60 to centered 600×38. Main lettering 18–22px. Shallow 2px bevels, subtle end-grain and pin holes replace thick panels. Long status lines are clipped with ellipsis rather than spilling into the scene. All existing headless cases PASS again after revision. Result postcard now shows prior distance/unload best (or first-postcard message). Font subset regenerated after runtime scripts landed. Revised native screenshot inspection still pending parent capture.

Same-node reentry: `reset_session()` clears completion state, retained before/after textures, and modal. Added stale-result reset assertion; full focused suite PASS after this addition. Regenerated font following shortened runtime hints.

Final-load regression: ground_remaining=0, cargo_used=1, delivered=23 away from depot now prioritizes “海滩已清理 · 回卸货站卸下最后一车” over pickup/hint/stale-capacity text. Near depot still prioritizes the E-unload instruction. Added explicit assertions for both, including stale hint/capacity input; full headless UI/audio suite PASS. Font regenerated for this caption.
