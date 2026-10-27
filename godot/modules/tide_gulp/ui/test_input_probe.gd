extends Node
## Test-only sink: records clicks that genuinely reached unhandled game input.
var unhandled_clicks := 0
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		unhandled_clicks += 1
