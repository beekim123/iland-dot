# Independent Monkey Vine audit

Run from any directory with `python tools/qa/monkey_vine/run_audit.py` (path relative to project).
The runner creates an isolated temporary project, fresh-imports using the official
Godot 4.7.2 binary, isolates XDG data for every suite, hashes copied source, checks
process status AND engine error text. It never imports into the shared editor cache.

## Latest verified batch

2026-10-28 04:59 UTC, evidence `evidence/20261028-045933/`.
Ten stages PASS, no script/engine error lines:
- fresh import;
- rules: 129,861 assertions, 36 ordinary-control routes, 3 seeds × 4 templates ×
  release thresholds .55/.65/.75 m; true grab radius, no teleport, constraint,
  speed cap, platform penetration, 240/120/60 Hz and large-delta time accounting;
- boundaries/seams: 90 assertions, explicit isolated artificial fixtures for
  four-direction swept solid collision, fixed/moving/fragile vine release,
  cooldown/held behavior, full break warning. Separately three normal stages
  completed using ordinary controls, never setting player state;
- storage: 27 assertions, corrupt/future bytes protected, canonical namespace,
  invalid namespace refusal, concurrent/stale and newly-created-file protection;
- runtime: 15 assertions using actual `Viewport.push_input`, same-frame Space
  tap, pause/focus/input clearing, large-delta backlog, Space activates Resume
  without a jump, actual focused Enter host-return button, synchronous detach and release;
- viewport route: 70 assertions, actual key events traverse three stages with
  18 distinct vine catches. `_process` advances controlled elapsed time; this is
  actual input dispatch but NOT real-time native performance measurement;
- rig: 49 assertions, actual Skin and bone weights, articulated skeleton,
  seven clips, animated bone transforms, grip error < .001 m including mirror,
  detached callback safety, 10,268 nondegenerate triangles with clockwise winding;
- UI layout: 30 assertions across actual logical 640×360 / 1280×720 / 1920×1080
  viewports, buttons/modal/warnings inside bounds, warning outside modal, wind arrows;
- actual standalone process exits by its own request_exit and WM close paths.

Source hashes identify tested executable/art state. Later changed files are not
implicitly covered. Logs are evidence, not substitutes for a native screenshot.

## Failures found and resolved

1. Release .10 m before the original witness caused the character to land before
   a narrow terminal trigger, then jump past it. Fixed by the rules owner using
   a wider safe ground-only exit; unchanged independent controller now passes.
2. Nine acute tube triangles disagreed with outward vertex normals. Character
   owner corrected local normals/geometry (not disabled culling). Fresh import
   has zero inversions, and shortened feet align with collision radius .32 m.

An early copied project was tested without importing its GLB; that run produced
missing resource errors and is explicitly invalid, not included as a pass.
An early no-HUD input suite is superseded by the latest full-component suite.

## Limits / pending evidence

- Headless only: no claim of native aesthetics, audio listening, Web export,
  mobile/touch support, or GPU/performance certification.
- Seeds currently do not change authoritative geometry; seed diversity does not
  imply randomized level coverage. Four fixed templates are what was tested.
- Optional moving/fragile high route is covered by labelled boundary fixtures,
  not demonstrated by an ordinary-player optional-collectible route.
- Wind force snapshot and direction UI are verified in the final batch; optional
  strong-wind challenges have not been implemented or playability-certified.

## Supplemental human release-spacing audit (05:02 UTC)

The original witness releases Space for only one 8.33 ms physics tick. Its passing
results must NOT be presented as proof of human key-up timing tolerance.
`audit_human_release.gd` separately explores 80/120/180 ms minimum Space-up
intervals, rounded UP to 83.33/125/183.33 ms, with .55/.65/.75 m release offsets,
3 seeds and all 4 templates. No physics/player state is altered. Baseline and
prepare-for-landing ordinary-key policies were both tested (216 route attempts).

| Space-up minimum | offset .55 | offset .65 | offset .75 |
|---|---:|---:|---:|
| 83.33 ms | 12/12 | 12/12 | 0/12 |
| 125 ms | 12/12 | 12/12 | 0/12 |
| 183.33 ms | 12/12 | 0/12 | 0/12 |

Both policies have the same outcome; 96/216 attempted parameter combinations
failed. This exploration intentionally exits nonzero and retains all failures.
80/120 ms successes use all six vines. The 180 ms .55 route legitimately skips
one vine (five catches), not a six-vine witness. These are real difficulty
boundaries, not evidence that arbitrary human timing works.

`audit_human_viewport.gd` additionally feeds real Viewport key events with
125 ms minimum Space-up intervals and .55 release offset: **three continuous
stages, 18 vine catches, 60 checks PASS**, no engine errors. Controlled elapsed
simulation is still not a physical keyboard/native human playtest.

Evidence: `evidence/20261028-human-release/`. It extends the exact production
hashes of `20261028-045933`, without changing the earlier 10-stage result or
pretending the exploratory failures are passes.

## Final frozen-source verification (2026-10-28 05:21 UTC)

Supersedes prior production snapshots. Thirteen fresh isolated stages PASS,
including independent normal-input optional moving/golden and fragile routes,
125 ms real-Viewport three-stage route, four biome rebuilds/node stability,
actual Chinese help/font, wind cues, storage and both standalone exit paths.
The optional geometry changes fragile anchor X from 21 to 21.5 only; no state
teleport is used to reach it. Bonus input edges are verified and each airborne
key-up interval is at least 10 ticks (83.33 ms). Fragile warning remains visible
47 ticks before voluntary release, followed by grounded exit completion.

Broad human timing exploration was rerun separately: **216 attempts, 96 failures**,
identical matrix to the earlier supplementary audit. This is NOT a claim that
all optional timings or all human input patterns pass. Optional 7-tick timing
windows are author evidence, not independently re-searched in this final batch.

Canonical source digest (SHA256 of sorted compact JSON mapping the 96 production
paths to their SHA256 hashes):
`73f802225b1762e5ea410f16bce242e6d422e3f37e2be6523c85f1e398db4d50`.
Final GLB:
`a3b0eccefd3523b24269f649d514929dc7c417f84927bfd428834cc1839e418a`.
Production source recheck: zero mismatches after the full run.

Summary/manifests: `evidence/20261028-final-freeze/`; raw final logs remain local
in `/tmp/monkey-independent-final-qefqd1sh`, not forwarded externally.
Actual source Chinese characters were independently checked against the font
cmap with no missing CJK glyphs. An initial synthetic font probe incorrectly
included the unused word “未来”; its missing unused glyph was a test-fixture
error, corrected to probe actual UI text (not a production-font fix).
Native captured replay belongs to the root's evidence and still does not prove
human continuous keyboard completion. No Web/performance/audio listening claim.
