# Independent Pelican rebuild audit

Scope: newly rebuilt `godot/modules/pelican_pedal`; official Godot 4.7.2 ed1daf0bf. Tests authored independently of production legal_driver and run with isolated XDG directories. No production changes by this auditor. This is not Web/manual visual acceptance.

## Tests

- `independent.gd`: independent raw-box distance collision oracle and BFS road driver; ordinary throttle/steer/brake/interact only. Eight jobs at 30 Hz and 5 Hz. Interaction distance, complete delivery counts, finite dt, speed bound, late state remains playable, malformed snapshots, collision survival/terminal immutability. Latest 34,188 checks pass. Counts differ from initial 33,123 due to legitimate revised southern pickup spawn and routes; tests do not teleport.
- `storage.gd`: 34 checks pass. Bad/future/foreign data preserved; external writer create/change/delete/lock protection, atomic backup and module namespace isolation.
- `lifecycle.gd`: 72 checks. Six real Viewport Enter/mouse home actions with synchronous host detach; focus loss/pause, latest save, quit-policy restoration, WeakRef release and orphan baseline. Initial test setup mistakes (layout timing, mouse coordinate transform, JSON float tolerance) corrected; not filed as production bugs.
- `skin.py`: directly parses GLB buffer accessors. Both rider and first-person rig have 16-joint skin, normalized weights, 77 blended vertices, 15/12 active influence bones, and five genuinely changing animation tracks. This proves actual skinning, not artistic/animation quality.
- `fresh.sh`: copies only Pelican production module (no other game or cached .import), creates minimal project, performs fresh import, then isolated test runs; records SHA-256 source manifest. `run.sh` tests current main project's imported resources.

## Real regressions found

1. `_sync_pedals` accessed Skeleton global transforms after synchronous scene removal. Original failed-run evidence is retained locally (including a corrected floating-point QA assertion). Runtime owner added inside-tree/validity guards; subsequent runs have no transform errors.
2. Pause Home keyboard Enter press reaches host `_unhandled_input` before Button activates on release. Mouse does not. Original assertion was described too broadly as post-detach bubbling; locally retained event-order evidence establishes **pre-exit paused-menu keydown leakage**. Guarding `leave_game` alone does not stop it. Owner fixed module-owned gameplay and paused/unhandled-event consumption. Final fresh retest passes all six keyboard/mouse cycles; no host-press leakage or engine errors.

## Limits

`wm_close.gd` also passed: two close notifications, latest save/players stopped immediately, module-owned delayed shutdown completes with exit 0 and no leaks/errors.

No claim of manual image quality, native GPU rendering, audible mix, exported Web behavior, or physical OS close. Focus notification simulated; home input is delivered via real Viewport InputEvents. Raw collision oracle covers original four buildings/boundary, not all newly added decorative objects. Final fresh source snapshot passed import, 34,188 rule checks, 34 storage checks and 72 lifecycle checks with zero engine errors. Raw logs remain local; source SHA-256 manifest is provided in `evidence/`. A previous fresh run was a genuine failed intermediate run. This is a clean scoped automated audit, not an all-platform release claim.
