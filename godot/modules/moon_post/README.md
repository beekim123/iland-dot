# 月影邮差 / Moon Post

An original, self-contained cozy synchronized-movement puzzle demo for 晴贝岛.
Only the abstract “one input moves multiple characters; walls change their relative
positions” idea is referenced. Characters, rooftop setting, illustration, audio,
12 level footprints, destination arrangements, writing and interface are original.
No third-party game artwork or copied levels are included.

## Play

Run `godot --path godot res://modules/moon_post/main.tscn` from repository root,
or enter 月影邮差 through the island. Start at the title screen.

- Arrow keys / WASD, large direction buttons, or swipe across the rooftop.
- Couriers 1 (gold), 2 (mint), 3 (rose) all move together. They can overlap and
  pass through one another. Walls independently block each courier.
- All couriers must simultaneously occupy their matching numbered envelopes.
  A courier that has arrived still moves on later inputs.
- Star plates open every moon gate while occupied. Movement uses the plate
  state **before** the move; leaving a plate can therefore let someone pass a
  gate in that same move. A closed gate does not crush or trap its occupant:
  they may leave, but no one may enter from outside.
- Z / Backspace: unlimited undo. R: restart. H: help. Escape: pause/back.
- No timer, failures or lives. “一步提示” computes a shortest continuation from
  the current state. An unsolvable state suggests undo/restart rather than
  silently moving a character.
- Progress unlocks the next route. Completed routes remain replayable;
  all 12 routes end with a final farewell screen.

## Isolation and lifecycle

`main.tscn` exposes `signal exit_requested`, `start(context = {})`, `started`,
and idempotent `request_exit()`. Standalone execution auto-starts and exits the
process; hosting emits the exit signal. Input is consumed before that signal,
so a host may detach synchronously. Window close delegates to a supplied
`context.quit_handler` when present. Context fields `game_id`, `save_dir`,
`schema_version` are compatible with the island contract; no context can
redirect this module's fixed private storage namespace.

Only `user://games/moon_post/progress.cfg` stores route unlocks, best moves and
sound preference. Invalid unlock counts are clamped. No host save is touched.
Rules are independent from rendering and storage in `rules.gd`. `levels.json`
contains fixed authored footprints and verified shortest reference solutions;
there is no runtime procedural level generation.

## Verification

From the `godot` directory:

```sh
godot --headless --path . --script res://modules/moon_post/tests/test_moon_post.gd
```

Use an isolated writable `XDG_DATA_HOME` for test saves (Linux), e.g.
`XDG_DATA_HOME=/tmp/moon-post-tests`. The combined suite checks independent BFS
shortest-path proof for every route, reference replay, every move's undo and
redo, exact restart, plate/gate semantics, actual use of gates in later lessons,
scene start/help/pause/swipe/undo/win/unlock/ending/selector/exit flows. Godot
4.7.2 verified; no external test dependencies. Tests intentionally exercise
namespaced save writes in the test data directory.

Shortest route lengths: **3, 5, 7, 9, 10, 12, 10, 12, 14, 16, 18, 20**.
The lower count at route 7 introduces a new rule gently. Routes 7–8 require
crossing the gate-separated rooftop. Later routes use gate shortcuts in their
shortest solutions.

## Runtime assets

The paper rooftops, flowers, lantern plates, envelopes and folded couriers are
rendered as original antialiased vector shapes. Movement eases between tiles;
couriers float and stars twinkle. Gentle short chimes are synthesized locally.
No preview or authoring files are required.

`ui/moon-sans.otf` is a runtime subset of Noto Sans CJK SC Regular from the
installed Noto CJK font, covering the complete runtime text. See
`ui/FONT-LICENSE.txt` (SIL Open Font License). A private module copy is intentional
so the module remains independently extractable.

## Visual QA starting points

Title: run the scene. Gameplay: click “开始送信”. Menu: “邮路”.
Help: H. Pause: Escape. To inspect a later scene programmatically,
`play_level(8)` selects the first three-courier gate lesson.
The view scales and letterboxes from its 1280×800 design canvas.
