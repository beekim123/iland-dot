extends RefCounted
## Standalone initial tuning, not user-playtest measurements.
## Length means the solid fish body, excluding decorative fins/tails.
const STAGE_LENGTHS := [1.0, 1.25, 1.56, 1.95, 2.44, 3.05]
const GROWTH_THRESHOLDS := [0.0, 10.0, 27.0, 55.0, 95.0, 150.0]
const TUNING := {
	"player_speed": 4.2, "player_acceleration": 16.0,
	"dash_duration": 0.7, "dash_multiplier": 1.7, "dash_cooldown": 3.0,
	"tide_period": 60.0, "tide_calm": 35.0, "tide_warning": 5.0,
	"current_fraction": 0.25, "first_warning": 1.2, "windup": 0.6,
	"recovery": 1.0, "chase_limit": 7.0, "max_lunges": 2,
	"start_safe_seconds": 8.0, "start_safe_radius": 9.0,
	"chunk_width": 24.0, "half_height": 7.0, "active_radius": 2,
	"fish_per_chunk": 12, "food_respawn_seconds": 120.0,
	"max_chunk_memory": 128, "max_events": 128,
	"growth_rate": 0.32, "spawn_clearance": 14.0,
}
const SPECIES := {
	"silver": {"name": "针尾银鱼", "length_min": 0.44, "length_max": 0.60, "speed": 1.85, "turn": 3.2, "nutrition": 1.0, "behavior": "school", "apex": false},
	"fan": {"name": "扇鳍花鱼", "length_min": 0.70, "length_max": 0.88, "speed": 1.45, "turn": 1.6, "nutrition": 1.15, "behavior": "wander", "apex": false},
	"leaf": {"name": "叶背蝶鱼", "length_min": 1.02, "length_max": 1.28, "speed": 1.65, "turn": 2.4, "nutrition": 1.2, "behavior": "weave", "apex": false},
	"ribbon": {"name": "剪尾梭鱼", "length_min": 1.46, "length_max": 1.65, "speed": 2.3, "turn": 1.05, "nutrition": 1.25, "behavior": "patrol", "apex": false},
	"lantern": {"name": "灯腹鲷", "length_min": 1.82, "length_max": 2.08, "speed": 1.55, "turn": 1.25, "nutrition": 1.4, "behavior": "drift", "apex": false},
	"parrot": {"name": "珊彩鹦鱼", "length_min": 2.24, "length_max": 2.42, "speed": 1.9, "turn": 0.9, "nutrition": 1.55, "behavior": "graze", "apex": false},
	"sailjaw": {"name": "长帆巡游者", "length_min": 4.0, "length_max": 4.25, "speed": 2.4, "turn": 0.65, "nutrition": 0.0, "behavior": "pursuit", "apex": true},
	"whalejaw": {"name": "蓝鲸口守望者", "length_min": 4.6, "length_max": 4.8, "speed": 1.8, "turn": 0.48, "nutrition": 0.0, "behavior": "ambush", "apex": true},
}
const BIOME_POOLS := {
	"shallow": ["silver", "silver", "silver", "silver", "fan", "fan", "fan", "leaf", "leaf", "ribbon", "silver", "fan"],
	"kelp": ["fan", "leaf", "leaf", "ribbon", "ribbon", "lantern", "lantern", "parrot", "silver", "fan", "sailjaw", "leaf"],
	"ruins": ["leaf", "ribbon", "lantern", "lantern", "parrot", "parrot", "parrot", "ribbon", "lantern", "sailjaw", "whalejaw", "fan"],
}
## All hand-authored obstacle rectangles preserve the full central y=-2.2..2.2
## trunk route, wider than the maximum player's 3.05-unit body diameter.
## Side openings are optional escape routes, never compulsory bottlenecks.
const MODULES := {
	"shallow": [
		[Rect2(-8, -7, 4, 3.8), Rect2(3, 3.2, 5, 3.8)],
		[Rect2(-9, 3.8, 3, 3.2), Rect2(-1, -7, 4, 4.0), Rect2(7, 4, 3, 3)],
		[Rect2(-7, -7, 3, 3), Rect2(1, 2.9, 3, 4.1), Rect2(7, -7, 3, 3.5)],
		[Rect2(-8, 3, 5, 4), Rect2(2, -7, 6, 3.7)],
	],
	"kelp": [
		[Rect2(-9, -7, 3, 4.1), Rect2(3, 3.4, 3, 3.6)],
		[Rect2(-7, 3.0, 3, 4), Rect2(0, -7, 3, 3.3), Rect2(7, 4.3, 2, 2.7)],
		[Rect2(-8, -7, 5, 3), Rect2(2, 2.8, 4, 4.2)],
		[Rect2(-9, 4, 5, 3), Rect2(-1, -7, 2.5, 4), Rect2(6, 3.2, 3, 3.8)],
	],
	"ruins": [
		[Rect2(-8, -7, 2.4, 4.2), Rect2(0, 2.7, 2.4, 4.3), Rect2(7, -7, 2.4, 3.3)],
		[Rect2(-9, 3.2, 4, 3.8), Rect2(2, -7, 3, 4.1)],
		[Rect2(-7, -7, 3, 3.9), Rect2(1, 3.0, 3, 4), Rect2(8, -7, 2, 3)],
		[Rect2(-8, 2.8, 3, 4.2), Rect2(-1, -7, 3, 3.6), Rect2(6, 3.3, 3, 3.7)],
	],
}
const TRANSITIONS := {
	"shallow_kelp": [Rect2(-7, -7, 4, 3.1), Rect2(4, 3.5, 3, 3.5)],
	"kelp_ruins": [Rect2(-8, 3.4, 3, 3.6), Rect2(3, -7, 3, 3.7)],
}
