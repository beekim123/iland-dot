extends SceneTree
## Actual imported geometry/default camera/picker. Games rotate, sites do not.
var failures: Array[String] = []
var checks := 0
var entries: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok and failures.size()<30: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func door_rect(camera: Camera3D,point: Vector3) -> Rect2:
	var result := Rect2(camera.unproject_position(point),Vector2.ZERO)
	for x in [-1.35,1.35]:
		for y in [0,3.9]: result=result.expand(camera.unproject_position(point+Vector3(x,y,0)))
	return result.grow(8)
func verify_doors(hub: Node3D,camera: Camera3D,label: String) -> void:
	check(hub.portals.size()==4,"four real portals: "+label)
	for i in hub.portals.size():
		var portal: Node3D=hub.portals[i]
		for j in range(i+1,hub.portals.size()):
			check(portal.position.distance_to(hub.portals[j].position)>=2.15,"terrain footprints separated: "+label)
			check(not door_rect(camera,portal.global_position).intersects(door_rect(camera,hub.portals[j].global_position)),"visible frames never overlap: "+label)
		for offset in [Vector3(0,1.85,0),Vector3(-.55,1,0),Vector3(.55,1,0),Vector3(-.55,2.7,0),Vector3(.55,2.7,0)]:
			var screen:=camera.unproject_position(portal.global_position+offset)
			check(hub._pick(screen)==portal,"five actual visible click samples: "+label)
			var before:=entries.size()
			for down in [true,false]:
				var click:=InputEventMouseButton.new(); click.position=screen; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=down
				hub._unhandled_input(click)
			check(entries.size()==before+1 and entries.back()==portal.game_id,"input routes assigned game: "+label)
func run() -> void:
	var app=load("res://app/main.tscn").instantiate(); root.add_child(app); await process_frame
	app.island.animated=false; app.island.set_process(false)
	app.hub.portal_requested.disconnect(app.launch_game)
	app.hub.portal_requested.connect(func(id:String):entries.append(id))
	var fixed: Array=app.hub.selected_layout.duplicate()
	check(fixed.size()==4 and app.hub.valid_layouts.size()>0,"authored geometry has four safe fixed sites")
	verify_doors(app.hub,app.island.camera,"initial")
	var seen := {}
	for seed_number in 32:
		app.rotation.rng.seed=seed_number+1
		app.shuffle_portals()
		check(app.hub.selected_layout==fixed,"recommendation refresh never moves sites")
		var unique := {}
		for portal in app.hub.portals:
			unique[portal.game_id]=true; seen[portal.game_id]=true
			check(app.registry.is_available(portal.game_id),"every assigned game genuinely loadable")
		check(unique.size()==4,"all four are distinct")
		verify_doors(app.hub,app.island.camera,"refresh %d"%seed_number)
		await process_frame
	check(seen.size()==8,"all eight playable games participate")
	check(app.hub._select_layout(-1)==fixed,"invalid index returns deterministic validated sites")
	for player in app.island.audio_players: player.stop(); player.stream=null
	app.queue_free(); await process_frame; await process_frame; await create_timer(.6).timeout
	print("FOUR FIXED PORTAL LAYOUT: ",checks," checks / ",entries.size()," input routes; ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
