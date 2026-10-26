# V5 island shell integration

## Runtime boundaries

- `app/main.tscn` is the project entry; `app/app.gd` owns scene lifecycle only.
- `app/game_registry.gd` owns catalog metadata. Only `gummy_bomber` is enabled; snake, reef memory and cloud hop remain planned and cannot launch.
- `hub/` owns randomized safe portal placement, ray picking, Q cursor, feedback and original SFX.
- `modules/gummy_bomber/` contains all its own scripts, scenes, fonts, art, audio and tests. It does not import island or shell files. Its save data stays in `user://games/gummy_bomber/`.

The shell retains the island instance while playing. Enter suspends hub input, cursor and transient sound; hides island and its CanvasLayer HUD; pauses island audio and processing; launches directly into the module. Exit detaches the game immediately, restores the original camera, HUD visibility, audio pause state, custom cursor and portal layout. The game uses a camera-local environment so its lighting does not conflict with the retained island WorldEnvironment. Child island lights are hidden with the island.

Important ordering: snapshot `AudioStreamPlayer.stream_paused` **before** disabling island processing; Godot otherwise reports automatically paused streams and they would remain silent on return.

## Approved model integration

`docs/active_asset_manifest.json` and `tools/sync_resources.py` explicitly select v3 approved environment, v4 turtle/crab/fish, and v5 gull/tern/dolphin. Model source files remain intact. Turtle scale 1.65→1.15 and crab 1.72→1.20 reduce them ~30%. New gull/tern have independent airborne paths, phases and Fly/Glide clips; dolphin follows an offshore foreground route with its authored vertical fluke deformation. Runtime contains 21 Skeleton3D instances: five main wildlife plus 16 fish. Imported clip length is normalized to source four-second time; no individual mesh-pivot animation or old wing stretching is used.

The existing terrain COLOR_0 linear-to-sRGB runtime adapter and coastline/water contract are preserved.

## Verification

Using Godot 4.7.2 (ed1daf0bf):

```sh
Godot --headless --path godot --script res://tests/check_scene.gd
Godot --headless --path godot --script res://tests/check_app.gd
```

`check_scene` validates six imported models, terrain color adapter, five moving rigged wildlife, 16 moving fish, true bones, reduced scales, water clock, audio loops and camera controls. `check_app` validates 20 enter/exit cycles, disabled and unknown routing, duplicate launch prevention, island/CanvasLayer hiding, music pause/resume, camera and portal persistence, input suspension and zero orphan-node growth.

Sandbox QA sets `XDG_DATA_HOME` and `XDG_CACHE_HOME` to writable `/tmp` directories; normal desktop uses Godot's normal OS user data location.

## Standalone extraction

```sh
python tools/extract_game.py gummy_bomber /new/path/gummy-standalone
Godot --editor --path /new/path/gummy-standalone
```

The destination must not exist. The tool rejects external `res://` script dependencies, copies only the module, excludes generated import caches, and creates an independent project with the same 3D Compatibility renderer and entry scene. It does not copy island assets, catalog or any save data. Keeping the `modules/gummy_bomber/` subdirectory preserves stable resource paths while allowing the whole extracted project to be developed independently.

## Compact themed HUD revision

The island now instantiates `hub/ui/island_hud.gd` instead of its old full-width dark instruction panel. The custom shell mark, small circular view/beach/mute controls and fading hint belong to the hub UI; `island.hud` remains a CanvasLayer for lifecycle/capture compatibility. Signals route reset, beach view, mute and volume to the island; `set_muted()` updates the illustrated icon. The lifecycle suite also tests these signal connections, then repeats all 20 round trips using the new island and game HUDs.

## Final magic-portal integration and scope

The approved magic-rift visual is hosted by `hub/portal.gd`, using `hub/portal_v2/magic_rift.gd` and its authored procedural shaders. The hub has three visible portals: pink Gummy Bomber (open), teal Snake and purple Reef Memory (both visibly unavailable and cannot launch). Cloud Hop remains a fourth catalog-only future idea, not a fourth portal. Catalog and scene routing are separate from the visual component.

This effect is a realtime stylized illusion built from layered double-sided shader surfaces, animated spark sprites and a soft ground shadow—not volumetric fluid simulation. Locked portals retain animation and click feedback but never launch missing content. User reference media is not incorporated in runtime assets. Existing random safe-site selection, drag suppression, hover feedback, sound pooling and return-state retention remain active.

Scope limits: only Gummy Bomber is playable; no level-selection screen and no implemented future games. This is single-player endless-wave play with original candy art, classic grid bomb rules and a direct return-to-island control. Bird and dolphin deformation is authored bone animation with procedural whole-body routes, not animal AI or physical locomotion. Coastline and terrain remain the approved island rather than a larger new terrain; safe portal placement uses its available clear locations. No new features were added during this final integration pass.

Final integration recheck (2026-10-26): scene test `failures=[]`; app lifecycle 20 round trips PASS, including three approved rift colors, only-first-enabled status, and three-layer effect instances. Gummy simulation 24 checks PASS; low-FPS wall-clock runtime PASS; save-schema migration/preservation PASS (the unknown-future-schema warning is intentionally exercised). These automated checks do not replace the parent's final graphical portal/HUD screenshot and click-through verification.

### Portal projection regression

Final graphical QA caught a Godot inheritance trap: `QuadMesh` inherits `PlaneMesh`, so a broad PlaneMesh test mistakenly terrain-conformed the vertical energy layers as well as the ground shadow. The portal wrapper now excludes QuadMesh and matches the exact soft-shadow shader before conforming geometry. App regression checks independently assert three upright energy QuadMeshes (height at least 3.9 world units), 34 intact spark QuadMeshes, and exactly one conformed ArrayMesh shadow per portal. The previously passing lifecycle tests alone were insufficient to validate this visual geometry; final graphical re-render remains required before publication.
