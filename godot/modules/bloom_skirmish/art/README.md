# Bloom cartoon animal art and real skinning

The current cast is **otter, rabbit, fox and raccoon**, each with blue/orange equipment variants and unchanged natural fur colors. These are original cartoon animals with species-specific muzzles, ears, paws, body proportions and tails—not the rejected human body with an animal head. The previous human GLBs and human `.blend` files are retained only in the local production archive and are **not included in this publication**; the factory never falls back to them and animal reproduction does not need them. `source/build_athlete.py` is retained because animal builders import its generic geometry helpers, never its human build entry point. Explicitly re-running that legacy entry point creates local historical outputs, not runtime animal models.

**Current scope:** real animal skin/animation integration. This is not a claim that the full sunlit-greenhouse environment redesign, visual acceptance or Web performance testing is complete. The existing procedural arena remains staging geometry; environment expansion is paused. Original audio is unchanged.

## Assets and reproducible source

- Obsolete unskinned `models/animals/<species>/*.glb` exports are no longer tracked. Species builders can regenerate them locally; current runtime and previews use only rigged exports. Git commit `7b16265` preserves the historical binaries.
- `source/animals/<species>/`: original Blender generation script, compressed editable `.blend`, validation/provenance reports. Inspection PNGs/contact sheets are local generated evidence, excluded from Git; the retained render scripts reproduce them. Each species README documents its exact reproduction command.
- `source/animals/rigging/build_rigs.py`: non-destructive rigging stage that reads those frozen `.blend` files, bakes the approved short-paw holding pose, builds a real Armature, assigns vertex weights and exports bone animations.
- `models/animals/rigged/<species>/<species>_{blue,orange}_rigged.glb`: runtime skinned scenes. Each has a real Skeleton3D/Skin after Godot import, multibone vertex weights, bone animation clips and an independent articulated sprayer.
- `source/animals/rigging/<species>/`: editable rigged `.blend`, source hashes, deformation/pose reports. Rigging does not overwrite the modeling source.
- `source/.gdignore`: prevents Godot from auto-launching Blender. Runtime requires only the self-contained GLBs, not Blender or image textures.

Reproduce the second stage with Blender 4.3.2, from repository root:

```sh
for species in otter rabbit fox raccoon; do
  blender -b --python godot/modules/bloom_skirmish/art/source/animals/rigging/build_rigs.py -- \
    --species "$species" --team both
done
Godot --headless --editor --path godot --import --quit
Godot --headless --path godot --script modules/bloom_skirmish/art/validate_art.gd
Godot --headless --path godot --script modules/bloom_skirmish/art/measure_art.gd
```

Use the verified Godot **4.7.2** executable and writable XDG directories. Import once after model generation has finished; do not race editor import against exports. `.godot/` import caches and `.blend1` backups are not source deliverables.

## Runtime API and hierarchy

```gdscript
var actor = Art.make_animal("otter", team, actor_id) # real skin required; no fallback
Art.animate_gardener(actor, game_time, normalized_speed, shooting, dash)
Art.apply_gardener_aim_pitch(actor, pitch)
Art.react_gardener(actor, "hit") # pod, respawn, victory, defeat, clear/reset
```

`make_gardener` remains a compatibility entry point, but also returns only an animal skin. Runtime explicitly assigns id 0 otter, id 1 rabbit, id 2 fox and id 3 raccoon; species and team are independent. The retired unskinned factory mode has been removed.

The factory preserves imported skeleton/animation paths. `skeleton` and `animation_player` metadata reference the actual instance nodes; `skinned=true`, `asset_path`, `animation_clip` and `last_evaluated_time` expose auditable state. There are no fake rigid Body/Arm rotations on the skin path. Required bone clips are `idle`, `run`, `spray`, `dash`, `hit`, `pod`, `respawn`, `celebration`, `defeat`. Moving-and-shooting uses the real run clip (holding paw already constrained) plus front-nozzle recoil; stationary shooting uses `spray`.

The AnimationPlayer uses **manual callback mode**, evaluated by `seek(..., true)` from simulation-supplied time. Locomotion phase advances from a separate `last_evaluated_time`, never event-writable `animation_clock`; changing movement speed therefore does not multiply a large elapsed time into phase jumps. Run playback scales with normalized movement speed, up to 2.6× at full speed; this is coordinated with the short-contact scurry clip rather than an arbitrary fast loop. Repeated evaluation at identical time preserves the pose. Pausing must skip both animate and aim. Events use the current `animation_clock`; respawn replaces a previous defeat/hit with its own recovery clip, and clear/reset removes reactions. Results may advance a separate visual clock without changing simulation time.

## Physical nozzle and short-paw grip

Godot is Y-up, -Z forward; sole plane is Y=0. Runtime scale is 1.3 and actor root Y=0.04.

- Public root `Weapon` position: **(0.31, 0.60923076923, -0.29)**.
- `Weapon/Muzzle`: **(0, 0.04, -0.51)**, a separate fixed physical anchor.
- Resulting world-relative physical origin: **(0.403, 0.884, -1.04)**, unchanged from simulation.
- `Weapon/GunGrip`: actual short-paw holding point, species-specific and stationary.
- `Weapon/AimNozzle`: a compact front ball-joint nozzle centered on Muzzle. Only this front part pitches/recoils; the main receiver and rear/top U-grip stay in the animal's reach. The head follows 25% of pitch from a cached freshly sampled bone pose, without accumulating rotations or moving the chest/holding arm.

Rotating the entire long sprayer around the fixed muzzle would move its rear grip outside a short animal arm's reach at steep angles. The approved solution is the articulated nozzle—not hidden limb stretching, shoulder relocation to the waist, loss of aim pitch or physics changes. Validation checks actual imported node transforms at both pitch limits and multiple motion states.

## Material pipeline and the fox import diagnosis

Runtime rigged animals use authored PBR materials. The rigging stage converts the fox's original linear vertex palette to equivalent linear PBR base colors and removes `COLOR_0`; **no gamma conversion is applied to rigged fox**.

The historical unskinned fox used linear `COLOR_0` and needed a Compatibility-only gamma workaround. Those obsolete exports and their preview-only conversion branch are removed. `source/animals/rigging/fox/original_palette_baseline.json` retains both original GLB SHA-256 hashes and their area-weighted linear-color histograms; independent `skin_palette.py` compares current rigged faces against this fixed original baseline with unchanged thresholds. It must not be regenerated from the current rig. Original fox `.blend` sources and `validate_palette.py` still support independent face-by-face source-to-rigged validation.

## Native previews and validation limits

```sh
Godot --path godot res://modules/bloom_skirmish/art/preview.tscn -- \
  --bloom-animal=otter --bloom-skinned --bloom-action=run \
  --bloom-art-shot --bloom-art-output=/absolute/path/new-unique-image.png
```

Allowed species are rabbit/fox/otter/raccoon; preview actions idle/run/spray/dash. `--bloom-skinned` is now an optional compatibility flag; previews always inspect current rigged assets. The preview shows three true Godot views on a mineral/graphite platform, with orthogonal directional shadows; it is not a gameplay screenshot. Use new image filenames for each milestone, never overwrite previously delivered evidence.

`validate_art.gd` checks all 8 real-skin combinations, 9 clips, actual bone motion, finite geometry/normals/UVs/weights, physical muzzle, nozzle/hand separation and deterministic pause sampling. `measure_art.gd` records actual imported counts and runtime hashes in `art_manifest.json`; read that file for current measurements rather than historical human counts. The independent gameplay QA suite additionally verifies CPU skin deformation, lifecycle and gameplay integration. Neither a source triangle count nor passing structural tests alone proves Web frame rate, subjective aesthetics, or user acceptance.

## Provenance

Animal design, geometry, material palette, rigging and animations were authored specifically for this project. No downloaded model, third-party character kit, copied game character, external image texture or trademarked character is included. Original project assets and source may be used, modified and redistributed with the enclosing project. Existing audio/source/license records remain separate and unchanged.
