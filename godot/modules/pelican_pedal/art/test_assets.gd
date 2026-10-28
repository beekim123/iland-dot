extends SceneTree
const Rig = preload("res://modules/pelican_pedal/art/pelican_bicycle.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for fp in [false,true]:
		var actor := Rig.new(); actor.first_person = fp; root.add_child(actor)
		await process_frame
		check(actor.pedals.size() == 2,"Both separate pedals present")
		check(actor.wheels.size() == 2,"Both real wheel meshes present")
		check(actor.animator != null,"AnimationPlayer imported")
		var skeleton: Skeleton3D = actor._find_type(actor.rider,"Skeleton3D")
		check(skeleton != null and skeleton.get_bone_count() == 16,"16 real bones")
		var skins := 0
		for m in actor.rider.find_children("*","MeshInstance3D",true,false):
			if m.skin != null: skins += 1
		check(skins > 0,"Real imported Skin bound to mesh")
		for clip in ["idle","pedal","steer_left","steer_right","brake"]:
			actor._play(clip)
			check(actor.current_clip == clip,"Clip found: " + clip)
		actor._play("pedal"); actor.animator.play(actor.animator.current_animation, 0.0); actor.animator.advance(0.0); actor.animator.seek(0.0,true)
		var bone := skeleton.find_bone("thigh_L")
		var before := skeleton.get_bone_pose_rotation(bone)
		actor.animator.seek(0.25,true)
		check(before.angle_to(skeleton.get_bone_pose_rotation(bone)) > 0.05,"Pedal actually deforms thigh bone")
		for phase in [0.0,0.25,0.5,0.75]:
			actor.animator.seek(phase,true)
			for side in ["L","R"]:
				var ankle := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("foot_"+side)).origin
				var a: float = phase*TAU+(0.0 if side=="L" else PI)
				var expected := Vector3(-0.22 if side=="L" else 0.22,0.39+0.12*sin(a),0.08-0.12*cos(a))
				check(ankle.distance_to(expected) < 0.004,"Analytic pedal ankle path within 4mm")
			actor._sync_pedals()
			for pedal in actor.pedals:
				var anchor: Dictionary = actor.pedal_anchors[pedal.name]
				var contact: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(anchor.bone) * anchor.point
				check(pedal.global_position.distance_to(contact) < 0.0001,"Pedal stays bound beneath webbed foot")
		var wheel_before: Basis = actor.wheels[0].basis
		actor.set_motion(2,0,false,0.1)
		check(not wheel_before.is_equal_approx(actor.wheels[0].basis),"Wheel rotates with travel")
		actor.queue_free(); await process_frame
	print("PELICAN ART: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
