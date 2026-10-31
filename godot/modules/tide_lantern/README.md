# 灯塔净潮 / Lantern Tide

Original 5-encounter miniature island tactics game. A lighthouse keeper cleanses tide-nightmares with six lantern relics. Tile Crawl is a **mechanical reference only** (tool wear, exact-strength rewards, environmental tactics); setting, characters, interface, layouts, progression, art and audio here are original.

## Play

Open `main.tscn`, or from the Godot project root:

```sh
godot --path . --scene res://modules/tide_lantern/main.tscn
```

Choose a relic, then tap a tide-pool tile. Mouse hover previews its footprint. Keys **1–6** choose tools; **Z** rewinds once per encounter; **Esc** pauses. All controls also support touch. Narrow/portrait viewports switch to a stacked board + 3×2 relic tray with separate large modal layouts.

- Six relics: powers 1/2/3 single-target, power-1 row, power-2 cross, power-1 column.
- Exact remaining strength refunds one durability and grants one shield (capped at 8). Overkill is permitted without refund.
- Surviving enemies tick once per valid action, attacking at zero then resetting to 3. Each enemy shows strength, attack damage (upper-right), and countdown dots (red when imminent).
- Salt crystals blast adjacent cross tiles and chain into other crystals. Coral heals 3; a navigation lantern grants 3 shield. Empty actions cost nothing.
- Clear all nightmares to advance. Choose healing/max-heart, more relic durability, or stronger crystal chains. Relics refill each encounter.
- Five cleared rooms wins. Zero heart or exhausted relics loses. Retry starts a fresh run. Rewind is available once each room during combat, not after results.

No external runtime dependency. Code-drawn nautical illustration, animated sea/nightmares, impact glow, and short synthesized tones (mute button). Chinese font subset distributed under SIL OFL (see `ui/`). No network requests. No claim of a WeChat port.

## Host contract / persistence

`main.tscn` root exposes `start(context = {})`, `started`, `exit_requested`, and idempotent `request_exit()`. Context accepts the host's `game_id`, `save_root`, `schema_version`, `quit_handler`; persistence deliberately stays at `user://games/tide_lantern/profile.json` regardless of caller path. Host quit handler is invoked for WM close. Standalone autostarts; standalone exit quits. Host input is consumed before exit emission.

Completed-run win count and best exact-hit record persist. Current run, board, relic durability, upgrades, and per-room rewind snapshot auto-save after each action and restore on re-entry. Versioned validation rejects corrupt/inconsistent saves; terminal runs are removed to avoid duplicate awards. UI supports pause/retry/return-to-island. Every run uses five deterministic authored encounters, deliberately forgiving for a short demo.

## Regression tests

Use Godot 4.7.2 (also tested initial scene on 4.6.3). From project root, with a disposable user-data directory:

```sh
XDG_DATA_HOME=/tmp/tide-lantern-tests godot --headless --path . --script res://modules/tide_lantern/tests/test_rules.gd
XDG_DATA_HOME=/tmp/tide-lantern-tests godot --headless --path . --script res://modules/tide_lantern/tests/test_runtime.gd
XDG_DATA_HOME=/tmp/tide-lantern-tests godot --headless --path . --script res://modules/tide_lantern/tests/test_storage.gd
```

Rules tests include full five-room actual-engine greedy completion, exact refunds, chain reactions, pattern boundaries, intent damage, invalid actions, exhaustion, and upgrades. Runtime tests cover onboarding/action/undo/pause/loss/retry/mute/idempotent exit; storage tests cover namespacing and single-result writes. `rules.gd` is deterministic pure state logic independent from scene/UI.
