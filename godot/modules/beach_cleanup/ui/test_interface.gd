extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred('_run')
func _run() -> void:
	var hud = load('res://modules/beach_cleanup/ui/beach_hud.gd').new()
	root.add_child(hud)
	await process_frame
	for dims in [Vector2(1280,720),Vector2(1024,768),Vector2(960,540),Vector2(640,360)]:
		hud.size=dims
		hud._layout()
		check(hud.canvas.position.x>=0 and hud.canvas.position.y>=0, 'fit '+str(dims))
		check(hud.canvas.size*hud.canvas.scale+hud.canvas.position*2==dims, 'bounds '+str(dims))
	hud.update_state({'cargo_used':12,'ground_remaining':8,'delivered':4,'depot_near':true})
	check(hud.slots.used==12,'cargo slots')
	check('E' in hud.prompt.text,'depot instruction')
	hud.update_state({'cargo_used':1,'ground_remaining':0,'delivered':23,'depot_near':false,'hint_text':'找残留','capacity_message':'旧提示'})
	check(hud.prompt.text == '海滩已清理 · 回卸货站卸下最后一车', 'last cargo directs back to depot')
	hud.update_state({'cargo_used':1,'ground_remaining':0,'delivered':23,'depot_near':true})
	check('按 E' in hud.prompt.text, 'last cargo at depot directs E unload')
	var warning := '进度暂时无法写入，请保持游戏开启后重试'
	hud.update_state({'cargo_used':1,'ground_remaining':0,'delivered':23,'depot_near':true,'capacity_message':'车厢不足','hint_text':'找残留','save_status':warning})
	check(hud.prompt.text == warning and hud.save_warning_text.text == warning, 'save warning outranks depot capacity and last cargo')
	check(hud.save_warning.is_visible_in_tree(), 'save warning visible near depot')
	hud.update_state({'cargo_used':0,'ground_remaining':0,'delivered':24,'depot_near':true,'save_status':warning})
	check(hud.prompt.text == warning, 'completed empty cart cannot hide save error')
	hud.show_pause()
	check(hud.modal_kind=='pause','pause')
	check(hud.save_warning.is_visible_in_tree() and hud.save_warning.z_index > hud.modal.z_index, 'save warning remains above pause dimmer')
	hud._confirm('return')
	check(hud.modal_kind=='confirm_return','return confirmation')
	hud.handle_escape()
	check(hud.modal_kind=='pause','cancel return')
	hud._confirm('replay')
	check(hud.modal_kind=='confirm_replay','replay confirmation')
	hud.handle_escape()
	var img=Image.create(16,16,false,Image.FORMAT_RGB8)
	img.fill(Color.SEA_GREEN)
	var tex=ImageTexture.create_from_image(img)
	hud.show_completion({'distance':140.0,'unloads':3,'has_next':true},tex,tex)
	check(hud.modal_kind=='completion','postcard')
	check(hud._before==tex and hud._after==tex,'actual textures retained')
	check(hud.save_warning.is_visible_in_tree() and hud.save_warning_text.text == warning and hud.save_warning.z_index > hud.modal.z_index, 'completion postcard retains unobscured save warning')
	hud.set_save_status('')
	check(not hud.save_warning.visible and hud.prompt.text != warning, 'successful canonical state has no error overlay')
	hud.set_save_status(warning)
	check(hud.save_warning.is_visible_in_tree() and hud.save_warning_text.text == warning, 'save failure updates immediately without presentation ticks')

	hud._confirm('return');hud.handle_escape()
	check(hud.modal_kind=='completion','completion confirmation cancel')
	hud.reset_session()
	check(hud.modal_kind.is_empty() and hud._completion.is_empty() and hud._before == null and hud._after == null, 'reset session clears stale result')
	hud.queue_free()
	await process_frame
	for pause_case in [false,true]:
		var audio=load('res://modules/beach_cleanup/audio/beach_audio.gd').new()
		root.add_child(audio)
		var weak=weakref(audio)
		for i in range(200): audio.cue('pickup')
		check(audio.voices.size()==8,'bounded effects')
		paused=pause_case
		audio.shutdown();audio.shutdown()
		# Simulate a low-FPS 400ms process frame; must finish even when paused.
		audio._process(0.4)
		await process_frame
		await process_frame
		check(weak.get_ref()==null,'retirement paused='+str(pause_case))
		paused=false
	var live_audio=load('res://modules/beach_cleanup/audio/beach_audio.gd').new()
	root.add_child(live_audio)
	var live_weak=weakref(live_audio)
	paused=true
	Engine.max_fps=5
	live_audio.shutdown()
	await create_timer(0.65, true).timeout
	check(live_weak.get_ref()==null,'real paused 5FPS retirement')
	paused=false
	Engine.max_fps=0
	var owner_node=Node.new()
	root.add_child(owner_node)
	var immediate_audio=load('res://modules/beach_cleanup/audio/beach_audio.gd').new()
	owner_node.add_child(immediate_audio)
	var immediate_weak=weakref(immediate_audio)
	owner_node.queue_free()
	await process_frame
	await process_frame
	check(immediate_weak.get_ref()==null,'parent immediate retirement')
	await create_timer(0.3).timeout
	print('BEACH_UI_AUDIO_TEST ', 'PASS' if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
