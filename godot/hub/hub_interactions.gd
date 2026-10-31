extends Node3D
## Input-safe standalone island interactions. Source geometry/bones remain untouched.
signal portal_requested(game_id: String)
const PORTAL = preload("res://hub/portal.gd")
const DRAG_THRESHOLD := 7.0
const PICK_TRIANGLE_BUDGET := 16384
# Keep unknown/planned games locked even when preview metadata incorrectly enables them.
const IMPLEMENTED_GAME_IDS := ["gummy_bomber", "bloom_skirmish", "tide_gulp", "beach_cleanup", "volcano_escape", "pelican_pedal", "fruit_gummy_snake", "monkey_vine", "dawn_sword", "apprentice_yokai_king", "woodland_duel", "tide_lantern", "moon_post", "whale_bento"]
const MAX_PORTALS := 4
var _site_data: Dictionary = {}
var world: Node3D
var camera: Camera3D
var portals: Array[Node3D] = []
var pickables: Array[MeshInstance3D] = []
var pick_triangles: Dictionary = {}
var pick_triangle_tests := 0
var pick_budget_exhausted := false
var visible_layout_sites: Array[Dictionary] = []
var valid_layouts: Array = []
var selected_layout: Array = []
var layout_fallback_used := false
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var hovered: Node3D
var press := Vector2.ZERO
var pressed := false
var dragged := false
var session_seed := 0
var refresh_clock := 0.0
var marker: MeshInstance3D
var effects: Array[Dictionary] = []
var last_effect := -1000
var cursor: ImageTexture
var suspended := false
var _suspended_layers: Array[CanvasLayer] = []
var _visible_before_suspend := true

func setup(p_world: Node3D, p_camera: Camera3D, registry = null) -> void:
	world = p_world; camera = p_camera
	var entries: Array = [
		{"id":"gummy_bomber","title":"GUMMY POP","enabled":true,"color":"ff439c"},
		{"id":"bloom_skirmish","title":"BLOOM SKIRMISH","enabled":true,"color":"23dcca"},
		{"id":"tide_gulp","title":"逐潮小鱼","enabled":true,"color":"9864ff"}]
	if registry is Object and registry.has_method("list_games"):
		entries = registry.list_games()
	elif registry is Array: entries = registry
	elif registry is Dictionary and registry.has("games"): entries = registry.games
	if session_seed == 0: session_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	_site_data = JSON.parse_string(FileAccess.get_file_as_string("res://hub/portal_sites.json"))
	var sites: Array = _site_data.points
	# Geometry chooses one deterministic safe four-door arrangement. Changing
	# recommendations never moves the doors or repositions approved island art.
	_refresh_pickables()
	visible_layout_sites = _visible_sites(sites)
	valid_layouts = _enumerate_layouts(visible_layout_sites)
	selected_layout = _select_layout(0)
	set_portal_entries(entries)
	_refresh_pickables()
	for key in ["click","portal","bird","plant","water"]:
		sounds[key] = load("res://hub/audio/"+key+".wav")
	for i in range(8):
		var voice := AudioStreamPlayer.new(); voice.bus = "Master"; voice.volume_db = -16
		add_child(voice); voices.append(voice)
	var sphere := SphereMesh.new(); sphere.radius = .12; sphere.height = .24
	marker = MeshInstance3D.new(); marker.mesh = sphere; marker.visible = false
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("fff4ae"); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat; add_child(marker)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path d="M4 3 L5 25 L11 20 L16 29 L21 26 L16 18 L25 17 Z" fill="#fff5db" stroke="#715b89" stroke-width="2"/><circle cx="10" cy="12" r="2" fill="#ff8ebc"/></svg>'
	var img := Image.new(); img.load_svg_from_string(svg); cursor = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(cursor,Input.CURSOR_ARROW,Vector2(4,3))

func set_portal_entries(entries: Array) -> void:
	# Called only by the shell with validated playable definitions. The allowlist
	# is defense in depth for test/preview metadata; no fake locked door fills a slot.
	pressed = false; dragged = false; hovered = null
	for portal in portals:
		remove_child(portal); portal.queue_free()
	portals.clear()
	var used: Array[String] = []
	for entry in entries:
		if not entry is Dictionary: continue
		var id := str(entry.get("id",""))
		if id not in IMPLEMENTED_GAME_IDS or not bool(entry.get("enabled",false)) or id in used: continue
		if portals.size() >= mini(MAX_PORTALS,selected_layout.size()): break
		var site: Array = _site_data.points[int(selected_layout[portals.size()])]
		var p := Vector3(site[0],site[1],site[2])
		var portal := PORTAL.new(); add_child(portal); portal.position = p
		var safe_entry: Dictionary = entry.duplicate(true)
		safe_entry["ground_patch"] = _site_data.get("ground_patches",{}).get("%d:%d" % [roundi(p.x*1000),roundi(p.z*1000)],[])
		portal.configure(safe_entry); portals.append(portal); used.append(id)
	_refresh_pickables()

func _visible_sites(sites: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	# A lightweight, non-rendering door proxy exercises the real picker. It has
	# the approved door bounds but no shader, label, sounds, or scene effects.
	var probe := PORTAL.new()
	add_child(probe); portals.append(probe)
	var viewport := get_viewport().get_visible_rect().grow(-16.0)
	for index in sites.size():
		var site: Array = sites[index]
		var point := Vector3(site[0],site[1],site[2])
		probe.position = point
		var clear := true
		for offset in [Vector3(0,1.85,0),Vector3(-.55,1,0),Vector3(.55,1,0),Vector3(-.55,2.7,0),Vector3(.55,2.7,0)]:
			var screen := camera.unproject_position(point+offset)
			if not viewport.has_point(screen) or camera.is_position_behind(point+offset) or _pick(screen) != probe:
				clear = false; break
		if not clear: continue
		var screen_bounds := Rect2(camera.unproject_position(point),Vector2.ZERO)
		for offset in [Vector3(-1.35,0,0),Vector3(1.35,0,0),Vector3(-1.35,3.9,0),Vector3(1.35,3.9,0)]:
			screen_bounds = screen_bounds.expand(camera.unproject_position(point+offset))
		if not viewport.encloses(screen_bounds): continue
		candidates.append({"index":index,"pos":point,"screen_bounds":screen_bounds.grow(8.0)})
	portals.erase(probe); probe.free()
	return candidates

func _layout_separated(a: Dictionary,b: Dictionary) -> bool:
	return (a.pos as Vector3).distance_to(b.pos) >= 2.15 and not (a.screen_bounds as Rect2).intersects(b.screen_bounds)

func _enumerate_layouts(candidates: Array[Dictionary]) -> Array:
	var layouts: Array = []
	for i in candidates.size():
		for j in range(i+1,candidates.size()):
			if not _layout_separated(candidates[i],candidates[j]): continue
			for k in range(j+1,candidates.size()):
				if not _layout_separated(candidates[i],candidates[k]) or not _layout_separated(candidates[j],candidates[k]): continue
				for m in range(k+1,candidates.size()):
					if _layout_separated(candidates[i],candidates[m]) and _layout_separated(candidates[j],candidates[m]) and _layout_separated(candidates[k],candidates[m]):
						layouts.append([candidates[i].index,candidates[j].index,candidates[k].index,candidates[m].index])
	return layouts

func _select_layout(index: int) -> Array:
	layout_fallback_used = index < 0 or index >= valid_layouts.size()
	if valid_layouts.is_empty():
		# Never silently choose four hidden doors. A geometry/camera regression
		# fails loudly instead of pretending the initial entrances are usable.
		push_error("No visible non-overlapping four-portal layout in authored sites")
		return []
	# Deterministic safe fallback is the FIRST geometry-validated combination,
	# not an unverified hard-coded point or freshly generated terrain.
	return valid_layouts[0 if layout_fallback_used else index].duplicate()

func _refresh_pickables() -> void:
	pickables.clear()
	# A bounded cache of current-world mesh faces, never retained across refresh.
	pick_triangles.clear()
	for n in world.find_children("*","MeshInstance3D",true,false):
		if is_ancestor_of(n) or n.mesh == null or not n.is_visible_in_tree(): continue
		var path := str(n.get_path()).to_lower()
		if "terrain" in path or "ocean" in path or "foam" in path or "water" in path or "sky" in path: continue
		pickables.append(n)

func _unhandled_input(event: InputEvent) -> void:
	if suspended: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press = event.position; pressed = true; dragged = false
		else:
			if pressed and not dragged and event.position.distance_to(press) <= DRAG_THRESHOLD:
				_activate(_pick(event.position))
			pressed = false
	elif event is InputEventMouseMotion and pressed:
		if event.position.distance_to(press) > DRAG_THRESHOLD: dragged = true

func _pick(screen: Vector2) -> Node3D:
	pick_triangle_tests = 0
	pick_budget_exhausted = false
	if suspended or not is_instance_valid(camera) or not is_visible_in_tree(): return null
	var from := camera.project_ray_origin(screen); var dir := camera.project_ray_normal(screen)
	var nearest := INF; var result: Node3D = null
	for portal in portals:
		if not portal.is_visible_in_tree() or is_zero_approx(portal.global_basis.determinant()): continue
		var local := portal.global_transform.affine_inverse()
		var hit = portal.get_pick_bounds().intersects_ray(local*from,local.basis*dir)
		if hit != null:
			var d: float = from.distance_to(portal.global_transform*hit)
			if d < nearest: nearest = d; result = portal
	# Keep generous object hit boxes for ordinary island interactions, but a
	# visible portal must not be blocked by empty corners of foliage AABBs.
	var portal_under_pointer := result != null
	for n in pickables:
		if not is_instance_valid(n) or not n.is_visible_in_tree() or is_zero_approx(n.global_basis.determinant()): continue
		var inverse := n.global_transform.affine_inverse()
		var hit = n.get_aabb().grow(.08).intersects_ray(inverse*from,inverse.basis*dir)
		if hit != null:
			var d: float = from.distance_to(n.global_transform*hit)
			if d >= nearest: continue
			# Skinned actors retain their established conservative hit proxy:
			# mesh rest triangles do not describe the deformed visible bird/fish.
			if portal_under_pointer and n.skin == null: d = _mesh_triangle_distance(n,from,dir,d)
			if d < nearest: nearest = d; result = n
	return result

func _mesh_triangle_distance(node: MeshInstance3D, origin: Vector3, direction: Vector3, conservative_distance: float) -> float:
	var mesh_id := node.mesh.get_instance_id()
	if not pick_triangles.has(mesh_id): pick_triangles[mesh_id] = node.mesh.get_faces()
	var faces: PackedVector3Array = pick_triangles[mesh_id]
	var inverse := node.global_transform.affine_inverse()
	var local_origin := inverse*origin
	var local_direction := inverse.basis*direction
	var nearest := INF
	for i in range(0,faces.size(),3):
		# Bound hover/click work. Extreme future geometry conservatively keeps
		# its original proxy instead of doing an unbounded triangle scan.
		if pick_triangle_tests >= PICK_TRIANGLE_BUDGET:
			pick_budget_exhausted = true
			return minf(nearest,conservative_distance)
		pick_triangle_tests += 1
		var point = Geometry3D.ray_intersects_triangle(local_origin,local_direction,faces[i],faces[i+1],faces[i+2])
		if point != null: nearest = minf(nearest,origin.distance_to(node.global_transform*point))
	return nearest

func _activate(target: Node3D) -> void:
	if suspended: return
	if not is_instance_valid(target): return
	if target in portals:
		if not target.enabled:
			_play("click"); _sparkle(target.global_position+Vector3.UP,"locked"); return
		_play("portal"); _sparkle(target.global_position+Vector3.UP,"portal")
		portal_requested.emit(target.game_id); return
	var key := "click"; var path := str(target.get_path()).to_lower()
	if "bird" in path or "gull" in path: key = "bird"
	elif "palm" in path or "leaf" in path or "flower" in path or "grass" in path or "shrub" in path or "fern" in path or "foliage" in path: key = "plant"
	elif "fish" in path or "turtle" in path or "dolphin" in path or "pier" in path: key = "water"
	_play(key)
	_sparkle(target.global_transform * target.get_aabb().get_center(),key)

func _play(key: String) -> void:
	if suspended: return
	for voice in voices:
		if not voice.playing: voice.stream = sounds[key]; voice.play(); return

func _sparkle(at: Vector3, kind: String) -> void:
	if Time.get_ticks_msec()-last_effect < 90: return
	last_effect = Time.get_ticks_msec()
	for i in range(8):
		var dot := MeshInstance3D.new(); var mesh := SphereMesh.new()
		mesh.radius = .045; mesh.height = .09; dot.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("a4f5e3") if kind in ["water","plant"] else Color("ffe5a0")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dot.material_override = mat
		add_child(dot); dot.global_position = at
		var a := TAU*i/8.0
		effects.append({"node":dot,"age":0.0,"velocity":Vector3(cos(a),1.5,sin(a))*.65})

func _process(delta: float) -> void:
	if suspended or not is_instance_valid(world): return
	refresh_clock += delta
	if refresh_clock > 3.0: refresh_clock = 0; _refresh_pickables()
	# GUI controls with STOP/PASS block hover; ignored decoration does not.
	var gui := get_viewport().gui_get_hovered_control()
	var target: Node3D = null if gui != null else _pick(get_viewport().get_mouse_position())
	hovered = target
	for p in portals: p.hovered = p == target
	if is_instance_valid(marker):
		marker.visible = target != null and not target in portals and not pressed
		if marker.visible:
			marker.global_position = target.global_transform*target.get_aabb().get_center() + Vector3.UP*.3
			marker.scale = Vector3.ONE*(1+.2*sin(Time.get_ticks_msec()*.006))
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]; effect.age += delta
		effect.node.position += effect.velocity*delta
		effect.node.scale = Vector3.ONE*maxf(.01,1-effect.age/.65)
		if effect.age > .65: effect.node.queue_free(); effects.remove_at(i)

## Call before the router hides/disables the island. Idempotent.
func suspend() -> void:
	if suspended: return
	suspended = true
	pressed = false; dragged = false; hovered = null
	for portal in portals:
		if is_instance_valid(portal): portal.hovered = false
	if is_instance_valid(marker): marker.visible = false
	for effect in effects:
		if is_instance_valid(effect.node): effect.node.queue_free()
	effects.clear()
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
	_visible_before_suspend = visible
	hide()
	_suspended_layers.clear()
	for layer in find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			_suspended_layers.append(layer)
			layer.hide()
	set_process(false)
	set_process_unhandled_input(false)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	# Island orbit handles the same press; clear its held drag on scene switch.
	if is_instance_valid(world):
		for property in world.get_property_list():
			if property.name == "dragging": world.set("dragging", false); break

## Call after the island is shown and processing is restored.
func resume() -> void:
	if not suspended: return
	suspended = false
	pressed = false; dragged = false; hovered = null
	visible = _visible_before_suspend
	for layer in _suspended_layers:
		if is_instance_valid(layer): layer.show()
	_suspended_layers.clear()
	set_process(true)
	set_process_unhandled_input(true)
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(4,3))

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice): voice.stop(); voice.stream = null
	sounds.clear()
	Input.set_custom_mouse_cursor(null)
