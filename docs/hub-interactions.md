# Island hub interactions

## Approved floating rift (final integration)

`portal.gd` is now a metadata/label adapter around `portal_v2/magic_rift.gd`. The old solid ring, disk and pedestal are removed. The approved shader effect is unchanged: layered double-sided energy planes, drifting particles and a soft shadow only. It is not volumetric fog. Palette: pink `ff439c`, teal `23dcca`, purple `9864ff`; locked instances darken their tint by 12%. Titles appear on hover; locked portals otherwise show only a small 未开放 label. The ray envelope is 2.10 m wide, 3.30 m tall, from local y=0.25 m.

Site elevations now use center terrain height + 0.012 m. A 9×5 terrain-height patch conforms the shadow receiver while retaining its approved shader/UVs; no ground circle is introduced. Energy appearance and capture prototype shaders are unmodified.


## Integration

```gdscript
var hub = load("res://hub/hub_interactions.gd").new()
add_child(hub)
hub.setup(self, camera, registry)
hub.portal_requested.connect(router.enter_game)
```

`registry.list_games()` returns dictionaries containing `id`, `title`, `enabled`, and `color` (Color or HTML string). Array entries and `{games: [...]}` also work. Only implemented `gummy_bomber` and `bloom_skirmish` can emit an entry request. The second teal portal is Bloom Skirmish; the retired `snake` ID is not an alias. The first three entries receive portals; planned entries display **未开放** and cannot enter. The component never changes source meshes, bone poses, wildlife paths or materials. Hover uses a separate glowing pearl; click feedback uses eight transient sparkles.

## Placement

`portal_sites.json` is generated from the approved v3 pure-Python terrain API, not guessed screen coordinates. It contains 63 certified points: grass mask > 0.8, shoreline distance > 2 m, vegetation/animal placement origin distance > 1.35 m, and 1.2 m sample footprint height variation < 0.55 m. A terrain-conformed soft-shadow receiver follows the slope without changing the island mesh. This is trunk/origin clearance, not a guarantee of no high canopy overlap. Three portal origins require 2.15 m mutual separation. Sites are shuffled by a local RandomNumberGenerator; set `session_seed` before setup for reproducible QA. Retaining the island instance retains its layout across game returns; a fresh instance/new session gets a fresh seed.

## Picking / input

Meshes are picked by local AABB ray intersections; moving root transforms are evaluated every time. For skinned animals this is the imported bind mesh envelope, not a physics collision mesh. Terrain, foam, ocean and sky are excluded. The nearest eligible mesh or portal is selected; normal decor and animals stay clickable without putting PhysicsBodies inside their rigs. New meshes are discovered every 3 s.

Input uses `_unhandled_input` so GUI controls consume clicks first. Left mouse movement over 7 px rejects a click even when the pointer returns to the original location. Orbit drag and wheel events are not consumed. Hover pauses over GUI controls. Cursor is a self-authored SVG rendered in memory; unload restores the system default.

## Audio / lifecycle

Five original mono 22.05 kHz WAV effects (click, portal, bird, plant, water) use no samples or outside assets. Eight AudioStreamPlayer voices are reused; excess simultaneous requests drop rather than allocate. All route through Master at -16 dB, respecting island mute. Sparks expire after 0.65 s and are rate limited to 90 ms. Audio stops and references clear on exit. UI font is a small Noto Sans CJK subset, under the same OFL license as `resources/fonts/OFL.txt`. The existing font face is retained; only the four Bloom Skirmish title glyphs were added. Reproduce with `python3 godot/hub/tools/subset_font.py`; provenance and the explicit codepoint list are stored alongside it.

## Reproduction / tests

```sh
XDG_DATA_HOME=/tmp/hub-test-data XDG_CACHE_HOME=/tmp/hub-cache \
  Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
  --script res://hub/tests/test_hub.gd
```

Test asserts three portals, both candy and bloom entry IDs, the second portal’s teal tint, mesh registration, enabled/locked routing, no return-to-origin drag activation, portal ray picking, bounded voice pool, and teardown. Headless tests do not establish visual or subjective audio quality; runtime screenshots and click/orbit interaction QA remain required at integration.

Regenerate sites and the five original synth files with `python godot/hub/tools/generate_assets.py`. A separate 10,000 shuffled-layout placement check found no layout with fewer than three mutually separated sites. Audio teardown test waits 0.2 s after freeing the scene so the audio server can release queued playback resources; final run exits without leaked-resource warnings.

## Mini-game handoff

Call `hub.suspend()` **before** hiding/disabling the island and `hub.resume()` **after** showing/enabling it. Both are idempotent. Suspend clears held press, drag, hover, temporary effects and source-island orbit drag; stops all SFX; hides the hub and any visible owned CanvasLayers; disables hub processing/input; restores the system cursor. Resume restores the previous hub/layer visibility and Q cursor without replaying sound or stale clicks. Current portal captions are Label3D, not CanvasLayer. The tests additionally assert suspended entry rejection, stopped voices, state reset, repeated-call safety and successful entry after resume.

### Shadow receiver regression guard

Godot `QuadMesh` derives from `PlaneMesh`: a broad `mesh is PlaneMesh` test also matches every energy/spark quad. Shadow draping therefore explicitly excludes `QuadMesh` and requires the exact `soft_shadow.gdshader` resource path. The regression test asserts each configured portal still has three energy `QuadMesh` surfaces with height ≥ 3.9 m and exactly one terrain-conformed shadow `ArrayMesh`. This protects against accidental flattening of the approved upright effect.
