extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var env=load("res://modules/monkey_vine/art/environment/jungle_environment.gd").new(); root.add_child(env)
	var snap={"segment":0,"platforms":[{"id":"p","rect":Rect2(-2,-2,5,2)}],"vines":[{"id":"v","anchor":Vector2(4,6),"tip":Vector2(5,1),"length":5.0,"warning":false}],"collectibles":[{"id":"f","pos":Vector2(3,1),"collected":false}],"exit_rect":Rect2(10,0,2,2)}
	env.build(snap)
	var count=env.terrain.get_child_count()
	for i in range(180): env.update_snapshot(snap,1.0/60)
	assert(env.terrain.get_child_count()==count)
	assert(env.ropes.v.get_child_count()==12)
	assert(env.ropes.v.get_child(8).position.distance_to(Vector3(5,1,.04))<.00001)
	snap.vines[0].warning=true; env.update_snapshot(snap,.016)
	assert(env.ropes.v.get_child(9).visible)
	snap.vines[0].broken=true; snap.collectibles[0].collected=true; env.update_snapshot(snap,.016)
	assert(not env.ropes.v.visible and not env.fruits.f.visible)
	root.size=Vector2i(640,360)
	var hud=load("res://modules/monkey_vine/ui/jungle_hud.gd").new(); root.add_child(hud)
	hud.update_snapshot(snap); hud.set_paused(true); await process_frame
	assert(hud.modal.visible and hud.shield.visible)
	assert(hud.modal.get_global_rect().end.y <= hud.status_label.position.y)
	hud.show_status("Save unavailable: progress kept in memory")
	assert(hud.status_label.get_parent().layer==100)
	assert(hud.buttons.get_child(1).get_theme_color("font_focus_color").r<.3)
	hud.set_paused(false); assert(not hud.modal.visible and not hud.shield.visible)
	snap.phase="failed"; hud.update_snapshot(snap); assert(not hud.modal.visible and hud.toast.text!="")
	var audio=load("res://modules/monkey_vine/audio/jungle_audio.gd").new(); root.add_child(audio)
	audio.music_start(); assert(audio.music.playing); audio.set_paused(true); assert(audio.music.stream_paused)
	audio.set_paused(false); audio.play_event("grab"); assert(audio.voices[0].playing)
	audio.set_volume(0); assert(audio.music.volume_db<=-79); audio.stop_all(); assert(not audio.music.playing)
	await create_timer(.35).timeout
	env.queue_free(); hud.queue_free(); audio.queue_free(); await process_frame
	await process_frame
	print("PRESENTATION PASS: stable node count; exact tip; warnings; hide state; modal shield/focus; isolated status; audio lifecycle")
	quit()
