# Underwater XYZ independent audit — prior freeze passed; low-speed revision pending

> At 04:08 UTC the root requested S slow swimming change from 3.2 to 1.7 m/s. Results below apply to the previous frozen speed model only until the revised full suite completes. New acceptance is in progress.

This is a new 3D audit. Historical planar results are not used as proof of XYZ gameplay. Official Godot 4.7.2 `ed1daf0bf`; isolated project/XDG.

## Current demonstrated results

- Kinematics: 8,576 checks pass. Ordinary controls displace all XYZ axes; body arc-length spacing; 30/60/144/3/1 FPS produce equal path/elapsed/outcomes. 100 seeded food layouts occupy meaningful vertical range and clear body/other fruit.
- Normal navigation: 2,422,883 checks pass, including explicit victory, terminal immutability and bounded arc-history assertions. All movement uses only public `set_controls` and `tick`, no head/body/food rewrites. Steering uses target selection, bounded pitch/yaw, and body avoidance. Seed 1909: **91 fruit, 1,828 points, 120 segments, victory at 582.7 s**. Seed 421: **90 fruit, 1,788 points, 120 segments, victory at 569.175 s**. Seeds 271/867 reached 21/11 contacts then correctly ended at boundaries. Navigation collects both above and below initial depth; score event ledger and growing-body spacing checked throughout.
- Growth replay: 4,504 checks pass. Ten real fruit contacts replay identical timestamped control values at 30 FPS versus 120 Hz; body, head, score, food RNG and events match.
- Explicit collision fixtures: 17 checks pass. True XYZ contact versus safe projected crossing at separated depths, near-neck exclusion boundary, analytic segment distance checks, and 3D world limits. These are marked fixtures, not normal navigation evidence.
- Storage: 80 checks pass, schema 2 in `underwater_v2`, old planar profile and six other module sentinel files untouched; corruption, future schema, concurrent create/delete and lock behavior preserved.
- Runtime: 74 checks pass in fresh imported project. Real Viewport D+Space+W press/release, actual XYZ movement and C descent, countdown pause, focus, restart, four viewport sizes, warning layering and host synchronous detach. Independent scene closing and actual CLI preview/focus-loss/no-score flow also pass.

## Defect found and repaired

Fruit collection previously changed declared length before updating public body positions. Independent normal navigation caught all 63 contacts exposing a one-tick body-length mismatch. Author moved sampling after consumption; rerun passed. Before-fix log retained.

- Long-body camera audit found a second defect on an ordinary route at seed 1909, 358.533 s, 78 segments: all four candidates were obstructed but runtime selected the last one anyway. Two body segments obscured the head sightline. Saved complete geometry in `evidence/camera_failure.json`; author replaced four-candidate fallback with a larger safe-position search. Independent rerun follows the same ordinary 91-fruit route all the way to 120 segments: **141,758 camera checks pass**, including the former failure point. This geometric test does not replace native visual review.

## Final evidence and remaining visual scope

Five pure simulation/storage suites passed at `/tmp/xyz-independent-sim.0oU75L`. Fresh standalone resource import and four runtime suites passed at `/tmp/xyz-runtime-independent.YaYB3L`. Exact logs and before/after SHA-256 manifests are archived under `evidence/final/sim/` and `evidence/final/runtime/`. Both source comparisons matched. No script errors, parse failures or leaked resources were logged. Runtime source includes the curved initial trail, final art at time of testing and the repaired camera search.

Native depth readability, graphics quality/GPU and Web exports are not proven by these headless tests and remain root-review scope. No production files were changed by this auditor; no push was performed.

### Post-test documentation-only change

At 04:04 UTC, owner appended final validation notes to module `QA.md`. Independent manifest comparison confirmed **only `QA.md` changed**, from SHA-256 `ef1e4d5367ba8514a01b34534dd389de5fc127d3d8252f41e7225b95ae1438e6` to `68f8b8c550f309a0d873e91894b6ef70735af2dc214d4f201ac4d7950a6e0531`. All production scripts, tests, font, audio and art remain byte-identical to the tested snapshot. Post-documentation manifest is retained alongside the frozen manifests.
