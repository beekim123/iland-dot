# Animal models — v3 approved Q-style modeling pass

## Deliverables

- `art/v3/animals_preview.png`: actual Blender Cycles CPU render, **1280 × 960, 48 samples**, denoising off. Inspected after rendering.
- `art/v3/animals.blend`: reproducible source with four editable, subdivided custom-mesh animals and a separate `STUDIO_ONLY` collection.
- `art/v3/turtle.glb`, `crab.glb`, `seagull.glb`, `fish.glb`: independent character hierarchies; no studio camera, floor or lights.
- `art/v3/build_animals.py`: self-contained build, no add-ons, external textures or old-model dependencies.
- `art/v3/animals_metrics.json`: dimensions, mesh/vertex counts and pivot names.
- `art/v3/animals_validation.json`: checked GLB structure, hierarchy, hashes and explicit rig/animation status.
- `animals_preview_first.png` and `animals_preview_pass2.png` retain the visual review trail. Use `animals_preview.png` as the final image.

## Approved direction and changes

The user approved the animal design shown in the first actual v3 preview. Subsequent work preserves that design and its proportions: **Q版, soft clay-like surfaces, oversized friendly eyes, compact stylized bodies**, not a realistic wildlife redesign.

- **Turtle:** continuous shaped head/neck, domed single carapace, fitted low-relief scute seams instead of separate flat tiles, tapering curved flippers attached at their shoulders.
- **Crab:** continuous rounded carapace, eight tapered bent walking legs, opposing hooked pincers with actual open gaps, integrated tapered eyestalks.
- **Gull:** continuous head/neck/pear body rather than stacked spheres; tapered wedge beak; folded gray-blue wing with layered feather silhouette; modeled webbed feet.
- **Fish:** smooth tapered spindle, body bands integrated into the body surface through face materials rather than raised white slabs, thickened ribbon fins and split fan tail.

Only technical fixes followed approval: shell seam fitting/interpolation and width, wing cross-section orientation, outward normals, small palette/exposure adjustment, and stable pivot names. No new head/body proportion redesign was applied.

## Asset contract

Blender coordinates: **+Z up, −Y forward**, meters. GLB export uses standard glTF Y-up conversion. Land-animal exported roots have identity transforms and ground contact at local Z=0; fish uses its body center. The `.blend` is staged for the studio screenshot; clear each species root's studio location/rotation before positioning it in another scene, or import its isolated GLB.

| Character | Root | Blender dimensions X × Y × Z (m) |
|---|---|---:|
| Turtle | `TurtleRoot` | 1.790 × 1.865 × 0.703 |
| Crab | `CrabRoot` | 1.150 × 0.890 × 0.561 |
| Gull | `SeagullRoot` | 0.618 × 1.501 × 0.894 |
| Fish | `FishRoot` | 0.746 × 1.150 × 0.637 |

### Authored pivots, not a skeletal rig

These models contain parented **EMPTY transform pivots**. They do **not** yet contain armatures, bones, skin weights, inverse kinematics or animation clips. Static preview approval must not be represented as animation/rig validation.

- Turtle: `HeadPivot`, `FrontFlipperPivotL/R`, `RearFlipperPivotL/R`, `TurtleTailPivot`.
- Crab: `EyeStalkPivotL/R`, `LegPivotL1…L4/R1…R4`, `ClawPivotL/R`, and child `PincerPivotL/R`.
- Gull: `WingPivotL/R`, `LegPivotL/R`, `SeagullTailPivot`.
- Fish: `TailPivot`, `FinPivotL/R`, `DorsalFinPivot`, `AnalFinPivot`.

Pivot local axes follow Blender XYZ (no hidden pre-rotation). Suggested future rigid-motion axes: fish tail yaw around Z; crab leg lift around Y and stepping sweep around Z; claw pinching around Z; turtle flipper lift around Y and rowing sweep around Z. These are starting axes, not delivered animation. The gull is in a **folded-wing rest pose**: convincing flight requires an authored unfolded wing pose/armature, not scaling or distorting the folded mesh.

## Reproduction

From the project root, with Blender 4.3.2:

```sh
/usr/bin/blender -b -t 8 --python art/v3/build_animals.py
```

Rebuild source and isolated exports without rerendering the identical studio image:

```sh
/usr/bin/blender -b -t 8 --python art/v3/build_animals.py -- --skip-render
```

## Verified / deliberately not done

Verified: all four GLBs are valid version-2 binary containers, contain exactly one expected identity root, preserve the named pivot hierarchies, and exclude cameras/lights/skins/animation clips; all source mesh normals recalculated outward; the final 48-sample render was opened and visually reviewed. The final rebuild only stabilized pivot names and did not change visible geometry.

Not done: skeleton rigging, skinning, runtime animation, engine integration or Godot resource replacement. Existing `art/blender`, `art/export`, `art/previews`, old build scripts and Godot project remain untouched by this animal task.
