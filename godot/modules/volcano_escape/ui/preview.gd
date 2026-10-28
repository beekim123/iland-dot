extends Node
## Preview only, run with preview.tscn. Not a gameplay proof.
func _ready() -> void:
	var background := ColorRect.new()
	background.color=Color("79b7b7"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var hud := preload("res://modules/volcano_escape/ui/rescue_hud.gd").new()
	add_child(hud)
	hud.update_snapshot({"time":116.0,"status":"running","health":2,"position":Vector2.ZERO,"interaction":{"kind":"balloon","required":6.0,"progress":2.5},"roads":[{"id":"R4","state":"warning","closes_at":136}],"shelters":[{"id":"S2","state":"warning","expires_at":146,"position":Vector2(30,0)}],"rocks":[{"id":"K1","state":"warning","impact_at":120}],"exits":[{"id":"boat","open":true,"windows":[Vector2(90,140)]},{"id":"balloon","open":true,"windows":[Vector2(100,165)]},{"id":"airship","open":false,"windows":[Vector2(140,180)],"called_at":110,"arrives_at":140}],"beacons":[{"lit":true},{"lit":false},{"lit":false}]})
