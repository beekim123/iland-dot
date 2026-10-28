> 资源整理说明（2026-10-28）：本文保留当时的制作/验收记录；旧模型、预览和试听二进制可能已从当前树删除，作者导出为本地可再生产物。需要复现原始文件时请使用整理前提交 `7b16265a990a1e3c342315fb0ab0ce94e5774601`，当前运行成品以 active_asset_manifest 的 destination 为准。

# Q-style botanical collection — model rebuild v3.1

This is a genuine **Q版 / chibi clay-diorama geometry rebuild** of the island plants, not a lighting-only update. The user explicitly rejected a realistic feeling; the final direction uses simple chunky forms, not detailed botanical realism. All earlier scene, model and Godot files remain untouched.

## Art changes

- **Three coconut-palm silhouettes:** a compact leaning hero, an opposing bowed medium tree, and a shorter young palm. Trunks are plump, taper continuously, curve smoothly and flare at the roots. Only three quiet growth marks remain; the cylinder-stack appearance is gone.
- **Chunky paired crowns:** six directionally layered fronds per palm, each with a curved central stem and six pairs of broad rounded leaflets plus one terminal leaf. These are closed, thick, smoothly shaded clay-like meshes, not paper-thin feathers, alpha cards or star-shaped banana petals. Upper and lower layers use different rise, length and droop.
- **Coconut clusters:** five differently angled fruits and their connecting stems per crown.
- **Large ground foliage:** simplified split Monstera leaves, including two large upright broad blades; banana leaves have bowed surfaces and large readable folds. Fussy secondary veins are removed.
- **Two flowering shrubs:** six authored branching leaf sprays and seven cupped five-petal flowers, coral/peach or cream/gold. No spherical leaf masses.
- **Small detail assets:** simplified seven-frond fern with four leaflet pairs per frond, and an eleven-blade curved grass clump.
- **Color:** soft saturated emerald and jade, selectively lighter lime upper leaves, green—not white—central stems, golden-brown trunks and restrained coral/cream flowers.

## Files

- `art/v3/build_plants.py` — complete deterministic Blender authoring script; fixed random seeds.
- `art/v3/plants.blend` — editable master collection and separate non-exported studio collection.
- `art/v3/plants.glb` — collection in a **studio layout**, not an assembled island.
- `art/v3/plants_preview.png` — actual Blender Cycles model render, 1280×960, 96 CPU samples, denoising disabled.
- `art/v3/plants_manifest.json` — per-asset filenames, exact local bounds, vertex/triangle counts and studio positions.
- Separate local-origin GLBs: `palm_a`, `palm_b`, `palm_c`, `foliage_monstera`, `foliage_banana`, `shrub_coral`, `shrub_cream`, `fern_a`, `grass_a`.

## Placement and object hierarchy

All individual GLBs have a named root at **ground (0, 0, 0)**. Blender uses Z-up and front −Y; standard glTF Y-up conversion is enabled. Do not import the studio master as world-placed vegetation.

Root names:

```
Palm_A  Palm_B  Palm_C
Foliage_Monstera  Foliage_Banana
Shrub_Coral  Shrub_Cream
Fern_A  Grass_A
```

Each palm root has nine direct mesh children: `*_BowedTrunk`, `*_CrownSheath`, `*_Coconuts`, and `*_Frond_01`…`*_Frond_06`. Frond mesh origins are at the base of their rachis and are useful for modest later wind motion. All other roots have one or two direct mesh children. Material slots preserve green-value variations while leaflets are joined by frond to avoid hundreds of scene objects.

For Blender assembly, append a root and its mesh descendants, reset the root's studio translation, and set it to `(x, y, terrain_height(x,y))` using the pure-Python terrain function from `art/v3/build_landscape.py`. Duplicate the hierarchy with shared mesh data if desired. Scale and rotate the **root**, not individual child meshes. Five or six palms should form asymmetrical groups rather than an evenly spaced circular fence. Keep the foreground animal beach open. Place groundleaf clumps in overlapping groups beneath the canopy and at the grass–sand transition.

The local root bounds in the manifest include bowed trunks, full crowns and root toes. This is deliberately a model-only handoff; no game integration is performed by this script.

## Reproduce

From the project root:

```sh
/usr/bin/blender -b -t 8 --python art/v3/build_plants.py
```

Optional `-- --quick` exports the full assets but renders a 60% / 24-sample preview. `-- --no-render` exports and saves only. No downloaded images, generated textures, external mesh dependencies or custom add-ons are required.

The geometry is low-to-mid-poly rather than ultra-low-poly: roughly 11–14k triangles per palm, with editable continuous curved surfaces and real leaf silhouettes. See the manifest for exact totals. Meshes deliberately use two-sided opaque materials, with no alpha-cutout artifacts.

## Style revision record

The first exploration had 13 pairs of thin leaflets and more surface detail. It was superseded after the explicit user correction “不要太真实了…要 q 版”. Its script and preview are retained only in `art/v3/exploration_botanical/`; they are not the final model. The active assets, active script and final preview are the revised Q-style set.

## Verified Q asset geometry

| Asset | Height (m) | Triangles | Mesh children |
|---|---:|---:|---:|
| `Palm_A` | 5.70 | 12,938 | 9 |
| `Palm_B` | 4.96 | 12,938 | 9 |
| `Palm_C` | 4.11 | 12,938 | 9 |
| `Foliage_Monstera` | 1.89 | 1,400 | 1 |
| `Foliage_Banana` | 1.58 | 1,000 | 1 |
| `Shrub_Coral` | 1.02 | 4,204 | 2 |
| `Shrub_Cream` | 1.05 | 4,204 | 2 |
| `Fern_A` | 0.55 | 2,394 | 1 |
| `Grass_A` | 0.36 | 528 | 1 |

The unique asset library contains 52,544 triangles before instancing.

Validation: all ten exported GLBs were parsed as valid glTF 2.0 with correct container lengths and expected named scene roots. Their buffers are embedded and there are no external image/texture dependencies. The studio floor, camera and lights are excluded from the GLBs. The Q-style preview was visually reviewed and accepted for scene assembly; final user approval remains with the assembled model preview.
