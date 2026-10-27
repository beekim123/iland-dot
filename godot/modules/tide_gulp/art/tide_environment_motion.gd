extends Node3D
## Minimal motion adapter for runtime-pooled watercolor scenery.
## The scene root remains at the world origin; only decorative kelp deforms.
const EnvironmentArt = preload("res://modules/tide_gulp/art/tide_environment.gd")
var current_strength: float = 0.0

func set_current(current: float) -> void:
	current_strength = clampf(current, -2.0, 2.0)

func tick_pose(_delta: float, time: float) -> void:
	EnvironmentArt.animate_environment(self, time, current_strength)
