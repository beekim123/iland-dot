# Tide Gulp independent QA

This directory is owned independently of the module implementation. It deliberately uses
small, explicit oracles instead of copying the very large Bloom Skirmish search suite.

```sh
# All third-game checks + host routing + a genuine fresh standalone extraction:
GODOT_BIN=/path/to/Godot tools/qa/tide_gulp/run.sh
# Just the real extraction, fresh import and identical module/independent tests:
GODOT_BIN=/path/to/Godot tools/qa/tide_gulp/extraction.sh
# Repository-wide aggregate (includes unrelated first/second game regressions):
GODOT_BIN=/path/to/Godot tools/test_all.sh
```

Both wrappers isolate `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` in
`mktemp` QA directories and retain logs. They fail on nonzero status **or** Godot
script/parse/resource/leak errors, including engines which exit zero after an error.
Do not run the storage scripts against player data.

## Evidence boundaries

- `resource_probe.gd`: ResourceLoader existence, actual PackedScene load/instance,
  host ABI, standalone deferred auto-start and real fish construction. Third purple
  portal was enabled only after this gate passed; enablement is not visual completion.
- `independent.gd`: independent 0.8P / 1.25P and score-bracket oracle, mouth vs tail /
  flank, peer separation, dash vulnerability, terminal immutability, 35+5+20 tide,
  actual warning + windup, committed lunge, finite chase, safe/off-screen spawn
  clearance, six-stage continuous collision growth, adult navigable trunk, fixed
  five chunks / sixty residents, three ecological regions and depletion on revisit.
- **Legal hunting run:** 600 seconds, only `start/restart`, `command`, `tick` and
  event reads; real failures restart honestly. No gifted score/growth, relocated
  fish, debug immortality or enemy disabling. Must reach stage 3 by real meals.
  Per-meal points and effective-food events reconcile with the score ledger.
- **Single-life long run:** a separate uninterrupted 600-second legal steering run
  near the authored safe-origin nursery, without resets or mutation. This bounds
  fish/chunks/depletion/events with the queue intentionally undrained; it is **not**
  evidence of ten minutes of aggressive hunting or all-biome survival.
- Synthetic boundary/collision/geometry fixtures are clearly separated from both
  command-only runs. The module author's 1800-second recycle fixture is also a
  controlled stress fixture, not a legal survival achievement.
- `lifecycle.gd`: six new scene entries; actual legal feeding; XY visual placement;
  camera-local lighting; screen-edge danger projection and nearest-two cue budget;
  pause/focus, honest death/result/restart/return, bounded render pool, audio/HUD
  retirement and orphan stability. Terminal collision injection is a labeled fixture.
- `storage.gd`: actual disk JSON preservation (bad/future/nonfinite schemas), atomic
  round-trip, fixed namespace against forged context, injected service ID, and
  byte-for-byte isolation of candy/Bloom/hub profiles. Test-created foreign-file
  sentinels are removed after comparison.
- `assets.py`: read-only validation of local 3D eight-joint skins/editable sources,
  quoted CJK glyph coverage, font/audio hashes and waveform bounds, and absence of
  foreign `res://` dependencies. It does not claim subjective listening.
- `extraction.sh`: module-only copy and distinct app identity; byte comparison of
  every copied file; no prebuilt import cache; fresh Godot import; identical
  author and independent suites resolve `res://` against the standalone project.
- `godot/tests/check_app.gd`: actual purple portal plus 24 alternating entries into
  all three modules, duplicate launch rejection, same island camera/HUD/audio
  restoration, no orphan growth. Fourth catalog slot stays unimplemented/locked.
- `godot/hub/tests/test_portal_picking.gd`: real island/camera ray and actual
  press/release input; static triangle occlusion rather than empty foliage AABBs;
  conservative skinned-actor proxies, bounded 16384-triangle work and cache reset.
- `godot/hub/tests/test_portal_layout.gd`: all 63 authored ground sites, every
  valid initial-camera three-door combination, five visible samples per door,
  screen-space non-overlap, 1000 seeds and 32 real hub setups. No new terrain.

Actual graphics, watercolor readability, mouse feel, listening, browser/WebGL and
performance require separate graphical/manual evidence. Headless PASS does not
approve the art style, constitute a release, or authorize the fourth game.
