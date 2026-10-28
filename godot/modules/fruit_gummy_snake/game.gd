extends Node3D
signal exit_requested
const Simulation=preload("sim.gd")
const Store=preload("store.gd")
const Art=preload("art/underwater_art.gd")
const HUD=preload("ui/gummy_hud.gd")
const GAME_ID:="fruit_gummy_snake"
var sim=Simulation.new()
var store=Store.new()
var art=Art.new()
var has_started:=false
var running:=false
var paused:=false
var accounted:=false
var closing:=false
var profile:=Store.fresh()
var boundary_grid:MeshInstance3D
var camera:Camera3D
var hud:Control
var snake_root:Node3D
var fruit_root:Node3D
var pieces:Array[Node3D]=[]
var body_batch:MultiMeshInstance3D
var shine_batch:MultiMeshInstance3D
var fruit_nodes:Dictionary={}
var music:AudioStreamPlayer
var sfx:AudioStreamPlayer
var sound_on:=true
var countdown:=3.0
var view_time:=0.0
var bite_age:=100.0
var seed_value:=1847
var pressed:Dictionary={}
var previous_mouse_mode:=Input.MOUSE_MODE_VISIBLE
var previous_auto_accept:=true
var quit_handler:Callable
var capture_path:=""
var capture_after:=1.5
var capture_done:=false
var preview:=false
var standalone:=false

func _ready() -> void:
	_build()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snake-capture="):capture_path=arg.trim_prefix("--snake-capture=");preview=true
		if arg=="--snake-preview":preview=true
	call_deferred("autostart")

func autostart() -> void:
	if not has_started:start({})

func _build() -> void:
	add_child(art.ocean())
	boundary_grid=MeshInstance3D.new();boundary_grid.name="WaterBoundaryWarning";add_child(boundary_grid)
	var grid_material:=StandardMaterial3D.new();grid_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;grid_material.vertex_color_use_as_albedo=true;grid_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;grid_material.no_depth_test=false;boundary_grid.material_override=grid_material
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=68;camera.position=Vector3(0,15,7);add_child(camera);camera.current=true;camera.far=100;camera.near=.15
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("387f9d");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("b7e3e3");environment.ambient_light_energy=.45;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.tonemap_exposure=.9;environment.fog_enabled=true;environment.fog_light_color=Color("559eac");environment.fog_density=.009;camera.environment=environment
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-58,-25,0);sun.light_energy=.65;sun.light_color=Color("fff8ef");sun.shadow_enabled=true;sun.directional_shadow_max_distance=45;add_child(sun)
	snake_root=art.snake();snake_root.name="UnderwaterSnake";add_child(snake_root)
	fruit_root=Node3D.new();fruit_root.name="CollectibleGummies";add_child(fruit_root)
	var canvas:=CanvasLayer.new();add_child(canvas);hud=HUD.new();canvas.add_child(hud)
	hud.pause_requested.connect(func():set_paused(true));hud.resume_requested.connect(func():set_paused(false));hud.retry_requested.connect(restart);hud.home_requested.connect(leave_game);hud.sound_requested.connect(toggle_sound);hud.collection_requested.connect(func():set_paused(true);hud.collection_open=true;_refresh_hud())
	music=AudioStreamPlayer.new();music.stream=preload("audio/fruit_loop.wav");music.stream=music.stream.duplicate();music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;music.stream.loop_end=705600;music.volume_db=-19;add_child(music)
	sfx=AudioStreamPlayer.new();sfx.volume_db=-13;add_child(sfx)

func start(context:Dictionary={}) -> void:
	if has_started:return
	has_started=true;running=true;paused=false;closing=false;accounted=false;countdown=3.0
	standalone=get_tree().current_scene==self and exit_requested.get_connections().is_empty()
	hud.standalone=standalone
	previous_mouse_mode=Input.mouse_mode;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	previous_auto_accept=get_tree().auto_accept_quit;get_tree().auto_accept_quit=false
	if context.get("quit_handler") is Callable:quit_handler=context.quit_handler
	seed_value=int(context.get("seed",Time.get_ticks_usec()%2147483647))
	store.load_profile(context);profile=store.profile.duplicate(true)
	sim.start(seed_value)
	if preview:
		# Preview freezes a normal new game. No manufactured score/length/success.
		paused=true
		print("FRUIT PREVIEW RENDER: lights=",get_tree().root.find_children("*","DirectionalLight3D",true,false).size()," tonemap=",camera.environment.tonemap_mode," exposure=",camera.environment.tonemap_exposure," ambient=",camera.environment.ambient_light_energy)
	if sound_on:music.play()
	_update_view();_refresh_hud()

func _process(delta:float) -> void:
	if not running:return
	if not is_finite(delta) or delta<0:return
	view_time+=delta
	if not paused and sim.alive:
		var play_delta:=delta
		if countdown>0:
			var consumed:=minf(countdown,play_delta);countdown-=consumed;play_delta-=consumed
		sim.tick(play_delta);bite_age+=play_delta
		for event in sim.drain_events():
			if event.type=="eat":bite_age=0;_sound("bite");hud.toast="%s软糖 +%d"%[["苹果","橘瓣","草莓","葡萄","西瓜"][int(event.kind)],int(event.points)];hud.toast_time=1.8
			if event.type=="salad":hud.toast="水果沙拉！ +30";hud.toast_time=2;_sound("salad")
			if event.type=="result":_record();_sound("win" if sim.won else "end");music.stream_paused=true
		_update_view()
	if hud.toast_time>0 and not paused:
		hud.toast_time-=delta
		if hud.toast_time<=0:hud.toast=""
	_refresh_hud()
	if not capture_path.is_empty() and not capture_done and view_time>=capture_after:
		capture_done=true;_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)

func _refresh_hud() -> void:
	if is_instance_valid(hud):
		var state:Dictionary=sim.snapshot();state.countdown=countdown if not preview else 0.0
		var nearest:Dictionary={};var distance:=INF
		for food in sim.foods:
			var d:float=sim.head.distance_to(food.position)
			if d<distance:distance=d;nearest=food
			if bool(food.get("intro",false)):distance=d;nearest=food;break
		if not nearest.is_empty():
			var p:Vector3=nearest.position;state.target_distance=distance;state.target_height=p.y-sim.head.y
			state.target_screen=camera.unproject_position(p) if not camera.is_position_behind(p) else Vector2(-1,-1)
			state.target_behind=camera.is_position_behind(p)
			var flat:Vector3=(p-sim.head)*Vector3(1,0,1);var facing:Vector3=sim.forward*Vector3(1,0,1)
			state.target_hint="前方" if facing.normalized().dot(flat.normalized())>.92 else ("右转寻找" if facing.cross(flat).y<0 else "左转寻找")
		hud.present(state,profile,paused and not preview,store.warning)

func _update_view() -> void:
	art.update_snake(snake_root,sim.body,sim.forward,view_time)
	_update_boundary()
	var right:Vector3=sim.forward.cross(Vector3.UP).normalized()
	var target:Vector3=sim.head-sim.forward*7.5+Vector3.UP*3.3+right*2.6
	var candidates:Array[Vector3]=[target,sim.head-sim.forward*7.5+Vector3.UP*3.3-right*2.6,sim.head-sim.forward*10+Vector3.UP*5+right*4,sim.head-sim.forward*10+Vector3.UP*5-right*4]
	var found:=false
	for candidate in candidates:
		candidate.y=clampf(candidate.y,1.0,27.3)
		if _camera_clear(candidate,true):target=candidate;found=true;break
	if not found:
		# A long coil can block every shoulder position. Search around the head,
		# including front-side positions, rather than falling through to an unsafe one.
		for radius in [7.5,4.0,2.2,11.0]:
			if found:break
			for elevation in [.55,-.45,1.05,0.0]:
				if found:break
				for turn in 12:
					var angle:=float(turn)*TAU/12
					var offset:Vector3=Vector3(cos(angle)*cos(elevation),sin(elevation),sin(angle)*cos(elevation))*radius
					var candidate:Vector3=sim.head+offset;candidate.y=clampf(candidate.y,1.0,27.3)
					if _camera_clear(candidate,true):target=candidate;found=true;break
	if not found and _camera_clear(camera.position,true):target=camera.position
	var smooth:Vector3=camera.position.lerp(target,1-exp(-get_process_delta_time()*7))
	camera.position=smooth if _camera_clear(smooth,true) else target
	var look:Vector3=sim.head+sim.forward*.6
	if camera.position.distance_to(look)>.1:camera.look_at(look,Vector3.UP)
	var active:=[]
	for food in sim.foods:
		var id:int=int(food.id);active.append(id)
		if not fruit_nodes.has(id):var n:Node3D=art.fruit(int(food.kind));fruit_root.add_child(n);fruit_nodes[id]=n
		fruit_nodes[id].position=food.position
		fruit_nodes[id].rotation.y=view_time*.35+id
		var pulse:=1.0+sin(view_time*3+id)*.035
		if int(food.kind)==4 and float(food.expires)-sim.elapsed<3:pulse=1+sin(view_time*10)*.10
		fruit_nodes[id].scale=Vector3.ONE*pulse
	for id in fruit_nodes.keys():
		if not active.has(id):fruit_nodes[id].queue_free();fruit_nodes.erase(id)

func _camera_clear(at:Vector3,check_view:bool)->bool:
	for i in range(1,sim.body.size()-1):
		if Simulation.point_segment_distance(at,sim.body[i],sim.body[i+1])<1.35:return false
		if check_view and i>=3 and Simulation.segment_distance(at,sim.head,sim.body[i],sim.body[i+1])<.50:return false
	return true

func _update_boundary()->void:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	for axis in 3:
		for side in [-1,1]:
			var limit:=float(side)*24 if axis!=1 else (2.0 if side<0 else 26.0)
			var distance:float=absf(sim.head[axis]-limit)
			if distance>6:continue
			var color:=Color(.75,.94,.96,clampf((6-distance)/5,.08,.8))
			if distance<2:color=Color(1,.73,.45,.8)
			var a:=(axis+1)%3;var b:=(axis+2)%3
			var min_a:=2.0 if a==1 else -24.0;var max_a:=26.0 if a==1 else 24.0
			var min_b:=2.0 if b==1 else -24.0;var max_b:=26.0 if b==1 else 24.0
			for i in range(int((max_a-min_a)/3)+1):
				var p:=Vector3.ZERO;var q:=Vector3.ZERO;p[axis]=limit;q[axis]=limit;p[a]=min_a+i*3;q[a]=p[a];p[b]=min_b;q[b]=max_b
				vertices.append(p);vertices.append(q);colors.append(color);colors.append(color)
			for i in range(int((max_b-min_b)/3)+1):
				var p:=Vector3.ZERO;var q:=Vector3.ZERO;p[axis]=limit;q[axis]=limit;p[b]=min_b+i*3;q[b]=p[b];p[a]=min_a;q[a]=max_a
				vertices.append(p);vertices.append(q);colors.append(color);colors.append(color)
	boundary_grid.visible=not vertices.is_empty()
	if vertices.is_empty():return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays);boundary_grid.mesh=mesh

func _apply_controls()->void:
	var turn:=float(pressed.has(KEY_D) or pressed.has(KEY_RIGHT))-float(pressed.has(KEY_A) or pressed.has(KEY_LEFT))
	var tilt:=float(pressed.has(KEY_SPACE) or pressed.has(KEY_UP))-float(pressed.has(KEY_C) or pressed.has(KEY_DOWN))
	var throttle:=float(pressed.has(KEY_W))-float(pressed.has(KEY_S))
	sim.set_controls(turn,tilt,throttle)

func _input(event:InputEvent) -> void:
	if not running or not event is InputEventKey:return
	var key:=int(event.physical_keycode)
	if key==0:key=int(event.keycode)
	if not event.pressed:pressed.erase(key);_apply_controls();return
	if event.echo or pressed.has(key):return
	if key==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if hud.collection_open:
			hud.collection_open=false;set_paused(false);return
		if hud.cancel_confirmation():return
		if sim.alive:set_paused(not paused)
		return
	if paused or not sim.alive:return
	pressed[key]=true
	if key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_C]:
		get_viewport().set_input_as_handled();_apply_controls()

func set_paused(value:bool) -> void:
	if not running or not sim.alive:return
	paused=value
	if not value:preview=false
	hud.collection_open=false;pressed.clear();sim.set_controls(0,0,0);hud.confirmation=false;music.stream_paused=paused;_refresh_hud()

func restart() -> void:
	if not running:return
	_record();seed_value+=1;sim.start(seed_value);countdown=3.0;paused=false;preview=false;accounted=false;pressed.clear();camera.position=Vector3(0,15,7);hud.confirmation=false;hud.toast="";bite_age=100
	if sound_on:music.play()
	_update_view();_refresh_hud()

func _record() -> void:
	if accounted or preview:return
	accounted=true
	profile.best_score=maxi(int(profile.best_score),sim.score);profile.longest=maxi(int(profile.longest),sim.longest);profile.rounds=mini(1000000000,int(profile.rounds)+1)
	for i in 5:profile.fruit_counts[i]=mini(1000000000000,int(profile.fruit_counts[i])+int(sim.collected[i]))
	store.write_profile(profile)

func leave_game() -> void:
	if not running:return
	_record();running=false;pressed.clear();sim.set_controls(0,0,0);music.stop();sfx.stop();Input.mouse_mode=previous_mouse_mode;set_process(false);set_process_input(false)
	var tree:=get_tree()
	if standalone:tree.create_timer(.5).timeout.connect(tree.quit)
	exit_requested.emit()

func toggle_sound() -> void:
	sound_on=not sound_on;hud.sound_button.text="音乐 开" if sound_on else "音乐 关"
	if sound_on and running and sim.alive:music.play();music.stream_paused=paused
	else:music.stop();sfx.stop()

func _sound(name_value:String) -> void:
	if not sound_on:return
	sfx.stream=load("res://modules/fruit_gummy_snake/audio/"+name_value+".wav");sfx.play()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running and sim.alive:set_paused(true)
	if what==NOTIFICATION_WM_CLOSE_REQUEST and running and not closing:
		closing=true;_record();music.stop();sfx.stop();running=false
		if quit_handler.is_valid():quit_handler.call()
		else:
			var tree:=get_tree();tree.create_timer(.5).timeout.connect(tree.quit)

func _exit_tree() -> void:
	if is_instance_valid(music):music.stop()
	if is_instance_valid(sfx):sfx.stop()
	if has_started:
		Input.mouse_mode=previous_mouse_mode
		if get_tree():get_tree().auto_accept_quit=previous_auto_accept
