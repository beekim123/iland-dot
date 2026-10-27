extends SceneTree
## Real island geometry, real camera rays and the actual press/release input
## route. No _activate bypass. Empty foliage AABBs must not obscure a portal;
## real triangles in front still block it. Five poses x all 63 safe sites.
var failures: Array[String]=[]
var checks:=0
var requested: Array[String]=[]
var face_cache: Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:
		failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func box_distance(camera:Camera3D,node:Node3D,box:AABB,screen:Vector2)->float:
	var origin:=camera.project_ray_origin(screen)
	var inverse:=node.global_transform.affine_inverse()
	var point=box.intersects_ray(inverse*origin,inverse.basis*camera.project_ray_normal(screen))
	return INF if point==null else origin.distance_to(node.global_transform*point)
func triangle_distance(camera:Camera3D,node:MeshInstance3D,screen:Vector2)->float:
	# Separate geometric oracle, with no call to the production narrow phase.
	var origin:=camera.project_ray_origin(screen)
	var inverse:=node.global_transform.affine_inverse()
	var local_origin:=inverse*origin
	var local_direction:=inverse.basis*camera.project_ray_normal(screen)
	var mesh_id:=node.mesh.get_instance_id()
	if not face_cache.has(mesh_id):face_cache[mesh_id]=node.mesh.get_faces()
	var faces:PackedVector3Array=face_cache[mesh_id]
	var nearest:=INF
	for i in range(0,faces.size(),3):
		var point=Geometry3D.ray_intersects_triangle(local_origin,local_direction,faces[i],faces[i+1],faces[i+2])
		if point!=null:nearest=minf(nearest,origin.distance_to(node.global_transform*point))
	return nearest
func click(hub:Node3D,screen:Vector2)->void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		hub._unhandled_input(event)
func run()->void:
	var started:=Time.get_ticks_msec()
	var app=load("res://app/main.tscn").instantiate()
	root.add_child(app);await process_frame
	app.island.animated=false;app.island.set_process(false)
	app.hub.portal_requested.disconnect(app.launch_game)
	app.hub.portal_requested.connect(func(id:String):requested.append(id))
	var sites:Array=JSON.parse_string(FileAccess.get_file_as_string("res://hub/portal_sites.json")).points
	var portal:Node3D=app.hub.portals[2]
	for other in app.hub.portals:other.visible=other==portal
	var original:Vector3=portal.position
	var samples:=0;var visible_samples:=0;var true_occluded:=0;var phantom_boxes:=0
	var skin_proxy_occlusions:=0
	var peak_triangle_tests:=0
	var peak_pick_us:=0
	var total_pick_us:=0
	var poses:Array=[[.38,.61,30.0],[.1,.64,23.0],[-.5,.61,30.0],[1.2,.61,30.0],[2.0,.61,30.0]]
	for pose_index in poses.size():
		var pose:Array=poses[pose_index]
		app.island.yaw=pose[0];app.island.pitch=pose[1];app.island.distance=pose[2];app.island._update_camera()
		for site_index in sites.size():
			var point:Array=sites[site_index];portal.position=Vector3(point[0],point[1],point[2])
			for height in [1.0,1.85,2.7]:
				var screen:Vector2=app.island.camera.unproject_position(portal.global_position+Vector3.UP*height)
				if not root.get_visible_rect().has_point(screen):continue
				samples+=1
				var nearest:=box_distance(app.island.camera,portal,portal.get_pick_bounds(),screen)
				var expected:Node3D=portal
				for mesh in app.hub.pickables:
					if not is_instance_valid(mesh) or not mesh.is_visible_in_tree():continue
					var box_d:=box_distance(app.island.camera,mesh,mesh.get_aabb().grow(.08),screen)
					if box_d>=nearest:continue
					var exact_d:=box_d if mesh.skin!=null else triangle_distance(app.island.camera,mesh,screen)
					if exact_d<nearest:nearest=exact_d;expected=mesh
					elif is_inf(exact_d):phantom_boxes+=1
				var pick_started:=Time.get_ticks_usec()
				var actual:Node3D=app.hub._pick(screen)
				var pick_us:=Time.get_ticks_usec()-pick_started
				total_pick_us+=pick_us;peak_pick_us=maxi(peak_pick_us,pick_us)
				peak_triangle_tests=maxi(peak_triangle_tests,app.hub.pick_triangle_tests)
				check(not app.hub.pick_budget_exhausted and app.hub.pick_triangle_tests<=app.hub.PICK_TRIANGLE_BUDGET,"current island fits bounded per-pick work")
				var label:="pose=%d site=%d height=%.2f" % [pose_index,site_index,height]
				check(actual==expected,"actual camera pick equals visible-geometry oracle: "+label)
				var before:=requested.size()
				click(app.hub,screen)
				if expected==portal:
					visible_samples+=1
					check(requested.size()==before+1 and requested.back()=="tide_gulp","visible portal enters through actual press/release: "+label)
				else:
					true_occluded+=1
					if expected is MeshInstance3D and expected.skin!=null:skin_proxy_occlusions+=1
					check(requested.size()==before,"static geometry or conservative animated proxy occludes portal: "+label)
	check(samples==945 and visible_samples>850 and true_occluded>0 and phantom_boxes>100,"real-camera test covers all sites, empty AABBs and real occlusion")
	check(app.hub.pick_triangles.size()<=app.hub.pickables.size(),"triangle cache bounded by active pickable meshes")
	var skinned_count:=0
	for mesh in app.hub.pickables:
		if mesh.skin!=null:
			skinned_count+=1
			check(not app.hub.pick_triangles.has(mesh.mesh.get_instance_id()),"animated mesh never uses undeformed rest triangle cache")
	check(skinned_count>20,"real bird/fish skin proxies included in actual island")
	# With portals hidden, the actual bird/fish clicks must match the original
	# conservative AABB oracle; zero triangle work is allowed in this path.
	portal.hide()
	var actor_samples:=0
	for actor_mesh in app.hub.pickables:
		if actor_mesh.skin==null:continue
		var center:Vector3=actor_mesh.global_transform*actor_mesh.get_aabb().get_center()
		var screen:Vector2=app.island.camera.unproject_position(center)
		if not root.get_visible_rect().has_point(screen):continue
		var expected:Node3D=null
		var closest:=INF
		for mesh in app.hub.pickables:
			if not is_instance_valid(mesh) or not mesh.is_visible_in_tree():continue
			var distance:=box_distance(app.island.camera,mesh,mesh.get_aabb().grow(.08),screen)
			if distance<closest:closest=distance;expected=mesh
		check(app.hub._pick(screen)==expected and app.hub.pick_triangle_tests==0,"animated bird/fish broad hit proxy preserved without portal")
		actor_samples+=1
	check(actor_samples>20,"real on-screen animated actor clicks covered")
	portal.show()
	# Exhaustion has an explicit bounded, conservative fallback instead of an
	# unbounded hover loop or inaccurate rest-mesh approximation for actors.
	for mesh in app.hub.pickables:
		if mesh.skin==null:
			app.hub.pick_triangle_tests=app.hub.PICK_TRIANGLE_BUDGET
			var fallback:float=app.hub._mesh_triangle_distance(mesh,Vector3(0,20,30),Vector3.FORWARD,12.3)
			check(app.hub.pick_budget_exhausted and is_equal_approx(fallback,12.3) and app.hub.pick_triangle_tests==app.hub.PICK_TRIANGLE_BUDGET,"triangle budget exhaustion keeps conservative proxy without excess work")
			break
	app.hub._refresh_pickables()
	check(app.hub.pick_triangles.is_empty(),"refresh releases stale triangle cache")
	portal.position=original
	print("PICKER WORK BUDGET peak=%d/%d triangles; measured mean=%.1fus peak=%dus (CPU-only, not rendered FPS)" % [peak_triangle_tests,app.hub.PICK_TRIANGLE_BUDGET,float(total_pick_us)/samples,peak_pick_us])
	app.queue_free();await process_frame;await process_frame;await create_timer(.6).timeout
	print("PORTAL REAL-CAMERA PICKING: %s; %d checks, %d rays, %d visible press/release routes, %d occlusions (including %d animated proxies), %d empty AABB candidates (%.2fs)" %["PASS" if failures.is_empty() else JSON.stringify(failures),checks,samples,visible_samples,true_occluded,skin_proxy_occlusions,phantom_boxes,(Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)
