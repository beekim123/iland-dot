extends Node3D
## Input-safe standalone island interactions. Source geometry/bones remain untouched.
signal portal_requested(game_id: String)
const PORTAL = preload("res://hub/portal.gd")
const DRAG_THRESHOLD := 7.0
var world: Node3D
var camera: Camera3D
var portals: Array[Node3D] = []
var pickables: Array[MeshInstance3D] = []
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
		{"id":"gummy_bomber","title":"GUMMY POP","enabled":true,"color":"ff84bb"},
		{"id":"snake","title":"SWEET SNAKE","enabled":false,"color":"75dfad"},
		{"id":"sky_hop","title":"CLOUD HOP","enabled":false,"color":"b29bff"}]
	if registry is Object and registry.has_method("list_games"):
		entries = registry.list_games()
	elif registry is Array: entries = registry
	elif registry is Dictionary and registry.has("games"): entries = registry.games
	if session_seed == 0: session_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new(); rng.seed = session_seed
	var site_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hub/portal_sites.json"))
	var sites: Array = site_data.points
	# Seeded shuffle, not global random state. Keep portal footprints separated.
	for i in range(sites.size()-1,0,-1):
		var j := rng.randi_range(0,i); var tmp = sites[i]; sites[i] = sites[j]; sites[j] = tmp
	for entry in entries:
		if portals.size() >= 3: break
		for site in sites:
			var p := Vector3(site[0],site[1],site[2])
			var clear := true
			for other in portals:
				if other.position.distance_to(p) < 2.15: clear = false
			if not clear: continue
			var portal := PORTAL.new(); add_child(portal); portal.position = p
			# All entries except implemented game remain locked regardless of incoming metadata.
			var safe_entry: Dictionary = entry.duplicate(); safe_entry["enabled"] = str(entry.get("id","")) == "gummy_bomber" and bool(entry.get("enabled",true))
			safe_entry["ground_patch"] = site_data.get("ground_patches",{}).get("%d:%d" % [roundi(p.x*1000),roundi(p.z*1000)],[])
			portal.configure(safe_entry); portals.append(portal); break
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

func _refresh_pickables() -> void:
	pickables.clear()
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
	if suspended or not is_instance_valid(camera) or not is_visible_in_tree(): return null
	var from := camera.project_ray_origin(screen); var dir := camera.project_ray_normal(screen)
	var nearest := INF; var result: Node3D = null
	for portal in portals:
		if not portal.is_visible_in_tree(): continue
		var local := portal.global_transform.affine_inverse()
		var hit = portal.get_pick_bounds().intersects_ray(local*from,local.basis*dir)
		if hit != null:
			var d: float = from.distance_to(portal.global_transform*hit)
			if d < nearest: nearest = d; result = portal
	for n in pickables:
		if not is_instance_valid(n) or not n.is_visible_in_tree(): continue
		var inverse := n.global_transform.affine_inverse()
		var hit = n.get_aabb().grow(.08).intersects_ray(inverse*from,inverse.basis*dir)
		if hit != null:
			var d: float = from.distance_to(n.global_transform*hit)
			if d < nearest: nearest = d; result = n
	return result

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
