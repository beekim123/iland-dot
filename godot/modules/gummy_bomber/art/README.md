# Gummy Garden — original candy art

Standalone procedural 3D artwork for the Gummy Bomber module. No island asset,
Autoload, external font, texture, addon or character franchise dependency.

- One tile: 1 metre; roots at ground Y=0, face towards -Z.
- Actor visuals approximately 0.6 m tall; collision remains gameplay-owned.
- `candy_factory.gd`: static `make_player`, `make_enemy(kind=0)`, `make_bomb`,
  `make_wall`, `make_crate`, `make_floor(variant=0)`, `make_pickup(kind="range")`,
  `make_blast`, each returns a newly owned Node3D.
- Supported pickup kinds: `range`, `capacity`, `speed`.
- Rounded boxes are authored smooth bevel meshes, with shared mesh/material
  caching. Each rounded piece uses 192 triangles with support vertices at bevel
  boundaries; actor spheres use 16 segments / 8 rings. The gameplay board groups
  static geometry into MultiMesh batches. Jellies have face features, cheeks, shine and distinct silhouettes.
- Chocolate = permanent obstruction; cream-filled wafer = breakable obstruction.
- Pink sugar orb = bomb, gold/cream flash + pastel confetti = nonviolent blast.
- Player/monster `Body` meshes can be animated by their parent root. Front is -Z.
- Use `preview.tscn` for the actual engine cast/contact-sheet scene.
- Test: Godot `--headless --path godot --script
  res://modules/gummy_bomber/art/validate_art.gd`.

## Audio

`../audio/synthesize_audio.py` reproducibly synthesizes all original audio with
Python and numpy (no external sample library). WAVs are PCM 16-bit / 44.1 kHz.
`music_loop.wav` is stereo, exactly 32 seconds, 16 bars at 120 BPM, with a seamless
wrapped decay. Enable AudioStreamWAV forward looping; SFX are one-shot mono.
Peak amplitude is documented in `audio_manifest.json`, none clips.
Music is deliberately quiet to sit below placement/pop/pickup sounds. Content is
independent of the island's soundtrack and can be exported with this module.
