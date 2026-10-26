extends RefCounted
## Real imported AnimationPlayer/Skeleton3D. Never transform individual mesh pivots.
static func bind_actor(actor: Node3D, requested_clip: String) -> Dictionary:
	var players := actor.find_children("*","AnimationPlayer",true,false)
	var skeletons := actor.find_children("*","Skeleton3D",true,false)
	if players.is_empty() or skeletons.is_empty():
		push_error("Missing real armature/player in "+actor.name)
		return {}
	var player := players[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clips := {}
	for clip in player.get_animation_list():
		if clip == "RESET": continue
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR
		clips[String(clip).get_slice("/", String(clip).get_slice_count("/")-1)] = String(clip)
	var rig := {"actor":actor,"player":player,"skeleton":skeletons[0],"clips":clips}
	sample(rig,requested_clip,0.0)
	return rig

static func sample(rig: Dictionary, clip: String, time: float) -> void:
	if rig.is_empty(): return
	var player: AnimationPlayer = rig.player
	var actual: String = rig.clips.get(clip, "")
	if actual.is_empty():
		push_error("Missing authored clip "+clip)
		return
	if player.current_animation != actual:
		player.play(actual)
	player.seek(fposmod(time,4.0) / 4.0 * player.get_animation(actual).length,true)
	player.advance(0.0)
	var skeleton: Skeleton3D = rig.skeleton
	skeleton.force_update_all_bone_transforms()
