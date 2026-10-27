extends Node3D
## Self-contained original 2v2 greenhouse arena. The host owns only routing.
signal exit_requested
const Simulation = preload("sim.gd")
const Art = preload("art/bloom_art.gd")
const BloomHUD = preload("ui/bloom_hud.gd")
const TurfShader = preload("ui/turf.gdshader")
const NectarEffects = preload("effects/nectar_effects.gd")
const GAME_ID := "bloom_skirmish"
const SAVE_DIR := "user://games/bloom_skirmish"
const SAVE_PATH := SAVE_DIR + "/profile.json"
const FIXED_DT := 1.0 / 60.0
const DEFAULT_RECORD_FPS := 12
const TEAM_COLORS := [Color("2f62ff"), Color("ff8a1f")]
# Species are participant identity, never an alias for team color.
const ACTOR_SPECIES := ["otter", "rabbit", "fox", "raccoon"]
var sim = Simulation.new()
var camera: Camera3D
var camera_yaw := -PI * 0.5
var camera_pitch := -0.16
var camera_distance := 4.7
var camera_shoulder := 1.15
var camera_pivot := Vector3.ZERO
var camera_boom_length := 4.7
var pointer_active := false
var capture_grace_left := 0.0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var mouse_sensitivity := 0.0024
var aim_world := Vector3(16, 0, 12)
var aim_enemy := false
var aim_has_hit := false
var aim_direction := Vector3.RIGHT
var movie_dir := ""
var movie_frames := 0
var movie_next := 8.0
var movie_pending := false
var movie_frame_limit := 96
var record_fixed := false
var record_fps := DEFAULT_RECORD_FPS
var arena: Node3D
var dynamic: Node3D
var fx: Node3D
var hud
var floor_mesh: MeshInstance3D
var turf_image: Image
var turf_texture: ImageTexture
var terrain_revision := -1
var actor_cache: Dictionary = {}
var projectile_cache: Dictionary = {}
var pod_cache: Dictionary = {}
var effects: Array[Dictionary] = []
var previous_positions: Dictionary = {}
var shot_pitches: Dictionary = {}
var running := false
var paused := false
var has_started := false
var countdown_left := 3.0
var countdown_last := 4
var elapsed := 0.0
# Only skeletal result presentation advances after the authoritative match ends.
# The match timer, ownership, projectiles and gameplay remain frozen.
var results_animation_elapsed := 0.0
var fixed_accumulator := 0.0
var previous_ticks := 0
var seed_value := 1
var keys: Dictionary = {}
var shoot_held := false
var dash_queued := false
var pod_queued := false
var aim_target := Vector2(16,12)
var input_guard := 0.0
var match_recorded := false
var save_service: Object
var save_write_allowed := true
var best_coverage := 0.0
var wins := 0
var matches := 0
var audio_enabled := true
var save_extras: Dictionary = {}
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var sound_throttle: Dictionary = {}
var viewport_settings: Dictionary = {}
var capture_path := ""
var capture_frame := 0
var capture_after := 0.0
var captured := false
var demo_mode := false
var motion_demo_mode := false
var profile_elapsed := 0.0
var empty_water_hint_shown := false
var pending_start_context: Dictionary = {}
var quit_handler: Callable
var window_shutdown_pending := false
var previous_auto_accept_quit := true
var owns_quit_policy := false

func _ready() -> void:
	build_scene()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bloom-capture="): capture_path=arg.trim_prefix("--bloom-capture=")
		if arg=="--bloom-demo": demo_mode=true
		if arg=="--bloom-motion-demo": motion_demo_mode=true; demo_mode=true
		if arg.begins_with("--bloom-movie-dir="): movie_dir=arg.trim_prefix("--bloom-movie-dir=")
		if arg.begins_with("--bloom-record-dir="): movie_dir=arg.trim_prefix("--bloom-record-dir="); record_fixed=true
		if arg.begins_with("--bloom-record-frames="): movie_frame_limit=clampi(int(arg.trim_prefix("--bloom-record-frames=")),1,3600)
		if arg.begins_with("--bloom-record-fps="): record_fps=_record_fps_from_arg(arg.trim_prefix("--bloom-record-fps="))
		if arg.begins_with("--bloom-record-after="): movie_next=maxf(0.0,float(arg.trim_prefix("--bloom-record-after=")))
		if arg.begins_with("--bloom-capture-after="): capture_after=maxf(0.0,float(arg.trim_prefix("--bloom-capture-after=")))
	call_deferred("autostart")

static func _record_fps_from_arg(value:String) -> int:
	if not value.is_valid_int(): return DEFAULT_RECORD_FPS
	var requested:=int(value)
	return requested if requested>=1 and requested<=60 else DEFAULT_RECORD_FPS

func autostart() -> void:
	if not has_started: start(pending_start_context)

func start(context: Dictionary = {}) -> void:
	if not is_node_ready():
		pending_start_context=context.duplicate(); return
	if not has_started: previous_mouse_mode=Input.mouse_mode
	has_started=true
	quit_handler=context.get("quit_handler",Callable())
	if not owns_quit_policy:
		previous_auto_accept_quit=get_tree().auto_accept_quit; owns_quit_policy=true; get_tree().auto_accept_quit=false
	save_service=context.get("save_service",null)
	load_data()
	seed_value=int(context.get("seed",Time.get_ticks_msec()))
	configure_render_quality()
	running=true; paused=false; pointer_active=demo_mode
	set_process(true); set_process_input(true); set_process_unhandled_input(true)
	hud.show(); hud.set_process(true)
	camera.make_current()
	_begin_match()
	if music:
		music.stream_paused=false
		if audio_enabled: music.play()

func _begin_match() -> void:
	sim.start(seed_value)
	countdown_left=3.0; countdown_last=4; elapsed=0.0; results_animation_elapsed=0.0; fixed_accumulator=0.0
	previous_ticks=Time.get_ticks_usec(); match_recorded=false; terrain_revision=-1
	input_guard=0.2; empty_water_hint_shown=false; clear_input(); previous_positions.clear(); shot_pitches.clear(); _clear_dynamic()
	if arena: arena.free()
	arena=Art.make_arena(sim.obstacles,sim.spawn_zones); add_child(arena); _batch_static_arena(arena)
	camera_yaw=-PI*.5; camera_pitch=-.16; _update_camera(0.0,true); _update_aim()
	_update_turf(true)
	_sync_visuals(0.0)
	_update_hud()

func restart() -> void:
	if not running: return
	seed_value+=1; paused=false
	_begin_match(); _capture_mouse(); _sync_audio_pause(); play_sound("ui_click")

func build_scene() -> void:
	print("BLOOM VISUAL_REV=5: sunlit mineral greenhouse, cobalt/orange liquid, independent competitive HUD")
	# Camera-local environment never replaces the host island's look on return.
	# One clear sun establishes volume; restrained cool fill keeps graphite legible.
	var env:=Environment.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("739cce"); sky_material.sky_horizon_color=Color("dce8f0")
	sky_material.ground_horizon_color=Color("dce8f0"); sky_material.ground_bottom_color=Color("aab7ba")
	sky_material.sky_curve=.22; sky_material.ground_curve=.15
	sky_material.sun_angle_max=4.0; sky_material.sun_curve=.08
	var sky:=Sky.new(); sky.sky_material=sky_material; sky.radiance_size=Sky.RADIANCE_SIZE_128
	env.background_mode=Environment.BG_SKY; env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("c9d8ed"); env.ambient_light_energy=.22
	env.ambient_light_sky_contribution=0.0
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun:=DirectionalLight3D.new(); sun.name="GreenhouseSun"
	sun.rotation_degrees=Vector3(-52,-42,0); sun.light_color=Color("fff5e8"); sun.light_energy=.56
	sun.shadow_enabled=true; sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance=54
	# Compatibility/software-GL PSSM produced dense receiver striping across
	# all materials. Same-seed native off/orthogonal A/B isolated the shadow path:
	# one orthogonal map removes the artifact while retaining contact shadows.
	# Do not replace this fix with disabled shadows or compensating turf patterns.
	sun.shadow_bias=.10; sun.shadow_normal_bias=1.10
	add_child(sun)
	camera=Camera3D.new(); camera.environment=env; camera.projection=Camera3D.PROJECTION_PERSPECTIVE; camera.fov=64.0; camera.near=.08
	camera.position=Vector3(-3,2.5,12); add_child(camera); camera.current=true; camera.far=100
	floor_mesh=MeshInstance3D.new(); floor_mesh.name="CoverageSurface"
	var plane:=PlaneMesh.new(); plane.size=Vector2(32,24); floor_mesh.mesh=plane; floor_mesh.position=Vector3(16,.025,12); add_child(floor_mesh)
	turf_image=Image.create(Simulation.GRID_W,Simulation.GRID_H,false,Image.FORMAT_RGB8); turf_image.fill(Color.BLACK); turf_texture=ImageTexture.create_from_image(turf_image)
	var turf:=ShaderMaterial.new(); turf.shader=TurfShader; turf.set_shader_parameter("coverage_map",turf_texture); turf.set_shader_parameter("grid_size",Vector2(Simulation.GRID_W,Simulation.GRID_H))
	# Explicit Color parameters keep Compatibility/WebGL source-color conversion consistent.
	var palette:={"mineral_a":Color("dce1e1"),"mineral_b":Color("d3d9da"),"blue_glint":Color("dce8ff"),"orange_glint":Color("fff0da"),"blue_liquid":TEAM_COLORS[0],"orange_liquid":TEAM_COLORS[1]}
	for parameter in palette:
		turf.set_shader_parameter(parameter,palette[parameter])
	floor_mesh.material_override=turf
	dynamic=Node3D.new(); dynamic.name="LiveAthletesAndPods"; add_child(dynamic)
	fx=NectarEffects.new(); add_child(fx)
	hud=BloomHUD.new(); add_child(hud)
	hud.pause_requested.connect(func(): set_paused(not paused))
	hud.exit_requested.connect(leave_game); hud.restart_requested.connect(restart); hud.audio_requested.connect(toggle_audio)
	for sound_name in ["shoot","hit","pod","bloom","dash","defeat","victory","ui_click","countdown","round_start","respawn"]:
		var path:String="res://modules/bloom_skirmish/audio/"+str(sound_name)+".wav"
		if ResourceLoader.exists(path):
			var voice:=AudioStreamPlayer.new(); voice.stream=load(path); voice.volume_db=-13.0 if sound_name=="shoot" else -10.0; add_child(voice); sounds[sound_name]=voice
	var music_path:="res://modules/bloom_skirmish/audio/music_loop.wav"
	if ResourceLoader.exists(music_path):
		music=AudioStreamPlayer.new(); music.stream=load(music_path).duplicate(); music.volume_db=-9.0
		if music.stream is AudioStreamWAV:
			music.stream.loop_begin=0
			music.stream.loop_end=roundi(music.stream.get_length()*music.stream.mix_rate)
			music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		add_child(music)

func clear_input() -> void:
	keys.clear(); shoot_held=false; dash_queued=false; pod_queued=false

func set_paused(value:bool) -> void:
	if not running or sim.state=="finished": return
	paused=value; clear_input(); fixed_accumulator=0.0; previous_ticks=Time.get_ticks_usec(); input_guard=.15
	if paused: _release_mouse()
	else: _capture_mouse()
	_sync_audio_pause(); play_sound("ui_click"); _update_hud()

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and has_started: request_application_quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused: set_paused(true)

func _input(event:InputEvent) -> void:
	# Releases are processed even when an interface control consumes the event.
	if event is InputEventKey and not event.pressed: keys.erase(event.physical_keycode)
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT: shoot_held=false

func _unhandled_input(event:InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		set_paused(not paused); get_viewport().set_input_as_handled(); return
	if paused or sim.state=="finished": return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not pointer_active:
		_capture_mouse(); get_viewport().set_input_as_handled(); return
	if not pointer_active and not demo_mode: return
	if event is InputEventMouseMotion:
		camera_yaw-=event.relative.x*mouse_sensitivity
		camera_pitch=clampf(camera_pitch-event.relative.y*mouse_sensitivity,-.75,.28)
		get_viewport().set_input_as_handled(); return
	if countdown_left>0 or input_guard>0: return
	if event is InputEventKey and not event.echo:
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			if event.pressed: keys[event.physical_keycode]=true
			else: keys.erase(event.physical_keycode)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_SPACE and event.pressed:
			dash_queued=true; get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			shoot_held=event.pressed; get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			pod_queued=true
			if sim.actors[0].alive:
				if sim.owner_at(sim.actors[0].pos)!=0: hud.show_toast("先涂出一片己方区域")
				elif sim.actors[0].pod_cd>0: hud.show_toast("花苞正在恢复")
			get_viewport().set_input_as_handled()

func _command() -> Dictionary:
	var move:=Vector2(float(keys.has(KEY_D) or keys.has(KEY_RIGHT))-float(keys.has(KEY_A) or keys.has(KEY_LEFT)),float(keys.has(KEY_S) or keys.has(KEY_DOWN))-float(keys.has(KEY_W) or keys.has(KEY_UP)))
	if move.length_squared()>1: move=move.normalized()
	var forward:=Vector2(-sin(camera_yaw),-cos(camera_yaw))
	var right:=Vector2(cos(camera_yaw),-sin(camera_yaw))
	move=right*move.x-forward*move.y
	var command:={"move":move,"aim":aim_target,"shoot":shoot_held,"dash":dash_queued,"pod":pod_queued}
	if aim_has_hit: command["aim_world"]=aim_world
	else: command["aim_direction"]=aim_direction
	dash_queued=false; pod_queued=false
	if motion_demo_mode:
		# Explicit motion-capture/test driver: ordinary legal input only. Keep the
		# old --bloom-demo path unchanged for comparisons and never teleport actors.
		var active_time:=maxf(0.0,elapsed-3.0)
		command={"move":_motion_demo_move(active_time),"aim":aim_target,"shoot":fmod(active_time,2.3)<.70,"pod":false,"dash":active_time>=.70 and active_time<1.0}
		if aim_has_hit: command["aim_world"]=aim_world
		else: command["aim_direction"]=aim_direction
	elif demo_mode:
		# Opt-in capture-only driver; the normal game never runs this input.
		var active_time:=maxf(0.0,elapsed-3.0)
		var demo_move:=Vector2.RIGHT if active_time<.85 else (Vector2(.3,sin(active_time*.32)*.2) if active_time>10.0 else Vector2.ZERO)
		command={"move":demo_move,"aim":aim_target,"shoot":fmod(active_time,3.0)<1.2,"pod":fmod(elapsed,13.0)<FIXED_DT,"dash":false}
		if aim_has_hit: command["aim_world"]=aim_world
		else: command["aim_direction"]=aim_direction
	return command

func _motion_demo_move(active_time:float) -> Vector2:
	# A full-speed rectangular run through the existing left-center lane. Corners
	# and the single dash still use simulation collision/sliding and cooldowns.
	var phase:=fposmod(active_time,4.7)
	if phase<1.50: return Vector2.RIGHT
	if phase<2.35: return Vector2.DOWN
	if phase<3.85: return Vector2.LEFT
	return Vector2.UP

func _process(_engine_delta:float) -> void:
	if not running: return
	var now:=Time.get_ticks_usec(); var dt:=float(now-previous_ticks)/1000000.0; previous_ticks=now
	# Background tabs/suspended apps pause instead of teleporting through a match.
	if dt>5.0: set_paused(true); dt=0.0
	if record_fixed: dt=1.0/float(record_fps)
	input_guard=maxf(0.0,input_guard-dt); capture_grace_left=maxf(0.0,capture_grace_left-dt)
	if DisplayServer.get_name()!="headless" and pointer_active and capture_grace_left<=0 and not demo_mode and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: set_paused(true)
	if motion_demo_mode:
		var active_time:=maxf(0.0,elapsed-3.0)
		var heading:=_motion_demo_move(active_time)
		camera_yaw=lerp_angle(camera_yaw,atan2(-heading.x,-heading.y),1.0-exp(-6.0*dt))
		camera_pitch=-.23+sin(active_time*1.1)*.07
	elif demo_mode:
		camera_yaw=-PI*.5+sin(maxf(0.0,elapsed-3.0)*.48)*.24
		camera_pitch=-.30
	_update_camera(dt); _update_aim()
	if not paused and (pointer_active or demo_mode) and sim.state!="finished":
		elapsed+=dt; fixed_accumulator+=dt
		while fixed_accumulator+0.00000001>=FIXED_DT:
			fixed_accumulator-=FIXED_DT
			step_simulation(FIXED_DT)
			if sim.state=="finished": fixed_accumulator=0.0; break
	if not paused and not sim.actors.is_empty():
		if sim.actors[0].water>50: empty_water_hint_shown=false
		if shoot_held and sim.actors[0].water<5 and not empty_water_hint_shown:
			empty_water_hint_shown=true; hud.show_toast("松开左键，让喷射器自动补液",3.0)
	floor_mesh.material_override.set_shader_parameter("liquid_time",elapsed)
	_update_turf()
	_sync_visuals(0.0 if paused else dt)
	_update_camera(dt); _update_aim()
	_update_hud()
	profile_elapsed+=dt
	if profile_elapsed>=5.0 and "--bloom-profile" in OS.get_cmdline_user_args():
		profile_elapsed=0.0
		print("BLOOM PERF fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if not capture_path.is_empty() and not captured:
		capture_frame+=1
		if capture_frame>=90 and elapsed>=capture_after: captured=true; call_deferred("_capture_viewport")
	if not movie_dir.is_empty() and movie_frames<movie_frame_limit and elapsed>=movie_next and not movie_pending:
		movie_pending=true; movie_next+=1.0/float(record_fps); call_deferred("_capture_movie_frame")

func step_simulation(dt:float) -> void:
	if countdown_left>0:
		countdown_left=maxf(0.0,countdown_left-dt)
		var number:=ceili(countdown_left)
		if number!=countdown_last and number>0: countdown_last=number; play_sound("countdown")
		if countdown_left<=0:
			clear_input(); play_sound("round_start"); hud.show_toast("松开左键补液 · 花苞部署在己方涂层",4.0)
		return
	sim.step(dt,_command())
	for event in sim.drain_events(): _handle_event(event)
	if sim.state=="finished" and not match_recorded:
		match_recorded=true; matches+=1; wins+=1 if sim.winner==0 else 0; best_coverage=maxf(best_coverage,float(sim.score[0])); save_data(); clear_input(); _release_mouse(); play_sound("victory")
		for actor in sim.actors:
			var reaction:="clear" if sim.winner<0 else ("victory" if int(actor.team)==sim.winner else "defeat")
			_react_actor(int(actor.id),reaction)

func _capture_mouse() -> void:
	# Invoked directly from a pressed input event or a pressed UI button: Web-safe.
	if demo_mode: pointer_active=true; return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	pointer_active=true; capture_grace_left=.25; clear_input(); previous_ticks=Time.get_ticks_usec(); fixed_accumulator=0.0

func _release_mouse() -> void:
	pointer_active=false; capture_grace_left=0.0
	Input.mouse_mode=previous_mouse_mode
	clear_input()

func _look_direction() -> Vector3:
	return Vector3(-sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),-cos(camera_yaw)*cos(camera_pitch)).normalized()

func _update_camera(dt:float,snap:bool=false) -> void:
	if sim.actors.is_empty(): return
	var pos:Vector2=sim.actors[0].pos
	var target:=Vector3(pos.x,1.85,pos.y)
	camera_pivot=target if snap else camera_pivot.lerp(target,1.0-exp(-18.0*maxf(dt,0.0)))
	var look:=_look_direction(); var right:=Vector3(cos(camera_yaw),0,-sin(camera_yaw))
	var desired:=camera_pivot-look*camera_distance+right*camera_shoulder
	var safe:=camera_safe_position(camera_pivot,desired)
	camera.position=safe; camera_boom_length=camera_pivot.distance_to(safe)
	camera.look_at(safe+look,Vector3.UP)

func camera_safe_position(pivot:Vector3,desired:Vector3) -> Vector3:
	var segment:=desired-pivot; var length:=segment.length()
	if length<.001: return desired
	var direction:=segment/length; var allowed:=length
	for rect in sim.obstacles:
		var box:=AABB(Vector3(rect.position.x-.22,-.22,rect.position.y-.22),Vector3(rect.size.x+.44,Simulation.OBSTACLE_HEIGHT+.44,rect.size.y+.44))
		allowed=minf(allowed,_ray_box(pivot,direction,box,length)-.08)
	var result:=pivot+direction*maxf(.35,allowed)
	result.y=maxf(.28,result.y)
	return result

func _ray_box(origin:Vector3,direction:Vector3,box:AABB,max_distance:float=80.0) -> float:
	var near:=0.0; var far:=max_distance
	for axis in 3:
		if absf(direction[axis])<.000001:
			if origin[axis]<box.position[axis] or origin[axis]>box.end[axis]: return INF
		else:
			var a:float=(box.position[axis]-origin[axis])/direction[axis]
			var b:float=(box.end[axis]-origin[axis])/direction[axis]
			near=maxf(near,minf(a,b)); far=minf(far,maxf(a,b))
			if near>far: return INF
	return near if near<=max_distance and far>=0 else INF

func _update_aim() -> void:
	var center:=get_viewport().get_visible_rect().size*.5
	var origin:=camera.project_ray_origin(center); var direction:=camera.project_ray_normal(center)
	var nearest:=INF; aim_enemy=false; aim_direction=direction
	if direction.y<-.0001: nearest=minf(nearest,maxf(0.0,-origin.y/direction.y))
	for rect in sim.obstacles:
		nearest=minf(nearest,_ray_box(origin,direction,AABB(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.size.x,Simulation.OBSTACLE_HEIGHT,rect.size.y))))
	var enemy_spawn:Rect2=sim.spawn_zones[1]
	nearest=minf(nearest,_ray_box(origin,direction,AABB(Vector3(enemy_spawn.position.x,0,enemy_spawn.position.y),Vector3(enemy_spawn.size.x,30.0,enemy_spawn.size.y))))
	for actor in sim.actors:
		if not actor.alive or int(actor.team)==0: continue
		var pos:Vector2=actor.pos
		var hit:=_ray_box(origin,direction,AABB(Vector3(pos.x-.36,0,pos.y-.36),Vector3(.72,Simulation.ACTOR_HEIGHT,.72)))
		if hit<nearest: nearest=hit; aim_enemy=true
	for pod in sim.pods:
		if int(pod.team)==0: continue
		var pos:Vector2=pod.pos
		var hit:=_ray_box(origin,direction,AABB(Vector3(pos.x-.42,0,pos.y-.42),Vector3(.84,Simulation.POD_HEIGHT,.84)))
		if hit<nearest: nearest=hit; aim_enemy=true
	aim_has_hit=is_finite(nearest)
	aim_world=origin+direction*(maxf(.1,nearest) if aim_has_hit else 60.0)
	aim_target=Vector2(aim_world.x,aim_world.z)

func _handle_event(event:Dictionary) -> void:
	var kind:String=event.type
	var own:bool=int(event.get("id",-1))==0
	match kind:
		"shot":
			var velocity:Vector3=event.get("velocity",Vector3.ZERO)
			if velocity.length_squared()>.001: shot_pitches[int(event.get("id",0))]=atan2(velocity.y,Vector2(velocity.x,velocity.z).length())
			fx.shot(event)
			if own: play_sound("shoot",.11)
		"hit":
			_react_actor(int(event.get("id",-1)),"hit")
			if own: play_sound("hit",.13)
		"dash":
			if own: play_sound("dash")
		"defeat":
			_react_actor(int(event.get("id",-1)),"defeat")
			_add_effect(event,.72,1.1)
			if own: clear_input(); play_sound("defeat")
		"respawn":
			_react_actor(int(event.get("id",-1)),"respawn")
			shot_pitches.erase(int(event.get("id",-1)))
			_add_effect(event,.8,.85)
			if own: clear_input(); input_guard=.12; play_sound("respawn")
		"pod_placed":
			# event.id belongs to the pod; owner_id is the deploying animal.
			_react_actor(int(event.get("owner_id",-1)),"pod")
			play_sound("pod",.18)
		"pod_burst":
			fx.impact(event); _add_effect(event,1.0,3.2); play_sound("bloom",.15)
		"pod_destroyed": _add_effect(event,.38,.55); play_sound("hit",.15)
		"splash": fx.impact(event)

func _actor_animation_time(id:int) -> float:
	return elapsed+results_animation_elapsed+float(id)*.63

func _react_actor(id:int,kind:String) -> void:
	if not actor_cache.has(id): return
	var rig:Node3D=actor_cache[id]
	if not is_instance_valid(rig): return
	# Events can arrive between rendered frames. Stamp their actual game clock,
	# not a previous pose's timestamp or a wall-clock timer inside the imported rig.
	rig.set_meta("animation_clock",_actor_animation_time(id))
	Art.react_gardener(rig,kind)

func _update_turf(force:bool=false) -> void:
	if not force and terrain_revision==sim.grid_revision: return
	terrain_revision=sim.grid_revision
	# Simulation maintains RGB bytes in the very same ownership mutation path.
	# Only a native copy/upload is needed, even at 384×288 authoritative cells.
	turf_image.set_data(Simulation.GRID_W,Simulation.GRID_H,false,Image.FORMAT_RGB8,sim.coverage_rgb)
	turf_texture.update(turf_image)

func _sync_visuals(dt:float) -> void:
	if running and not paused and sim.state=="finished":
		results_animation_elapsed+=maxf(dt,0.0)
	for actor in sim.actors:
		var id:int=actor.id
		if not actor_cache.has(id):
			var rig:Node3D=Art.make_animal(ACTOR_SPECIES[posmod(id,ACTOR_SPECIES.size())],int(actor.team),id)
			rig.scale=Vector3.ONE*1.3; dynamic.add_child(rig); actor_cache[id]=rig
		var node:Node3D=actor_cache[id]; node.visible=actor.alive
		var pos:Vector2=actor.pos
		var old:Vector2=previous_positions.get(id,pos); var speed:=pos.distance_to(old)/maxf(dt,.001)
		previous_positions[id]=pos
		node.position=Vector3(pos.x,.04,pos.y)
		var facing:Vector2=actor.aim
		node.rotation.y=atan2(-facing.x,-facing.y)
		if not paused:
			var acting:bool=actor.alive and sim.state=="playing"
			Art.animate_gardener(node,_actor_animation_time(id),minf(speed/Simulation.MOVE_SPEED,1.0) if acting else 0.0,acting and float(actor.shot_cd)>.015,acting and float(actor.dash_left)>0)
			_apply_weapon_pitch(node,float(shot_pitches.get(id,camera_pitch if actor.is_player else 0.0)))
		# A paused frame must not re-select idle or accumulate aim offsets. The
		# imported AnimationPlayer is manual; no hidden engine delta advances it.
	fx.sync_projectiles(sim.projectiles,sim.actors,dt)
	# Kept as a bounded ID inventory for lifecycle instrumentation, not render nodes.
	projectile_cache.clear()
	for projectile in sim.projectiles: projectile_cache[int(projectile.id)]=true
	var active:Dictionary={}
	for pod in sim.pods:
		var id:int=pod.id; active[id]=true
		if not pod_cache.has(id):
			var flower:Node3D=Art.make_prop("seed_pod",int(pod.team)); dynamic.add_child(flower); pod_cache[id]=flower
		var node:Node3D=pod_cache[id]; node.position=Vector3(pod.pos.x,.06,pod.pos.y)
		var pulse:=1.0+.11*sin(elapsed*(9.0 if pod.fuse<1.0 else 4.0)); node.scale=Vector3.ONE*pulse; node.rotation.y=elapsed*.6
	_prune_cache(pod_cache,active)
	for i in range(effects.size()-1,-1,-1):
		var effect:Dictionary=effects[i]; effect.left-=dt
		if effect.left<=0:
			effect.node.free(); effects.remove_at(i)
		else:
			var fraction:float=effect.left/effect.total
			effect.node.scale=Vector3.ONE*effect.radius*(.5+.5*(1.0-fraction)); effect.node.position.y=.03+sin((1-fraction)*PI)*.18
			if fraction<.25: effect.node.scale*=fraction*4.0

func _apply_weapon_pitch(rig:Node3D,pitch:float) -> void:
	# Short animal paws hold the stationary receiver/U-grip. Only the articulated
	# front nozzle pivots; its separate Muzzle stays at the authoritative origin.
	# The art adapter owns skeletal pose and avoids the old rigid ArmR correction.
	Art.apply_gardener_aim_pitch(rig,clampf(pitch,-.75,.70))

func _add_effect(event:Dictionary,duration:float,radius:float) -> void:
	if effects.size()>=24: return
	var visual:Node3D=Art.make_bloom(int(event.get("team",0)),radius); dynamic.add_child(visual)
	var pos:Vector2=event.get("pos",Vector2.ZERO); visual.position=Vector3(pos.x,.05,pos.y)
	effects.append({"node":visual,"total":duration,"left":duration,"radius":radius})

func _prune_cache(cache:Dictionary,active:Dictionary) -> void:
	for id in cache.keys():
		if not active.has(id): cache[id].free(); cache.erase(id)

func _batch_static_arena(root_node:Node3D) -> void:
	# Repeated decorations and exact obstacle meshes become shared-material surfaces.
	# Vertex colors (including the material's sRGB flag) survive SurfaceTool append.
	var groups:Dictionary={}
	_collect_static(root_node,Transform3D.IDENTITY,groups)
	for child in root_node.get_children(): child.free()
	for group in groups.values():
		group.tool.index()
		var node:=MeshInstance3D.new(); node.name="MergedGreenhouse"; node.mesh=group.tool.commit(); node.material_override=group.material; root_node.add_child(node)
	root_node.set_meta("static_draw_batches",groups.size())

func _collect_static(node:Node3D,parent_transform:Transform3D,groups:Dictionary) -> void:
	var transform:=parent_transform*node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material:Material=node.material_override if node.material_override else node.mesh.surface_get_material(surface)
			var key:int=material.get_instance_id() if material else 0
			if not groups.has(key):
				var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); groups[key]={"tool":st,"material":material}
			groups[key].tool.append_from(node.mesh,surface,transform)
	for child in node.get_children():
		if child is Node3D: _collect_static(child,transform,groups)

func _stop_actor_animations() -> void:
	for rig in actor_cache.values():
		if not is_instance_valid(rig): continue
		# Also quiesce imported descendants before host routing frees this scene.
		rig.process_mode=Node.PROCESS_MODE_DISABLED
		for player:AnimationPlayer in rig.find_children("*","AnimationPlayer",true,false):
			player.stop(true)
			player.active=false

func _clear_dynamic() -> void:
	_stop_actor_animations()
	if fx: fx.reset()
	for child in dynamic.get_children(): child.free()
	actor_cache.clear(); projectile_cache.clear(); pod_cache.clear(); effects.clear()

func _update_hud() -> void:
	if sim.actors.is_empty(): return
	var player:Dictionary=sim.actors[0]; var tags:Array=[]; var roster:Array=[]
	for actor in sim.actors:
		roster.append({"team":int(actor.team),"alive":bool(actor.alive),"player":bool(actor.is_player)})
		if actor.alive and not actor.is_player and not camera.is_position_behind(Vector3(actor.pos.x,1.7,actor.pos.y)):
			tags.append({"pos":camera.unproject_position(Vector3(actor.pos.x,2.15,actor.pos.y)),"hp":float(actor.hp)/100.0,"color":TEAM_COLORS[int(actor.team)],"player":actor.is_player})
	for pod in sim.pods:
		tags.append({"pos":camera.unproject_position(Vector3(pod.pos.x,.8,pod.pos.y)),"hp":float(pod.hp)/Simulation.POD_HP,"color":TEAM_COLORS[int(pod.team)],"fuse":float(pod.fuse)/Simulation.POD_FUSE})
	hud.update_state({"pointer_active":pointer_active or demo_mode,"aim_enemy":aim_enemy,"green":sim.score[0],"coral":sim.score[1],"time":sim.time_left,"hp":player.hp,"water":player.water,"dash_cd":player.dash_cd,"pod_cd":player.pod_cd,"alive":player.alive,"respawn":player.respawn_left,"countdown":countdown_left,"paused":paused,"finished":sim.state=="finished","winner":sim.winner,"audio":audio_enabled,"best":best_coverage,"wins":wins,"tags":tags,"roster":roster})

func play_sound(sound_name:String,throttle:float=0.0) -> void:
	if not audio_enabled or not sounds.has(sound_name): return
	var now:=Time.get_ticks_msec()/1000.0
	if now-float(sound_throttle.get(sound_name,-100.0))<throttle: return
	sound_throttle[sound_name]=now; sounds[sound_name].play()

func toggle_audio() -> void:
	audio_enabled=not audio_enabled; save_data(); _sync_audio_pause()
	if audio_enabled: play_sound("ui_click")
	_update_hud()

func _sync_audio_pause() -> void:
	if music:
		if audio_enabled and running and not music.playing: music.play()
		music.stream_paused=paused or not audio_enabled
	for voice in sounds.values():
		if paused or not audio_enabled: voice.stop()

func leave_game() -> void:
	if not running: return
	save_data(); running=false; paused=false; _release_mouse(); clear_input(); fixed_accumulator=0.0
	_stop_actor_animations()
	set_process(false); set_process_input(false); set_process_unhandled_input(false)
	if music: music.stop()
	for voice in sounds.values(): voice.stop()
	hud.hide(); hud.set_process(false); fx.reset(); restore_render_quality()
	if get_tree().current_scene==self and exit_requested.get_connections().is_empty():
		request_application_quit()
	else: exit_requested.emit()

func configure_render_quality() -> void:
	if not viewport_settings.is_empty(): return
	var adapter:=RenderingServer.get_video_adapter_name().to_lower()
	if "llvmpipe" in adapter or "softpipe" in adapter or "swiftshader" in adapter or "software" in adapter:
		var viewport:=get_viewport(); viewport_settings={"msaa":viewport.msaa_3d,"scale":viewport.scaling_3d_scale}
		viewport.msaa_3d=Viewport.MSAA_DISABLED; viewport.scaling_3d_scale=.80

func restore_render_quality() -> void:
	if viewport_settings.is_empty(): return
	var viewport:=get_viewport()
	if viewport:
		viewport.msaa_3d=viewport_settings.msaa; viewport.scaling_3d_scale=viewport_settings.scale
	viewport_settings.clear()

func load_data() -> void:
	save_write_allowed=true; best_coverage=0.0; wins=0; matches=0; audio_enabled=true; save_extras={}
	if save_service and save_service.has_method("load_game"):
		var injected=save_service.call("load_game",GAME_ID)
		if injected!=null: apply_saved_data(injected)
		return
	if FileAccess.file_exists(SAVE_PATH):
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(SAVE_PATH))!=OK:
			_disable_save("Unreadable save preserved"); return
		apply_saved_data(parser.data)

func apply_saved_data(data:Variant) -> void:
	if not data is Dictionary:
		_disable_save("Unreadable save preserved"); return
	var version:Variant=data.get("schema_version",1)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version)!=1.0:
		_disable_save("Unknown save schema preserved"); return
	var best:Variant=data.get("best_coverage",0.0); var won:Variant=data.get("wins",0); var played:Variant=data.get("matches",0)
	if not (best is int or best is float) or not (won is int or won is float) or not (played is int or played is float):
		_disable_save("Invalid score data preserved"); return
	if not is_finite(float(best)) or not is_finite(float(won)) or not is_finite(float(played)) or float(best)<0 or float(best)>100 or float(won)<0 or float(played)<0 or float(won)>float(played) or float(played)>1000000000 or float(won)!=floorf(float(won)) or float(played)!=floorf(float(played)):
		_disable_save("Out-of-range score data preserved"); return
	var enabled:Variant=data.get("audio_enabled",true)
	if not enabled is bool: _disable_save("Invalid settings preserved"); return
	best_coverage=float(best); wins=int(won); matches=int(played); audio_enabled=enabled; save_extras=data.duplicate(true)

func _disable_save(reason:String) -> void:
	save_write_allowed=false; push_warning("Bloom Skirmish: "+reason+"; automatic writes disabled.")

func save_data() -> void:
	if not save_write_allowed: return
	var data:=save_extras.duplicate(true); data.merge({"schema_version":1,"best_coverage":best_coverage,"wins":wins,"matches":matches,"audio_enabled":audio_enabled},true)
	if save_service and save_service.has_method("save_game"):
		save_service.call("save_game",GAME_ID,data); return
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR)!=OK: return
	var file:=FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(data)); file.close()
	var error:=DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)
	if error!=OK: push_warning("Bloom Skirmish: unable to atomically save profile: %s"%error)

func _capture_viewport() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree() and not capture_path.is_empty():
		var image:=get_viewport().get_texture().get_image()
		print("BLOOM CAPTURE ",capture_path," result=",image.save_png(capture_path))

func _capture_movie_frame() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree() and not movie_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(movie_dir)
		get_viewport().get_texture().get_image().save_png(movie_dir.path_join("frame_%04d.png"%movie_frames))
		movie_frames+=1
		if movie_frames==movie_frame_limit:
			print("BLOOM MOVIE captured ",movie_frame_limit," real frames; sample_fps=",record_fps," fixed_simulation=",record_fixed," path=",movie_dir)
			if record_fixed: request_application_quit()
	movie_pending=false

func request_application_quit() -> void:
	if window_shutdown_pending: return
	window_shutdown_pending=true
	_stop_actor_animations()
	if quit_handler.is_valid():
		quit_handler.call(); return
	# Standalone close follows the same complete cleanup as host exit, without
	# emitting a route-change signal or letting active audio outlive its players.
	if running: save_data()
	running=false; paused=false; _release_mouse()
	set_process(false); set_process_input(false); set_process_unhandled_input(false)
	if music: music.stop()
	for voice in sounds.values(): voice.stop()
	if fx: fx.reset()
	var tree:=get_tree()
	tree.create_timer(.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	_stop_actor_animations()
	if owns_quit_policy and get_tree(): get_tree().auto_accept_quit=previous_auto_accept_quit
	_release_mouse(); clear_input(); restore_render_quality()
	if music: music.stop()
	for voice in sounds.values(): voice.stop()
	if running: save_data()
	running=false
