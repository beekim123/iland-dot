# Tide Gulp original watercolor art — reproducible source

Created specifically for the third portal, not reused from Sunny Shell, Gummy Bomber, or Bloom Skirmish.

## Rebuild the actual 3D meshes

```sh
blender --background --python godot/modules/tide_gulp/art/source/build_fish.py
# Optional targeted rebuild:
blender --background --python godot/modules/tide_gulp/art/source/build_fish.py -- moonfish_0
```

Blender 4.3.2 was used. The script creates editable `.blend` source files and glTF 2.0 binary meshes under `../fish/`. It uses original mathematical mesh lofts, curved fin membranes, volumetric eyes and a real eight-bone Armature modifier. It does not paint images pretending to be models, use downloaded fish models, or generate any promotional art.

`source/.gdignore` deliberately keeps authoring `.blend` files out of Godot's resource/import/export pipeline. Runtime uses only the eleven GLBs, GDScript and the original watercolor shader.

## Contract and coordinates

- Godot +X is forward, +Y up, +Z toward the camera. Both sides have full modeled eyes.
- The continuous primary body spans x=-0.5 through x=+0.5. Tail/fins/streamers do not count toward effective gameplay length.
- `moonfish_0`, `_1`, `_2` are three detail tiers for stages 0–1, 2–3 and 4–5. They are cached once per player and switched without reconstruction.
- Ordinary species: `silver`, `fan`, `leaf`, `ribbon`, `lantern`, `parrot`.
- Apex silhouettes: slender high-dorsal `sailjaw`, heavy blunt-front `whalejaw`.
- One vertex-pigment material per fish; ~2,300–2,500 source triangles each. Exact source counts in `build_report.json` (Godot import may deduplicate/filter degenerate pole faces).
- Bones: head → spine_a → spine_b → spine_c → tail; jaw and paired pectoral fins are independent head children. Continuous blend weights overlap neighboring body bones. Dorsal and ventral fins are topologically welded: they reuse the existing body-surface root vertices and therefore share precisely identical root bone weights in all poses.
- `tide_fish.gd` applies a traveling phase with increasing tail amplitude and layers jaw opening, turning and dash motion. The runtime owns all world position/facing/length transforms.

## Color / material system

Moonfin uses apricot-gold shoulders, pearl-cream underside and muted plum caudal/dorsal fins. Fish have no metallic/clearcoat/specular contribution. All paint colors are authored vertex pigments. `watercolor.gdshader` adds soft low-frequency pigment pooling and screen-stable interpolated paper tooth without a time-dependent noise texture. Eyes retain dark ink contrast; geometry remains real 3D during turns.

## Environment

`tide_environment.gd` batches original 3D low-poly seabed/sea-fan/shell/kelp/ruin geometry by material. Backgrounds and scenery sit behind the gameplay plane. The only visible blocking reefs are constructed from the simulation's exact `Rect2` values. No artwork creates hidden collisions.

## Verify

```sh
Godot --headless --path godot --script res://modules/tide_gulp/art/tide_art_contract_check.gd
Godot --path godot res://modules/tide_gulp/art/tide_art_preview.tscn -- --tide-art-shot --tide-art-output=/tmp/tide-art-preview.png
```

The first check verifies all nine species have actual Skeleton3D and Skin bindings, one mesh material, differing head/tail poses, six growth stages without node recreation, and all three nonempty ecology chunks. The second captures a real rendered Godot frame (requires a graphics display).
