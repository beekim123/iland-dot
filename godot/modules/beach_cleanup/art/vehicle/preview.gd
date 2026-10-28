extends Node3D
var _frames := 0
var _output := ""
var _preset := "hero"
func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		if argument.begins_with("--preset="):
			_preset = argument.trim_prefix("--preset=")
	var camera := $Camera3D as Camera3D
	if _preset == "extended":
		camera.position = Vector3(2.0, 1.8, -3.2)
		camera.size = 3.4
		$CleanupCart.set_grab(0.50, Vector3(0, 0.15, -1.8))
	elif _preset == "grip":
		camera.position = Vector3(1.8, 1.65, -2.9)
		camera.size = 2.55
		$CleanupCart.set_grab(0.50, Vector3(0, 0.1, -1.1))
	elif _preset == "cargo":
		camera.position = Vector3(2.0, 2.0, 2.8)
		camera.size = 2.7
		$CleanupCart.set_cargo(["bottle", "can", "wrapper", "sandal", "net", "bottle"])
	camera.look_at(Vector3(0, 0.5, -0.22))
	for i in range(6):
		var kind: String = ["bottle", "can", "wrapper", "sandal", "crate", "net"][i]
		var model := (load("res://modules/beach_cleanup/art/trash/" + kind + ".tscn") as PackedScene).instantiate() as Node3D
		add_child(model)
		model.position = Vector3(-1.25 + float(i % 3) * 1.2, 0, 1.0 + float(i / 3) * 0.65)
		if _preset != "catalog":
			model.visible = false
	if _preset == "catalog":
		camera.position = Vector3(3.5, 4.8, -5)
		camera.size = 5.4
		camera.look_at(Vector3(0, 0.2, 0.65))
func _process(_delta: float) -> void:
	_frames += 1
	if _output != "" and _frames == 8:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(_output)
		get_tree().quit()
