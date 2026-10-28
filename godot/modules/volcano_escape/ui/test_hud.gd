extends SceneTree
const HUD = preload("res://modules/volcano_escape/ui/rescue_hud.gd")
const AUDIO = preload("res://modules/volcano_escape/audio/rescue_audio.gd")
var retries := 0
var homes := 0
var pauses: Array = []
func key(code: Key, echo := false) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.pressed=true; e.echo=echo
	root.push_input(e)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var hud := HUD.new(); root.add_child(hud)
	hud.retry_requested.connect(func(): retries+=1)
	hud.home_requested.connect(func(): homes+=1)
	hud.pause_requested.connect(func(v: bool): pauses.append(v))
	for viewport in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(960,540),Vector2i(640,360)]:
		root.content_scale_size=viewport; root.size=viewport
		hud.reset()
		hud.update_snapshot({"status":"running","time":15,"health":3})
		await process_frame
		key(KEY_ESCAPE); await process_frame
		assert(hud.overlay=="pause" and pauses.back()==true)
		key(KEY_ENTER,true); assert(hud.overlay=="pause")
		key(KEY_ENTER); assert(hud.overlay=="" and pauses.back()==false)
		key(KEY_ESCAPE); await process_frame
		key(KEY_DOWN); key(KEY_ENTER); assert(hud.overlay=="retry")
		key(KEY_ENTER); assert(hud.overlay=="pause")
		await process_frame
		key(KEY_DOWN); key(KEY_ENTER); await process_frame
		key(KEY_DOWN); key(KEY_ENTER); key(KEY_ENTER)
		assert(retries==[Vector2i(1280,720),Vector2i(1024,768),Vector2i(960,540),Vector2i(640,360)].find(viewport)+1)
		hud.reset(); assert(not hud.action_latched and hud.overlay=="")
		# Pointer path: double click must not leak through to newly opened menu.
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
		click.position=Vector2(hud.size.x-24*hud._scale,24*hud._scale)
		root.push_input(click); await process_frame
		assert(hud.overlay=="pause")
		click.double_click=true
		click.position=(hud._buttons[1].get_center())*hud._scale
		root.push_input(click); assert(hud.overlay=="pause")
		# Keyboard focus-style selection wraps and is visible in custom menu.
		key(KEY_TAB); assert(hud.selection==1)
		key(KEY_TAB); assert(hud.selection==2)
		key(KEY_TAB); assert(hud.selection==0)
		# Pointer resume is a real viewport event, not direct method invocation.
		click.double_click=false
		click.position=hud._buttons[0].get_center()*hud._scale
		root.push_input(click); assert(hud.overlay=="" and pauses.back()==false)
		hud.update_snapshot({"status":"success","time":84,"health":3,"result":{"exit":"boat"},"beacons":[]})
		await process_frame
		assert(hud.overlay=="result")
		key(KEY_DOWN); key(KEY_ENTER); key(KEY_ENTER)
		assert(homes==retries)
		assert(hud.snapshot_data.exit_name=="南港渡船")
	# Fixed pool and paused retirement; weak ownership must not remain alive.
	for i in 12:
		var audio := AUDIO.new(); root.add_child(audio); audio.start_music()
		for j in 50: audio.play_cue("rock")
		assert(audio.voices.size()==6 and audio.get_child_count()==7)
		audio.set_paused(true); paused=true
		if i==11: Engine.max_fps=5
		var ref: WeakRef = weakref(audio)
		if i==10: audio.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		audio.shutdown(); audio.shutdown()
		await process_frame
		assert(ref.get_ref()==null)
		paused=false
		Engine.max_fps=0
	hud.queue_free(); await process_frame
	await create_timer(.15, true).timeout
	print("PASS Volcano HUD: 4 resolutions, actual push_input keyboard, held suppression, confirmation cancel, duplicate commit latch, reset, results; audio fixed pool and 12 paused retirements")
	quit()
