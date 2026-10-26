# Fish skeletal swim study

The approved v3 fish shape and materials are preserved. This is a **real Blender armature + skinned mesh** study, not empty-node rotation and not a Godot recording.

## Assets
- `fish_rigged.blend`: editable 11-bone armature, 23 skinned meshes, Swim action, preview lights/camera.
- `fish_rigged.glb`: portable fish only, one skin with 11 joints and the Swim animation. All mesh primitives carry JOINTS_0 / WEIGHTS_0.
- `rig_fish.py`: reproducible rig generation from the existing approved `art/v3/animals.blend`.
- `rig_qa.json`: weight coverage and normalization.
- `fish_swim.gif` / `.mp4`: actual Blender-rendered preview, four seconds, 12 sampled frames per second; original action is 24 fps.

## Motion and weighting
Six longitudinal deform bones run from head through three spine regions and two tail segments. Small head motion develops into a phased stronger caudal wave. Pectoral fins have their own bones and smoothly blended roots; dorsal and anal fins counterbalance. Eyes and mouth remain rigid to the head. Every vertex of every fish mesh has normalized skin weights; no detached or unweighted surfaces are intentional.

The 97th key repeats the four-second end pose. Frames 1–96 form the source cycle. Preview frames 1,3,…,95 are sampled at 12 fps, so playback speed is unchanged rather than slowed down. It is a swim-in-place animation study, not a full underwater scene or physical fluid simulation. No audio is attached.

## Reproduce
Run `blender -b -t 2 --python rig_fish.py`, then `blender -b -t 2 --python render_preview.py`, then `bash encode_preview.sh` from this folder. Blender 4.3.2 / CPU Cycles was used because background Eevee failed EGL initialization in this environment. The quick rendered preview uses 8 samples and may show grain; this does not alter the mesh or animation.

Godot and approved v3 source files are untouched.
