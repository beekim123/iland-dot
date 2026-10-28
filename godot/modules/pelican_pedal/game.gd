extends Node3D
signal exit_requested
const Sim = preload("sim.gd")
const Map = preload("data/map.gd")
const Store = preload("storage.gd")
const Hud = preload("ui/pelican_hud.gd")
const FIXED_DT := 1.0/60.0
var sim=Sim.new()
var store=Store.new()
var profile: Dictionary={}
var world: Node3D
var rider: Node3D
var camera: Camera3D
var hud: Control
var music: AudioStreamPlayer
var cue: AudioStreamPlayer
var running:=false
var has_started:=false
var paused:=false
var comfort:=true
var keys: Dictionary={}
var interact_pending:=false
var look_held:=false
var look_yaw:=0.0
var look_pitch:=0.0
var accumulator:=0.0
var autosave:=0.0
var save_status: String=""
var previous_mouse_mode:=Input.MOUSE_MODE_VISIBLE
var previous_quit:=true
var quit_pending:=false
var result_shown:=false
var cargo_items:Array[Node3D]=[]
func _ready() -> void:
	world=load("res://modules/pelican_pedal/world.gd").new();add_child(world)
	rider=Node3D.new();add_child(rider)
	if ResourceLoader.exists("res://modules/pelican_pedal/art/pelican_bicycle.gd"):
		var visual=load("res://modules/pelican_pedal/art/pelican_bicycle.gd").new();visual.name="RiderVisual";rider.add_child(visual)
	_build_cargo()
	camera=Camera3D.new();camera.position=Vector3(0,1.68,-.12);camera.near=.05;camera.far=150;camera.fov=72;rider.add_child(camera);camera.current=true
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("a1d6dc");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("d6e2eb");environment.ambient_light_energy=.18;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;camera.environment=environment
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-25,0);sun.light_color=Color("fff9ef");sun.light_energy=.35;sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=80;add_child(sun)
	var layer:=CanvasLayer.new();add_child(layer);hud=Hud.new();layer.add_child(hud);hud.bind(self)
	hud.pause_requested.connect(func():set_paused(true));hud.resume_requested.connect(func():set_paused(false));hud.home_requested.connect(leave_game);hud.retry_requested.connect(retry);hud.next_requested.connect(next_job);hud.comfort_changed.connect(func(v):comfort=v;save_data())
	music=AudioStreamPlayer.new();add_child(music);music.volume_db=-19
	if ResourceLoader.exists("res://modules/pelican_pedal/audio/theme.wav"):music.stream=load("res://modules/pelican_pedal/audio/theme.wav")
	music.finished.connect(func():if running:music.play())
	cue=AudioStreamPlayer.new();add_child(cue);cue.volume_db=-12
	call_deferred("autostart")
func autostart() -> void:
	if not has_started:start({})
func start(context: Dictionary = {}) -> void:
	if running:return
	has_started=true;previous_mouse_mode=Input.mouse_mode;previous_quit=get_tree().auto_accept_quit;get_tree().auto_accept_quit=false
	profile=store.load_profile(context);comfort=profile.comfort
	sim.start()
	if not profile.snapshot.is_empty():sim.restore(profile.snapshot)
	running=true;paused=false;quit_pending=false;result_shown=false;accumulator=0;autosave=0;clear_input();set_process(true);set_process_unhandled_input(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if music.stream:music.play()
	_present(0)
	if sim.phase in ["complete","failed"]:_show_result()
func clear_input() -> void:
	keys.clear();interact_pending=false;look_held=false;sim.command({})
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _unhandled_input(event: InputEvent) -> void:
	if not running:return
	if event is InputEventKey:
		if event.echo:return
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_ESCAPE and event.pressed:
			var viewport:=get_viewport();viewport.set_input_as_handled()
			if sim.phase in ["complete","failed"]:return
			if hud.menu_kind=="retry_confirm":hud.show_menu("pause")
			else:set_paused(not paused)
			return
		if not paused and sim.phase in ["pickup","delivery"]:
			if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_R]:keys[code]=event.pressed
			if code==KEY_E and event.pressed:interact_pending=true
			if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_R,KEY_E]:get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		look_held=event.pressed and not paused and sim.phase in ["pickup","delivery"]
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if look_held else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and look_held:
		look_yaw=clampf(look_yaw-event.relative.x*.003,-1.5,1.5)
		look_pitch=clampf(look_pitch-event.relative.y*.003,-.75,.65)
		get_viewport().set_input_as_handled()
	# GUI buttons activate on release; consume their unhandled press after GUI dispatch.
	if paused or sim.phase in ["complete","failed"]:
		var viewport:=get_viewport()
		if is_instance_valid(viewport):viewport.set_input_as_handled()
func _process(dt: float) -> void:
	if not running:return
	if not paused and sim.phase in ["pickup","delivery"]:
		accumulator+=maxf(0,dt)
		var steps:=0
		while accumulator>=FIXED_DT and steps<240:
			sim.command({"throttle":float(keys.get(KEY_W,false))-float(keys.get(KEY_S,false)),"steer":float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),"brake":keys.get(KEY_SPACE,false),"reset":keys.get(KEY_R,false),"interact":interact_pending})
			interact_pending=false;sim.tick(FIXED_DT);accumulator-=FIXED_DT;steps+=1
			_handle_events()
			if sim.phase in ["complete","failed"]:break
		autosave+=dt
		if autosave>=3:autosave=0;save_data()
	_present(dt)
func _handle_events() -> void:
	for event: Dictionary in sim.drain_events():
		if event.type in ["pickup","delivery","collision","reset","complete","failed"]:play_cue(event.type)
		if event.type=="complete":
			if int(profile.completed)<=sim.job_index:
				profile.completed=sim.job_index+1;profile.total_score=int(profile.total_score)+sim.score()
			save_data();_show_result()
		elif event.type=="failed":save_data();_show_result()
func _show_result() -> void:
	result_shown=true;clear_input();hud.show_menu(sim.phase);music.stream_paused=true
func _present(dt: float) -> void:
	rider.process_mode=Node.PROCESS_MODE_DISABLED if paused or sim.phase in ["complete","failed"] else Node.PROCESS_MODE_INHERIT
	rider.position=Vector3(sim.pos.x,Map.height_at(sim.pos),sim.pos.y);rider.rotation.y=sim.yaw
	var visual=rider.get_node_or_null("RiderVisual")
	if visual and visual.has_method("set_motion"):visual.set_motion(sim.speed,float(sim.input.steer),bool(sim.input.brake),dt if not paused else 0)
	if not look_held:
		look_yaw=move_toward(look_yaw,0,dt*2.4);look_pitch=move_toward(look_pitch,0,dt*1.5)
	camera.rotation=Vector3(-.35+look_pitch,look_yaw,0)
	camera.position.y=1.68+(sin(sim.elapsed*5)*minf(absf(sim.speed),4)*.006 if not comfort else 0)
	for i in cargo_items.size():cargo_items[i].visible=sim.phase=="delivery" and i<sim.deliveries.size()-sim.delivered
	world.update(sim);save_status=store.status;hud.update()
func set_paused(value: bool) -> void:
	if not running or sim.phase not in ["pickup","delivery"]:return
	paused=value;clear_input();accumulator=0;music.stream_paused=value;cue.stream_paused=value;hud.show_menu("pause" if value else "")
	if value:save_data()
func retry() -> void:
	if not running:return
	sim.start(sim.job_index,sim.seed_value);paused=false;result_shown=false;accumulator=0;clear_input();hud.show_menu("");music.stream_paused=false;cue.stream_paused=false;save_data()
func next_job() -> void:
	if not running or sim.phase!="complete":return
	sim.start(sim.job_index+1,sim.seed_value);paused=false;result_shown=false;accumulator=0;clear_input();hud.show_menu("");music.stream_paused=false;cue.stream_paused=false;save_data()
func save_data() -> bool:
	if profile.is_empty():return false
	profile.snapshot=sim.snapshot();profile.comfort=comfort
	var success:=store.save(profile);save_status=store.status
	if is_instance_valid(hud):hud.update()
	return success
func play_cue(kind: String) -> void:
	var path:="res://modules/pelican_pedal/audio/"+kind+".wav"
	if ResourceLoader.exists(path):cue.stream=load(path);cue.play()
func leave_game() -> void:
	if not running:return
	var viewport:=get_viewport()
	var standalone:=get_tree().current_scene==self
	if is_instance_valid(viewport):viewport.set_input_as_handled()
	save_data();running=false;paused=true;clear_input();music.stop();cue.stop();set_process(false);set_process_unhandled_input(false);hud.hide();Input.mouse_mode=previous_mouse_mode
	get_tree().auto_accept_quit=previous_quit
	if standalone:request_application_quit()
	exit_requested.emit()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running:set_paused(true)
	elif what==NOTIFICATION_WM_CLOSE_REQUEST and has_started:request_application_quit()
func request_application_quit() -> void:
	if quit_pending:return
	quit_pending=true
	if running:save_data();running=false;music.stop();cue.stop();clear_input()
	var tree:=get_tree()
	await tree.create_timer(.3).timeout
	tree.quit()
func _exit_tree() -> void:
	if running:save_data();running=false
	if is_instance_valid(music):music.stop()
	if is_instance_valid(cue):cue.stop()
	if has_started and get_tree():get_tree().auto_accept_quit=previous_quit
	if has_started:Input.mouse_mode=previous_mouse_mode

func _build_cargo() -> void:
	for i in 3:
		var parcel:=Node3D.new();parcel.name="Parcel"+str(i);rider.add_child(parcel)
		parcel.position=Vector3((-.09 if i%2==0 else .09) if i<2 else 0, .87+floori(i/2.0)*.14,-.83)
		world.box(Vector3.ZERO,Vector3(.16,.13,.20),["b9784f","568994","a1696c"][i],parcel)
		world.box(Vector3.ZERO,Vector3(.025,.135,.205),"dcc996",parcel)
		parcel.visible=false;cargo_items.append(parcel)
