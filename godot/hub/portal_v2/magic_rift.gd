extends Node3D
## Visual-only prototype. configure / set_hovered preserve future wrapper API.
var game_id := ""
var enabled := true
var tint := Color("ff439c")
var hovered := false
var clock := 0.0
var controlled_time := false
var surfaces: Array[ShaderMaterial] = []
var motes: Array[MeshInstance3D] = []
func configure(entry: Dictionary) -> void:
	game_id = str(entry.get("id", ""))
	enabled = bool(entry.get("enabled", true))
	tint = Color(entry.get("color", "ff439c"))
	if is_inside_tree() and surfaces.is_empty(): _build()
func _ready() -> void:
	if surfaces.is_empty(): _build()
func _build() -> void:
	for i in range(3):
		var m := ShaderMaterial.new(); m.shader = load("res://hub/portal_v2/energy.gdshader")
		m.set_shader_parameter("tone",tint); m.set_shader_parameter("layer",0.0 if i == 0 else 1.0)
		m.render_priority = i
		var n := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(2.6,3.9)*(1.0+i*.025)
		n.mesh=quad; n.material_override=m; n.position=Vector3(0,1.85,i*.022)
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(n); surfaces.append(m)
	var shadow := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(2.6,1.45)
	shadow.mesh=plane; shadow.position.y=.015
	var sm := ShaderMaterial.new(); sm.shader=load("res://hub/portal_v2/soft_shadow.gdshader"); shadow.material_override=sm
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(shadow)
	var spark_material := ShaderMaterial.new();spark_material.shader=load("res://hub/portal_v2/spark.gdshader");spark_material.set_shader_parameter("tone",tint)
	for i in range(34):
		var n := MeshInstance3D.new();var q := QuadMesh.new();q.size=Vector2.ONE*(.12+.07*fmod(i*.618,1.0));n.mesh=q;n.material_override=spark_material;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);motes.append(n)
	set_time(0.0)
func set_hovered(value: bool) -> void: hovered=value
func set_time(t: float) -> void:
	clock=t
	for m in surfaces:
		m.set_shader_parameter("phase",clock)
		m.set_shader_parameter("strength",1.09 if hovered else 1.0)
	for i in range(motes.size()):
		var f:=fmod(i*.618033+clock*(.07+.015*(i%3)),1.0)
		var a:=float(i)*2.39996+clock*.17
		motes[i].position=Vector3(cos(a)*(.72+.33*sin(i*1.7)),.25+f*3.45,sin(a)*.26+.09)
		motes[i].scale=Vector3.ONE*sin(f*PI)*(.65+.35*sin(clock*1.8+i))
func _process(delta:float)->void:
	if not controlled_time:set_time(clock+delta)
