# Jungle presentation

Original procedural 2.5D jungle, XY gameplay / +Z view. Authoritative platforms use `rect.end.y` as exact cap top. Real vine `anchor`/`tip` controls eight shared CylinderMesh links; no mesh allocation during frame updates. Decorative trunks/leaves/treehouse remain behind play plane. Broken vines and collected bananas hide from snapshot. Weak vines have both orange material and falling fragments; warning audio comes from rule events.

## Integration
- `art/environment/jungle_environment.gd`: Node3D; `build(snapshot)`, `update_snapshot(snapshot, delta)`.
- `ui/jungle_hud.gd`: CanvasLayer; `update_snapshot`, `set_paused`, `set_hosted`, `show_status`; signals pause/retry/exit/continue_requested, volume_changed. Clear/fail are nonblocking toasts because rules auto-advance/recover. Only pause opens the modal.
- `audio/jungle_audio.gd`: Node; `music_start`, `play_event`, `set_volume`, `set_paused`, `stop_all`.
- Runtime owns camera, lighting and input/simulation; use LINEAR conservative lighting (preview .35 sun, .3 ambient), not high-energy FILMIC.
- Before standalone shutdown stop audio and wait .3+ real seconds to drain. Dummy-driver immediate shutdown can retain pending audio resources.

## Preview and checks
Godot 4.7.2 official binary used. Isolated preview: `art/environment/tests/preview.tscn` (fixture, not witness play).
Automated suite: `--headless --audio-driver Dummy -s res://modules/monkey_vine/ui/tests/presentation_test.gd`.
2026-10-28: PASS stable node count for 180 updates, exact rope tip, warning/hidden geometry, modal mouse shield, dark focus text, 640x360 modal vs warning non-overlap, top-layer warning, nonblocking fail toast, music/cue/volume/pause/stop lifecycle; zero resources leaked with .35 second drain.
WAV checks: 11 PCM mono files; no clipping, max peak .28; music duration 16s, RMS .045, last sample zero. Source generator included. Dummy driver does not constitute listening approval.
Native visual inspection/screenshot and real-input integration remain root/runtime QA responsibilities; these tests do not prove gameplay reachability or visual quality.

## Four-biome presentation pass
`segment % 4` selects fern fans, broad waterfall cliffs, giant golden canopy branches, or mossy broken stone arches. All are background Z < 0, without collisions; no new platform/anchor geometry. Small foliage clusters and biome leaves use MultiMesh. Anchors are visually supported by rear branches, no floating green-disc caps.

Four `tests/preview_{fern_gully,waterfall,canopy,ancient_grove}.tscn` scenes now instantiate real `rules.configure(4242,index).snapshot()` rather than fabricated fixture geometry. All four ran headless Godot 4.7.2 without errors, and the invariant suite passed again. Native screenshot review is still separate. Chinese controls explicitly include Space jump; regenerated local OFL font includes all module strings.
