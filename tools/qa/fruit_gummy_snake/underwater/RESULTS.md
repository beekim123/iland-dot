# Underwater XYZ independent audit — final revised freeze PASS

**2026-10-28 04:27 UTC.** Current tested rules include true continuous XYZ swimming, S slow speed **1.7 m/s**, normal 3.9/W 4.6 m/s, the one-time introductory apple, final “target fruit” HUD/font and repaired long-body camera. This is not a reuse of historical planar or earlier-speed test results.

Official Godot **4.7.2 `ed1daf0bf`**. Sources copied into independent projects with isolated XDG storage. Runtime resources freshly imported. Both suite source SHA-256 comparisons matched before/after; no parse/script errors or leaked resources logged.

## Final results

| Independent suite | Checks | Result |
|---|---:|---|
| Introductory apple | 680 | PASS: 40 normal seeds, unique legal intro slot, ordinary forward contact scores/grows, no repeated intro on refill |
| Kinematics | 8,582 | PASS: real XYZ movement, arc spacing, speed HUD/actual displacement, 30/60/144/3/1 FPS consistency, volumetric food |
| Normal navigation | 9,372,432 | PASS: ordinary public controls, score ledger, growth spacing, bounded trail memory, three full victories, terminal immutability |
| Real-contact frame replay | 7,900 | PASS: ten actual fruit contacts; identical controls at 30 FPS / 120 Hz yield same body/head/food RNG/score/events |
| Explicit collision fixtures | 17 | PASS: XYZ contact versus depth-separated crossing, near-neck boundary, segment distances and world walls |
| Independent storage | 80 | PASS: underwater schema 2, old planar/six other module sentinels preserved, malformed/future/concurrent/lock cases |
| Real Viewport input/lifecycle | 86 | PASS: XYZ controls, S press actual .85 m in .5 s, S release restores 3.9; countdown/pause/focus/retry/exit; four sizes |
| Long-body camera route | 312,512 | PASS: ordinary 94-fruit route to 120 segments, camera outside body and head sightline clear |

Also passed standalone close/audio retirement, actual CLI preview + focus loss without recording a round, and **intro target priority**: normal seed 69 contains a nearer random fruit, yet HUD targets intro first; after actual contact it returns to nearest remaining fruit.

### Ordinary navigation outcomes

No head/body/food/score state was forced. The test controller chooses targets and uses only public `set_controls` / `tick` with bounded yaw/pitch and body avoidance.

| Seed | Fruit contacts | Score | Segments | Simulated seconds | Outcome |
|---:|---:|---:|---:|---:|---|
| 271 | 88 | 1,976 | 120 | 1,454.400 | Victory |
| 867 | 30 | 571 | 45 | 1,500.000 | Alive at observation limit; **not claimed as a victory** |
| 1909 | 94 | 2,035 | 120 | 1,273.783 | Victory; also complete long-camera route |
| 421 | 89 | 1,883 | 120 | 1,080.908 | Victory |

## Defects independently found and repaired

1. **Growth snapshot mismatch:** collecting fruit changed declared length one tick before body samples. Normal navigation caught 63 mismatched contacts. Author resamples after consumption; subsequent complete navigation passes.
2. **Long-body head occlusion:** ordinary seed 1909 previously reached 78 segments / 358.533 s where all four shoulder positions were blocked, but runtime selected an unsafe final candidate. Full camera/body snapshot is preserved in `evidence/camera_failure.json`, with failing log. Author added a broader safe-position search and adjusted look direction. Subsequent full 120-segment camera runs pass, including the final changed-speed/intro route.

## Evidence and reproducibility

- Pure suites: `/tmp/xyz-independent-sim.wbAaZW`; archived `evidence/intro_final/sim/`.
- Fresh runtime: `/tmp/xyz-runtime-independent.qg1eGT`; archived `evidence/intro_final/runtime/`.
- Supplemental intro-target test ran against that same isolated imported source. Its normal seed-69 result is `intro_target.txt`.
- Commands: `bash tools/qa/fruit_gummy_snake/underwater/run_sim.sh` and `bash tools/qa/fruit_gummy_snake/underwater/run_runtime.sh`.
- Earlier `evidence/final/`, `evidence/slow_final/` and the parent directory’s planar results are **historical**, not substitutes for this revision.

Collision tangency/world-edge tests are explicitly manufactured fixtures; normal navigation and target tests are not. Runtime precise-delta tests disable automatic processing and call `_process` at stated deltas, while controls use actual `Viewport.push_input`. Focus notifications are explicit. No private input handler is used to simulate real keyboard/mouse input.

## Scope limits

Headless geometry and controls do not establish native visual quality, depth readability, GPU performance or Web-export compatibility. Those remain root-review gates. This auditor changed no production files and performed no push.

### Post-test documentation-only update

At 04:28 UTC an independent full-module manifest comparison found exactly one post-test change: `QA.md`, from `68f8b8c550f309a0d873e91894b6ef70735af2dc214d4f201ac4d7950a6e0531` to `ffdda809352f4fde63068a92d0c707620e3a7376d1c7486ab9eaa4bcb01983e4`. Production scripts, tests, art, fonts and audio remain byte-identical to the passed runtime snapshot. The post-documentation manifest is archived with the final runtime evidence.
