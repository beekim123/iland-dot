extends SceneTree
## Every initial candidate/layout uses the real default camera and real picker.
## No terrain, art, camera or simulation code is substituted.
var failures:Array[String]=[]
var checks:=0
var entries:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func door_rect(camera:Camera3D,point:Vector3)->Rect2:
	var result:=Rect2(camera.unproject_position(point),Vector2.ZERO)
	for x in [-1.35,1.35]:
		for y in [0,3.9]:result=result.expand(camera.unproject_position(point+Vector3(x,y,0)))
	return result.grow(8)
func verify_doors(hub:Node3D,camera:Camera3D,label:String)->void:
	check(hub.portals.size()==3,"all three real portals exist: "+label)
	for i in hub.portals.size():
		var portal:Node3D=hub.portals[i]
		for j in range(i+1,hub.portals.size()):
			check(portal.position.distance_to(hub.portals[j].position)>=2.15,"terrain footprints separated: "+label)
			check(not door_rect(camera,portal.global_position).intersects(door_rect(camera,hub.portals[j].global_position)),"visible portal frames never overlap on screen: "+label)
		for offset in [Vector3(0,1.85,0),Vector3(-.55,1,0),Vector3(.55,1,0),Vector3(-.55,2.7,0),Vector3(.55,2.7,0)]:
			var screen:=camera.unproject_position(portal.global_position+offset)
			check(hub._pick(screen)==portal,"five actually visible/clickable portal samples: "+label)
			var before:=entries.size()
			for down in [true,false]:
				var click:=InputEventMouseButton.new();click.position=screen;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
				hub._unhandled_input(click)
			check(entries.size()==before+1 and entries.back()==portal.game_id,"actual input routes correct color/id: "+label)
func run()->void:
	var started:=Time.get_ticks_msec()
	var app=load("res://app/main.tscn").instantiate();root.add_child(app);await process_frame
	app.island.animated=false;app.island.set_process(false)
	app.hub.portal_requested.disconnect(app.launch_game)
	app.hub.portal_requested.connect(func(id:String):entries.append(id))
	var sites:Array=JSON.parse_string(FileAccess.get_file_as_string("res://hub/portal_sites.json")).points
	var layouts:Array=app.hub.valid_layouts.duplicate(true)
	check(sites.size()==63 and app.hub.visible_layout_sites.size()>=50 and layouts.size()>=50,"all authored candidates filtered into a nontrivial valid set")
	# Verify EVERY available combination, including actual door-to-door screen
	# occlusion with all three rendered proxies present, not just pair distance.
	for index in layouts.size():
		for slot in 3:
			var point:Array=sites[layouts[index][slot]]
			app.hub.portals[slot].position=Vector3(point[0],point[1],point[2])
		verify_doors(app.hub,app.island.camera,"combination %d" % index)
	var selected:Array=app.hub._select_layout(-1)
	check(app.hub.layout_fallback_used and selected==layouts[0],"invalid choice falls back to first actually geometry-verified combination")
	check(app.hub._select_layout(999999)==layouts[0],"out-of-range choice cannot select a hidden or unknown ground site")
	var seen:Dictionary={}
	for seed_number in 1000:
		var rng:=RandomNumberGenerator.new();rng.seed=seed_number
		var first:Array=app.hub._select_layout(rng.randi_range(0,layouts.size()-1))
		rng.seed=seed_number
		check(first==app.hub._select_layout(rng.randi_range(0,layouts.size()-1)),"seeded valid-combination selection deterministic")
		check(first in layouts,"random seed never escapes validated combinations")
		seen[JSON.stringify(first)]=true
	check(seen.size()>50,"random layout selection preserves meaningful variety")
	# Re-run actual setup (including new cache, sprites, random color/site order)
	# with 32 seeds instead of testing only the selector in isolation.
	var actual_layouts:Dictionary={}
	for seed_number in 32:
		app.hub.free()
		app.hub=load("res://hub/hub_interactions.gd").new()
		app.island.add_child(app.hub);app.hub.session_seed=seed_number+1
		app.hub.setup(app.island,app.island.camera,app.registry)
		app.hub.portal_requested.connect(func(id:String):entries.append(id))
		verify_doors(app.hub,app.island.camera,"real setup seed %d" % (seed_number+1))
		actual_layouts[JSON.stringify(app.hub.selected_layout)]=true
		for i in 3:check(app.hub.portals[i].game_id==["gummy_bomber","bloom_skirmish","tide_gulp"][i],"random site order never changes module identity")
	check(actual_layouts.size()>20,"actual seeded setup creates distinct safe color layouts")
	app.queue_free();await process_frame;await process_frame;await create_timer(.6).timeout
	print("PORTAL INITIAL LAYOUT: %s; %d checks; 63 candidate sites, %d validated triples, 1000 seeds, 32 actual setups, %d press/release routes (%.2fs)" %["PASS" if failures.is_empty() else JSON.stringify(failures),checks,layouts.size(),entries.size(),(Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)
