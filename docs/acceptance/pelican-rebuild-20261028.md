# Pelican rebuild: release acceptance, 2026-10-28

## Delivered scope

Independent first-person 3D pelican bicycle delivery module, skinned rider and bicycle assets, source Blender file and generators, music, save/resume, delivery jobs, pause/retry/exit and host integration. Six admitted games now participate in the four-door pool. Fruit Gummy Snake remains disabled and is not included in this release.

## Frozen automated acceptance

Official Godot 4.7.2 ed1daf0bf: the final six-module aggregate completed all **147 steps**, with **703 included inputs unchanged** before/after (04:10:11–04:26:57 UTC). All six games ran available author tests, host/catalog lifecycle tests, and fresh production-extractor projects. Available independent Gummy/Bloom/Tide/Pelican suites also passed. Beach/Volcano historical independent suites were not recovered: their fresh author coverage is not represented as independent coverage.

Pelican independent rules: 34,188 checks; storage: 34; lifecycle: 72. Author coverage includes eight legal routes, edges 907, world 12,994, input 8, runtime 36, storage 33, rig/skin assets, and actual standalone pause/result menu termination. Reproduce with `tools/test_all.sh`; scoped scripts live under `tools/qa/pelican_rebuild/` and module tests.

## Root native verification

Actual keyboard riding/braking/interact completed the first two-stop delivery: 100% cargo condition, zero collisions, 84 m and 450 points. The 619-second elapsed time includes inspection and reopening, not a speed benchmark. Starting a second job and quitting/reopening restored delivery state. Cargo parcels were visibly rendered after pickup; standalone menu exit closed the process normally.

The refreshed seaside scene was reviewed again at 04:09–04:10: shop windows, arches, flower boxes and animal passersby visible; road normals correct, no white exposure washout, and parcels visible. At 04:11–04:13 root entered Pelican through the actual host catalogue, paused, and used keyboard return; the app stayed running and restored the same catalogue selection. No script/engine errors were observed; only the existing driver VSync warning. Screenshot was shared with the user. This is root native verification, not final user art approval.

## Historical failures, retained rather than hidden

Earlier stages failed on overexposure, missing font glyphs, downward road/ground normals, off-tree skeleton transforms, paused Enter leaking to the host, and standalone home leaving a stopped scene. These were fixed and retested. An initial aggregate runner lacked a legacy report directory; the corrected runner restarted the complete aggregate and passed. No failed intermediate run is counted as acceptance.

Raw historical/debug logs remain local and are deliberately not published. The repository provides reproduction scripts, source fingerprints and this result summary instead. Native historical screenshots are labelled by their filenames and do not substitute for the refreshed scene verification.

## Limits

Animal passersby currently move static meshes along routes; they do not have skeletal walk cycles. No Web/GPU-performance/audible-mix or final user art acceptance claim. The frozen run included two non-executable log evidence files; these are excluded from the published tree for data minimization, along with all other raw logs. Executable production/test bytes remain identical; release documentation-only updates are recorded separately.
