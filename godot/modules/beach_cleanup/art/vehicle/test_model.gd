extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var cart := (load("res://modules/beach_cleanup/art/vehicle/cleanup_cart.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(cart)
	var shoulder := cart.find_child("Shoulder", true, false) as Node3D
	var elbow := cart.find_child("Elbow", true, false) as Node3D
	var wrist := cart.find_child("Wrist", true, false) as Node3D
	assert(shoulder and elbow and wrist)
	assert(shoulder.position.distance_to(Vector3(0, .77, -.29)) < .001)
	assert(elbow.position.distance_to(Vector3(0, 0, -.48)) < .001)
	assert(wrist.position.distance_to(Vector3(0, 0, -.45)) < .001)
	var counts := count_surfaces(cart)
	assert(counts.x == 11 and counts.y == 11)
	var wheel := cart.find_child("WheelLFront", true, false) as Node3D
	var wheel_mesh := wheel.get_child(0) as MeshInstance3D
	assert(wheel_mesh.mesh.surface_get_material(0).vertex_color_use_as_albedo)
	assert(wheel_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size() > 0)
	var wheel_bounds: AABB = wheel_mesh.transform * wheel_mesh.get_aabb()
	var world_bounds: AABB = wheel_mesh.global_transform * wheel_mesh.get_aabb()
	assert(world_bounds.position.y >= -0.001 and world_bounds.position.y <= 0.02)
	print("WHEEL_GROUND_PASS: minY ", world_bounds.position.y)
	assert(wheel_bounds.size.y > 0.46 and wheel_bounds.size.z > 0.46)
	assert(wheel_bounds.size.x < 0.24)
	print("WHEEL_AXIS_PASS: local bounds ", wheel_bounds.size)
	cart.set_motion(1.0, .5, .1)
	for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
		cart.set_grab(progress, Vector3(.2, .05, -1.12))
		assert(shoulder.transform.is_finite() and elbow.transform.is_finite() and wrist.transform.is_finite())
	for reach in [0.02, 0.1, 0.4, 0.8, 1.4, 1.8]:
		for angle in [-40.0, 0.0, 40.0]:
			var target := Vector3(sin(deg_to_rad(angle)) * reach, 0.11, -cos(deg_to_rad(angle)) * reach)
			cart.set_grab(0.5, target)
			var gap: float = cart.get_grip_world_position().distance_to(target)
			print("GRIP_REACH ", reach, " angle=", angle, " gap=", gap)
			assert(gap < 0.03)
	cart.set_cargo(["bottle", "can", "wrapper", "sandal", "crate", "net"])
	assert(cart.get_node("VisibleCargo").get_child_count() == 6)
	var first_cargo_id: int = cart.get_node("VisibleCargo").get_child(0).get_instance_id()
	cart.set_cargo(["bottle", "can", "wrapper", "sandal", "crate", "net"])
	assert(cart.get_node("VisibleCargo").get_child(0).get_instance_id() == first_cargo_id)
	cart.set_cargo([])
	assert(cart.get_node("VisibleCargo").get_child_count() == 0)
	for kind in ["bottle", "can", "wrapper", "sandal", "crate", "net"]:
		var trash := (load("res://modules/beach_cleanup/art/trash/"+kind+".tscn") as PackedScene).instantiate()
		root.add_child(trash)
		assert(count_surfaces(trash) == Vector2i(1,1))
		var trash_mesh := trash.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert(trash_mesh.mesh.surface_get_material(0).vertex_color_use_as_albedo)
		trash.free()
	print("CART_MODEL_PASS: 11 meshes / 11 surfaces; six trash each 1 surface; pivots, finite IK, wheels and cargo refresh verified")
	cart.queue_free()
	quit()
func count_surfaces(node: Node) -> Vector2i:
	var result := Vector2i.ZERO
	if node is MeshInstance3D:
		result = Vector2i(1, node.mesh.get_surface_count())
	for child in node.get_children():
		result += count_surfaces(child)
	return result
