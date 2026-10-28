# 见习小妖王 / Apprentice Yokai King

Self-contained Godot 4.7.2 2D action roguelite. Entry: `main.tscn`, root Node2D,
`start(context = {})`, `exit_requested`. No autoload or cross-module resource dependency.

## Play

- WASD / arrows: move. Mouse: aim.
- Left press/release: light swing; hold ≥0.45s: partial slam; ≥0.75s: full slam.
- Space: dodge, cancels charge without attacking. Esc: pause.
- Accessibility mode: left click light; right click starts charging, right click again releases.
- Settings support sound, reduced flashes, shake, forward-cone aim assist, six remappable keys.
- Practice is safe and skippable; a non-attacking grunt resets after a successful hit sequence.
- Six finite waves; first five ends each award one of three upgrades. First choice selects
  exactly one of three mutually exclusive cores. Five total choices from twelve cards.
- Life zero / explicit deadline = loss; survive and defeat the final boss = victory.
- No automatic attacks, collection objective, protected tower, or infinite wave budget.

## Runtime architecture

`run_model.gd` is a RefCounted simulation, using 120 Hz internal fixed steps and seeded RNG.
`advance(delta, input)` accepts movement/aim vectors plus press/release/dodge/skip edges.
`build_model.gd` is seeded, filtered card selection. `profile_store.gd` validates and atomically
writes `user://games/apprentice_yokai_king/profile.json` schema 1. Corrupt/future files are
read-only until a double-confirmed reset preserves their original bytes in `.preserved`.
Standard and assist records are separate; quit is abandonment, not a completed result.
No live run is restored. InputMap is never mutated.

`main.gd` uses event coordinates transformed into logical coordinates (1280×800), including
clicks with no preceding MouseMotion. Modal hit targets invalidate immediately; pause is
idempotent. Standalone WM-close and menu exit both await audio shutdown. Hosted exits only
emit the signal, and do not change the host's auto-quit policy.

## Assets

Original AI-assisted character/action raster assets, source records and deterministic
extraction live in `art/`; generated original audio and reproduction code in `audio/`.
Hero has 32 poses (8 rows × 4 frames). Enemies have idle/walk/anticipation/attack strips.
Hero faces right; enemies face left. Every frame anchors feet at (128,220), 256² cells.
UI has twelve card illustrations. Font is a module-local Noto Sans CJK SC subset, SIL OFL;
`ui/FONT-LICENSE.txt` and `ui/subset_font.py` preserve license and reproduction instructions.
Fallback geometric sprites are engineering error fallbacks, not accepted final art.

## Reproduce verification

Run fresh import before scripts. Use writable, isolated XDG_DATA_HOME / XDG_CONFIG_HOME /
XDG_CACHE_HOME outside the repository. Exact engine tested:
`/workspace/scratch/e3e9ec015b32/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`.

```sh
"$GODOT" --headless --path godot --editor --import --quit
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_profile_build.gd
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_combat.gd
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_lifecycle.gd
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_inputs.gd
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_window_close.gd
"$GODOT" --headless --path godot --script res://modules/apprentice_yokai_king/tests/test_playthrough.gd -- route=ayk_core_wind
# Other routes: ayk_core_thunder, ayk_core_quake; optional mode=assist seed=2081
```

### Evidence boundaries (2026-10-28)

- Profile/build: 3,158 assertions; combat fixtures: 52 assertions. Fixtures construct states
  to check corner cases and are **not** proof of a playable completed run.
- Event input tests cover primary short click, accessible toggled charge, pause freezing,
  held Enter non-reentry, no-input real defeat, reset. Four hosted lifecycle cycles pass.
- `test_playthrough.gd` controls only legal movement/aim/press/release/dodge actions and legal
  card selections. It does not alter HP, enemy HP, phase, speed, damage or victory flags.
  Seed 2081 completed all six waves / five choices on all three standard routes and assist.
  Measured expert-controller battle times: wind 175.28s, thunder 218.39s, quake 205.98s.
  **This is shorter than the design's 9–12 minute normal-play target; pacing remains an
  explicitly unmet tuning target.** No inflated health or empty waits were added to hide it.
- These are automated deterministic input runs, not manual desktop play, subjective feel,
  a performance/60fps guarantee, or a claim of browser/mobile/controller validation.
- Graphical desktop checks, independent audit and host registration are owned by the parent
  integration task; their results are recorded separately. Forced `--quit-after` is not a
  shutdown acceptance test.

Test logs are outside the repo in `/workspace/scratch/e3e9ec015b32/next-games-records/`.

Exact input replay is also available: pass `trace=/absolute/path/run.jsonl` to
`test_playthrough.gd`, then invoke `test_replay.gd -- /absolute/path/run.jsonl`.
The trace stores seed, normal dt, raw action vectors/edges and card choices, not state writes.
Wind seed2081 recorded and replayed 11,602 frames to the same win/HP/time/five choices.
