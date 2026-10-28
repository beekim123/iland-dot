# Rescue instrument interface — focused evidence

Godot **4.7.2.stable.official.ed1daf0bf**, headless, isolated XDG data/config/cache, `ui/test_hud.gd` PASS (2026-10-27). This is **not a native screenshot/visual approval** and not the final whole-game aggregate.

- Actual Viewport `push_input` keyboard: 1280×720, 1024×768, 960×540, 640×360; Esc pause/resume, repeated/echoed Enter suppression, confirmation cancellation and confirmation, duplicate action latch, reset/reentry, success result exit label.
- Pointer: pause hit target and ignored double-click (does not activate newly exposed menu).
- Fixed audio pool six cues + music, 50 simultaneous cue requests per cycle; excess dropped rather than spawning/stopping unbounded playbacks.
- Twelve retirement cycles while tree paused; WeakRef becomes null after frame. Includes 5 FPS frame and explicit WM_CLOSE_REQUEST notification. Immediate idempotent shutdown, no timer requiring the game to resume. Final run no ObjectDB/resource leak log.
- Numerically measured font widths: 354 px introductory safety/control text inside 460 px strip; 208 px confirmation subtitle inside 296 px region. Local Noto Sans CJK SC subset generated from current module GD source and fixed gameplay vocabulary. Original upstream SIL OFL in `OFL.txt`; deterministic extraction source `subset_font.py`.
- Persistent core HUD occupies 29,932 px² at 640×360 = 12.99% (badge + exit chips + pause target). Temporary interaction/help, phase text and up to three time-ordered alerts add contextual space; they are not modal or full-width panels. This measure does not claim combined transient coverage is under 15%.

`preview.tscn` is a static instrument stress-preview for the parent to inspect in the approved GUI. It is not a simulated gameplay completion. Canonical `sim.gd` arrays are duplicated before presentation derivations; no UI writes to gameplay state. Road/shelter/rock ETA comes from authoritative close/expire/impact times, not UI-owned schedules. Airship availability distinguishes calling/arrival from generic window openness.

Integration: instantiate `rescue_hud.gd` Control in CanvasLayer; call `update_snapshot(s)` and `reset()` on new round. Signals `pause_requested(bool)`, `retry_requested`, `home_requested`, `ui_sound(String)` are intent only. `audio/rescue_audio.gd`: `start_music`, `handle_events`, `play_cue`, `set_paused`, `set_muted`, `shutdown` (queues itself for deletion).

Native screenshot `build/previews/volcano-game-first.png` was actually inspected: duplicate minute digits and out-of-badge phase text were found. Revision replaces duplicate digits with clock hands plus full remaining-time ring and encloses phase in the badge. Focused four-size real `push_input` click/Tab regression rerun; updated native screenshot still requires parent inspection.

## Public route chart

`test_route_map.gd` PASS: actual Sim snapshot (12 nodes / 18 roads / 6 shelters / 3 exits), four dimensions, real M inputs including echoed/ten repeated toggles, pause/resume preservation and reset cleanup. Source snapshot serialization unchanged after UI adaptation/drawing. Road and shelter warning/closed/expired overlays exercised. M chart defaults hidden and shows only public authoritative route states, never an optimized route or undisclosed future event. Native chart screenshot remains parent-owned acceptance.

Standalone extraction audit caught a test-only resize assumption: changing Window.size does not change the project's fixed content scale size. Both four-size tests now set `root.content_scale_size` explicitly and pointer coordinates are derived from HUD's logical dimensions/scale; this avoids claiming a window-pixel click as a logical-canvas click. Production input API remains unchanged.

Actually inspected `build/previews/volcano-route-map-native.png`: lower exit names overlapped nodes/legend. Revised chart uses separate left graph, right exit-name/direction column, and bottom legend; exit names remain 12px rather than being shrunk. Warning presentation now says `A站防护失效`, `AB 路段关闭`, and player-distance-based `附近落石 · 5米` / `远处落石 · 30米` (near means ≤12m, a UI proximity description, not a safety claim). Four-size route tests verify both distance cases, absence of `rock_`/`shelter_` text, and unmodified input snapshot. Updated chart still needs native screenshot verification.
