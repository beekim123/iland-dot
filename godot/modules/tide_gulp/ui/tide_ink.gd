extends Control
## Original pencil/watercolour HUD drawing surface. It never consumes game input.
var owner_hud: CanvasLayer
func _draw() -> void:
	if is_instance_valid(owner_hud):
		owner_hud.draw_ink(self)
