# Four-door shell and game catalogue integration

2026-10-28, stage functional acceptance evidence; user-approved paged catalogue; not full-project aggregate acceptance.

## Product scope

- Five admitted modules: `gummy_bomber`, `bloom_skirmish`, `tide_gulp`, `beach_cleanup`, `volcano_escape`.
- Rebuilt `pelican_pedal` and planned `fruit_gummy_snake` remain explicitly disabled regardless of whether a directory appears during parallel work. Enabling a new game is a separate final acceptance decision.
- At most four distinct available games occupy four fixed, geometry-checked sites. There are no locked placeholder portals. Fewer than four games yield fewer doors.
- Only the explicit shuffle action changes recommendations. It weights underexposed games more highly and guarantees a new game when there are more than four candidates. Game entry, return, catalogue navigation and application restart preserve the selection.
- Catalogue and shuffle controls do not count as world portals. Game return restores the launch source: same catalogue instance/navigation, or same island camera/layout.
- Shell profile is `user://hub/portal_rotation.json`, never a game profile. Invalid/future profiles are preserved and writes disabled; competing writers or leftover temporary files do not get overwritten.

## Actual checks completed

- Explicit official Godot 4.7.2 `ed1daf0bf`.
- `godot/app/tests/test_portal_rotation.gd`: 3517 checks passed, bounded uniqueness, refresh, small pools, missing-slot repair and invalid numeric/schema data.
- `godot/hub/tests/test_hub.gd`: four real approved magic rifts, correct labels/glyphs, upright energy versus conformed shadow, bounded audio, drag rejection, suspend/resume, unknown/planned metadata rejection.
- `godot/hub/tests/test_portal_layout.gd`: 1944 checks and 660 press/release routes passed over 32 recommendation refreshes. Sites remained fixed while all five available games appeared.
- `godot/tests/check_app.gd`: 30 repeated real scene lifecycles across all five modules plus five catalogue-origin routes passed; camera, audio, HUD, selection and catalogue identity retained, no orphan growth.
- Independent adversarial checks and final aggregate are tracked separately by the independent reviewer/root; these focused passes do not substitute for them.

## Found and fixed during integration

1. The original camera `.38 yaw / .61 pitch` had no non-overlapping four-door layout. Actual imported geometry and real picker found 15 four-door layouts at unchanged yaw `.38`, pitch `.80`, distance `30`. Only default/reset pitch changed; no picker bypass, model, terrain or door resizing. The deterministic first safe layout is `[3,9,44,53]`.
2. Corrupt profile parsing originally used `JSON.parse_string`, which emitted an engine error for expected bad input. Replaced with `JSON.new().parse` return-code checking; bad bytes remain untouched.
3. Native observation found bottom-anchored menu controls off-screen because `position` was set instead of offsets. Corrected offsets at 03:16 UTC; root subsequently confirmed both controls visible in the native window, and actual viewport-input regression passed.

## Limits

- User approved the semi-transparent background, portal-entry visual direction and pagination. Root native recheck confirmed readable names, six entries per page, 1/2 to 2/2 navigation, close/reopen retention, and actual Beach entry / pause / save / return to the same catalogue selection. User explicitly accepted this pagination visual and requested commit/push at 03:40 UTC: “分页可以了，做下提交推送”.
- Portal interiors currently use labelled offline model previews or theme icons, not gameplay screenshots. Native evidence: `build/previews/catalog-portals-page1.png` and `build/native/hub-four-native.log` (local build evidence).
- Independent frozen-source five-suite pass: rotation 27,534; catalogue 103; pagination 120; host 223; paged host 20. Reproduction and source hashes are under `tools/qa/four_portal_hub/`.
- No claim of 30 FPS, Web export, GPU performance or new Pelican/Snake completion.
- First `--quit-after` development smoke force-quit produced audio retirement/leak output; clean lifecycle tests use normal teardown. The force-quit run is not a passing shutdown test.

Additional picker coverage: the original independent real-geometry oracle now
includes the current `.38/.80/30` default plus all five former poses. The route
assertion follows the actual assigned game ID instead of hard-coding Tide, and
sample count is the exact `63 sites × 6 poses × 3 heights` rather than the old
five-pose constant. All 4508 checks / 1134 rays passed, including real occlusion,
conservative animated proxies, empty AABB rejection, and the unchanged 16384
triangle work budget. No hit testing or visibility rule was relaxed.
