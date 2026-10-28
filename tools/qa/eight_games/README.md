# Eight-game admission staging — provisional

This independent tree starts from the accepted seven-game staging. Its seven
existing modules remain unchanged. Monkey Vine was copied provisionally from
`monkey-vine-development/modules/monkey_vine`; admission remains disabled until
its independent final source freeze is verified and synchronized.

Contract: `monkey_vine`, title 猴子荡荡, 2.5D landscape jungle adventure;
`res://modules/monkey_vine/main.tscn`; `start(context)` and `exit_requested`;
normal module exit is `request_exit()` (not the other modules' `leave_game()`).
The module owns `user://games/monkey_vine/`. A standalone main scene owns process
shutdown; host instances emit exit back to their original source page.

The island still uses four fixed safe portal positions, with no-duplicate
selection from admitted games. Page two contains the underwater snake and
Monkey entries. No layout redesign is part of this increment.

The Monkey cover is the actual first-grab native scene from normal Viewport
keyboard replay, HUD hidden. It is neither reference artwork, human-play
footage nor a performance measurement; exact source SHA is recorded alongside
it. It is directly copied, not retouched.

No eight-game acceptance is claimed until the new module freeze, host/page2/
namespace/portal increment and production-extracted module tests pass. Prior
seven full rules results may only be reused when their exact module source
hashes are unchanged. This is not an all-eight full aggregate.

## Final module pin received

Independent final freeze canonical digest:
`73f802225b1762e5ea410f16bce242e6d422e3f37e2be6523c85f1e398db4d50`.
The developer project manifest has 96 entries: 78 actual module source/resource
files, 17 derived `.import` files and the standalone `project.godot`. All source
entries were verified before copying. The host intentionally keeps its own
project settings and regenerates import metadata, while verifying all 78
module sources exactly. Monkey is now enabled in this staging for admission QA.

Do not execute `tests/test_rules_bonus_search.gd` in a frozen source tree: it is
a witness generator that writes `data/bonus_witness_*.json`, not a read-only test.
The actual bonus-witness regression, route/invariants, rig/presentation and
independent final suites are included instead. Wider timing robustness was not
accepted by the independent auditor; preserve its documented limitations.

The final increment executes module author and independent rule/art suites only
once, inside the real production-extracted project. Host-specific coverage is
the 48-cycle actual-exit lifecycle plus independent page-two/portal/storage UI
checks. This avoids repeating the same new module rules in host and standalone
while still validating both integration paths. Existing seven module rules are
not rerun: their complete 583-file exact-byte baseline is enforced.

## Host input correction after the module-only audit

The independent host probe found Monkey Enter keydown and Escape events reaching
underlying listeners. The original 13-stage module acceptance is therefore not
claimed as acceptance of this corrected host integration. The module owner
changed only `game.gd` and `ui/jungle_hud.gd`: pause/retry keys are consumed before
UI transitions; modal Enter/KPEnter/Space activation is consumed and deduplicated.
The original 96-entry manifest is retained, and the exact two-file delta is
recorded separately in `eight-game-integration-records/input-fix-delta.json`.
Use `monkey-input-fixed-manifest.json` for the new increment. All other 76 source
files are identical. Fresh module author and independent suites run again on
this new pin, together with the strict host no-input-leak probe; its prior
failing evidence remains in the independent host evidence folder.

The final HUD pin is `69d3e5c193694f093b4d50f28e593b778ae5ed492c26242cafb5bb2ef857c18e`:
held confirmation key echoes are also consumed after resuming hides the modal.
Use `monkey-input-final-manifest.json`. The owner's exact four-case real input
regression is copied as `test_monkey_input_consumption.gd` and runs on the fresh
extracted project. The earlier cd17 HUD's successful increment is intermediate
history only, not final delivery evidence.

## Publication boundary

Raw runtime/debug logs are retained locally, not distributed in the repository, regardless of filename extension. Historical exact-evidence reuse modes require the original locally retained evidence; use the included independent/author scripts to perform new runs. A missing historical log is not a passing result. This release preserves the tested runner, not a modified evidence-bypass.
