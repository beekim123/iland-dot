# Independent next-games QA — 2026-10-28

These tests were written by the independent reviewer, not copied from module-author tests. Production files were not modified by this reviewer.

## Tested environment

- Engine: `/workspace/scratch/e3e9ec015b32/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`
- Clean standalone project: `/workspace/scratch/e3e9ec015b32/next-games-records/independent/project`
- Both complete module directories copied into this separate project; no host dependency or existing `.godot` cache copied. Headless `--editor --import` performed there.
- XDG data/config/cache all under `/workspace/scratch/e3e9ec015b32/next-games-records/independent/`, never existing user profiles.
- No GUI, Cloud task, publication, or production-code edit performed.

## Results

| Test | Actual result | Qualification |
| --- | --- | --- |
| `test_independent_regressions.gd` | 6 checks PASS after author fixes | Four malformed Dawn nested settings/flags payloads; Yokai same-frame double-click pause; 240 Hz queued mouse press released during pause. Initial failures preserved in external logs. HUD hit list fixture explicitly marked; actual mouse events exercise input. |
| `test_independent_boundaries.gd` | 9 checks PASS | Both future-version profiles remain byte-identical; sibling sentinel unchanged; movement-only at 30/60/120 Hz cannot clear first wave; exactly 12 maximum first-wave spawns. Save payloads are labeled fixtures. |
| `test_independent_host_lifecycle.gd` | 10 checks PASS | Both modules: duplicate start, hosted close-policy preservation, duplicate exit signal once, held input cleanup, removal preserves close policy. This is synthetic host-contract coverage, not actual lobby integration. |
| `test_independent_dawn_route.gd` | Reached ending through 20 sections, 1 death, 578.433 simulated seconds | Rules-layer normal movement/attack/jump/roll/heal/interaction input only, no position/HP/phase/win mutation. Retry uses public retry operation. Default adventure difficulty. Not a real-time GUI/animation/audio acceptance run. |
| `test_independent_yokai_routes.gd` | Independent policy lost wind/quake in wave 5, thunder in wave 6 | 130.23 / 137.53 / 172.89 simulated combat seconds respectively. This is a controller limitation, NOT proof of game defect or successful full-run coverage. No state/HP injections. Five-choice duplicate selection rejection exercised on routes reaching wave 6. |

Audio shutdown requires 0.45 seconds. Initial lifecycle harness waited only 0.3 seconds and therefore produced false exit-count failures; final harness waits 0.6 seconds and all checks pass. Initial regression harness freed active audio directly and leaked two objects; final harness awaits audio shutdown and runs clean. These harness errors were not filed as production bugs.

## Independent findings and fixes

1. Dawn nested save types were accepted despite unsafe consumers (`flags.memories=1`, `settings.keys=1`, `settings.volume=[]`, string completed flag). Author strengthened validation; independent probes now pass.
2. Yokai same-frame double click on pause overwrote `paused_from` with `paused`, making resume impossible. Author made transition guarded/idempotent and invalidated cached hit targets; probe now passes.
3. Yokai sub-tick queued mouse press survived pause, release while paused, resume, causing unheld infinite charge. Author clears model queued edges and accumulator during pause/resume; probe now passes.
4. Dawn unconditionally changed SceneTree close policy on hosted entry. Author restricts interception to standalone startup; both host lifecycle checks now pass.

## Acceptance limits

- Dawn's independent complete route takes **9m38s**, not evidence of its **60–90 minute** first-clear target. Do not claim target-duration acceptance.
- Yokai design currently says **9–12 minute** normal target with 13-minute combat hard cap, not 12–15. Author input-only results around 181 seconds do not establish the target. This reviewer does not claim independent Yokai full clear.
- Dawn has playable tower walk-out (`epilogue`) before ending, not immediate boss-to-ending. The planned separate playable village homecoming and introductory kidnapping staging remain design/content matters; author confirmed current short form. An initial reviewer statement of immediate ending was retracted after checking the full function.
- No real gamepad device, mouse GUI, visual readability, resizing, audio output, performance, or actual host/extractor regression is certified here. Parent owns GUI and integration coverage.

## Reproduction

Copy the complete two module directories to a separate clean Godot project with 1280×800 viewport, then copy these `.gd` files to its root. Run the engine headlessly with `--editor --import`, then `--script res://test_independent_<name>.gd`, with isolated XDG directories. `boundaries` deliberately creates future/corrupt save fixtures: do not run it against real user storage. `yokai_routes` exits 1 for an unsuccessful policy run; do not classify that as a game regression without analysis.

External logs: `regressions.log`, `regressions-retest.log`, `regressions-final.log`, `boundaries.log`, `host-lifecycle-final.log`, `dawn-route.log`, `routes.log` under the independent records directory. Snapshot SHA-256 file stored there as `tested-code-sha256.txt`.
