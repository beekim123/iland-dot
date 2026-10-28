extends Node3D
## Original editable carved-sand diorama. All gameplay geometry comes from maps.gd.
## No physics bodies: the simulation is the sole collision / collection authority.
const SAND_SHADER = preload("res://modules/beach_cleanup/shaders/environment_sand.gdshader")
const SAND = Color("bcb3a0")
const EDGE = Color("968a76")
const SEA = Color("426e70")
const FOAM = Color("c4d2bd")
const CLAY = Color("ad6149")
const INK = Color("344a48")
const REED = Color("66765a")
var _map: Dictionary = {}
var _ecology: Dictionary = {}
var _actors: Array[Node3D] = []
var _time := 0.0
var source_triangle_count := 0
var batched_triangle_count := 0
var _materials: Dictionary = {}

func build(map_data: Dictionary) -> void:
 for child in get_children():
  remove_child(child)
  child.queue_free()
 _ecology.clear()
 _actors.clear()
 _map = map_data
 var size: Vector2 = map_data.get("size", Vector2(32,22))
 var map_id := int(map_data.get("id",0))
 _ground(size, map_id)
 for obstacle in map_data.get("obstacles", []):
  _obstacle(obstacle, map_id)
 for depot in map_data.get("depots", []):
  _depot(depot)
 for i in range(map_data.get("zones", []).size()):
  _zone(map_data.zones[i], i)
 _coastal_details(size, map_id)
 _beach_story(size,map_id)
 source_triangle_count = _triangle_count(self)
 _batch_branch(self,12.0,true)
 for zone in _ecology.values():
  _batch_branch(zone,12.0,true)
 for actor in _actors:
  _batch_branch(actor,0.0,false)
 batched_triangle_count = _triangle_count(self)
 assert(source_triangle_count == batched_triangle_count, "Spatial batching lost geometry")

func update_state(snapshot: Dictionary) -> void:
 var restored = snapshot.get("restored_zones", snapshot.get("zones_restored", []))
 for zone_id in _ecology:
  var active := false
  if restored is Dictionary:
   active = bool(restored.get(zone_id, false))
  elif restored is Array or restored is PackedStringArray:
   active = restored.has(zone_id)
  _ecology[zone_id].visible = active

func _process(delta: float) -> void:
 _time += delta
 for i in range(_actors.size()):
  var actor := _actors[i]
  if not is_instance_valid(actor) or not actor.is_visible_in_tree():
   continue
  var origin: Vector3 = actor.get_meta("origin")
  var bird := bool(actor.get_meta("bird",false))
  actor.position = origin + Vector3(sin(_time*0.45+i)*0.16, abs(sin(_time*2.0+i))*0.025 if bird else 0.0, cos(_time*0.35+i)*0.09)
  actor.rotation.y = sin(_time*0.5+i)*0.18 + float(i)*1.2

func _mat(color: Color, sandy: bool = false) -> Material:
 var key := str(color)+str(sandy)
 if _materials.has(key):
  return _materials[key]
 var material: Material
 if sandy:
  var shader_material := ShaderMaterial.new()
  shader_material.shader = SAND_SHADER
  shader_material.set_shader_parameter("sand_color", color.srgb_to_linear())
  shader_material.set_meta("author_srgb",color)
  material = shader_material
 else:
  var standard := StandardMaterial3D.new()
  standard.albedo_color = color
  standard.roughness = 0.93
  material = standard
 _materials[key] = material
 return material

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, sandy: bool = false) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.material_override = _mat(color,sandy)
 node.position = pos
 parent.add_child(node)
 return node

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, sandy: bool = false) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return _mesh(parent,mesh,pos,color,sandy)

func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radial_segments = 12
 mesh.rings = 6
 mesh.radius = 0.5
 mesh.height = 1.0
 var node := _mesh(parent,mesh,pos,color)
 node.scale = size
 return node

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.radial_segments = 16
 mesh.rings = 1
 mesh.bottom_radius = radius
 mesh.top_radius = radius if top < 0 else top
 mesh.height = height
 return _mesh(parent,mesh,pos,color)

func _ground(size: Vector2, map_id: int) -> void:
 var points := PackedVector2Array()
 var half := size*0.5
 for i in range(96):
  var angle := TAU*float(i)/96.0
  var ray := Vector2(cos(angle),sin(angle))
  var radii := half+Vector2.ONE*(3.5 if map_id<2 else 4.0)
  var reach := pow(pow(absf(ray.x)/radii.x,4.0)+pow(absf(ray.y)/radii.y,4.0),-0.25)
  points.append(ray*(reach+0.28*sin(angle*5.0+map_id)+0.22*cos(angle*3.0)))
 _prism(points,-0.58,-0.04,EDGE,true)
 var top_points := PackedVector2Array()
 for p in points:
  top_points.append(p*0.985)
 for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
  assert(Geometry2D.is_point_in_polygon(corner,top_points),"shoreline clips playable bounds")
 _prism(top_points,-0.06,0.0,SAND,true)
 var ocean := PackedVector2Array()
 for i in range(96):
  var angle := TAU*float(i)/96.0
  var ray := Vector2(cos(angle),sin(angle))
  var radii := half+Vector2(7.7,7.0)
  var reach := pow(pow(absf(ray.x)/radii.x,3.0)+pow(absf(ray.y)/radii.y,3.0),-1.0/3.0)
  ocean.append(ray*(reach+0.3*sin(angle*3.0+map_id)))
 _prism(ocean,-0.95,-0.52,SEA,false)
 _ribbon(points,1.0,1.045,-0.28,Color("a8aa93"))
 _ribbon(points,1.045,1.10,-0.5,Color("749f99"))
 # Continuous tapering surf lines, not dashed road markings.
 _ribbon(points,1.105,1.112,-0.49,Color("becdc1"))
 _ribbon(points,1.16,1.164,-0.50,Color("93b4ab"))

func _ribbon(points: PackedVector2Array, inner: float, outer: float, y: float, color: Color) -> void:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(points.size()):
  var a := points[i]
  var b := points[(i+1)%points.size()]
  _tri(surface,Vector3(a.x*inner,y,a.y*inner),Vector3(a.x*outer,y,a.y*outer),Vector3(b.x*outer,y,b.y*outer))
  _tri(surface,Vector3(a.x*inner,y,a.y*inner),Vector3(b.x*outer,y,b.y*outer),Vector3(b.x*inner,y,b.y*inner))
 surface.generate_normals()
 surface.index()
 var ribbon := _mesh(self,surface.commit(),Vector3.ZERO,color)
 ribbon.set_meta("terrain",true)

func _prism(points: PackedVector2Array, bottom: float, top: float, color: Color, sandy: bool) -> void:
 # Clockwise front-face triangles, explicit top+bottom+side normals via SurfaceTool.
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(points.size()):
  var a := points[i]
  var b := points[(i+1)%points.size()]
  _tri(surface,Vector3.ZERO+Vector3(0,top,0),Vector3(a.x,top,a.y),Vector3(b.x,top,b.y))
  _tri(surface,Vector3(0,bottom,0),Vector3(b.x,bottom,b.y),Vector3(a.x,bottom,a.y))
  _tri(surface,Vector3(a.x,top,a.y),Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y))
  _tri(surface,Vector3(a.x,top,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y))
 surface.generate_normals()
 surface.index()
 var terrain := _mesh(self,surface.commit(),Vector3.ZERO,color,sandy)
 terrain.set_meta("terrain",true)

func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
 surface.add_vertex(a)
 surface.add_vertex(b)
 surface.add_vertex(c)

func _obstacle(data: Dictionary, map_id: int) -> void:
 var rect: Rect2 = data.rect
 var height := float(data.get("height",1.0))
 var center := rect.get_center()
 var root := Node3D.new()
 root.name = "Sandbank_"+str(data.get("id",""))
 root.position = Vector3(center.x,0,center.y)
 add_child(root)
 _sandstone(root,rect.size,height)
 if minf(rect.size.x,rect.size.y)>1.0:
  for i in range(3):
   var point := Vector3((i-1)*minf(rect.size.x*0.23,1.2),height+0.4,0)
   _grass(root,point,0.62+0.15*(i%2))
  if map_id == 1:
   _box(root,Vector3(0,height+0.48,0),Vector3(minf(1.1,rect.size.x*0.5),0.18,0.34),CLAY,true)

func _depot(data: Dictionary) -> void:
 var p: Vector2 = data.pos
 var radius := float(data.get("radius",1.8))
 var root := Node3D.new()
 root.name = "Receiving_station_"+str(data.get("id",""))
 root.position = Vector3(p.x,0.025,p.y)
 add_child(root)
 _cylinder(root,Vector3(0,0.018,0),radius,0.035,Color("bcb89a"))
 # Four corner markings keep the entire unload approach legible.
 for angle in [0.0,PI*0.5,PI,PI*1.5]:
  var mark := _box(root,Vector3(sin(angle)*radius*0.82,0.045,cos(angle)*radius*0.82),Vector3(0.4,0.025,0.09),FOAM)
  mark.rotation.y = -angle
 # Keep the centre clear for the spawn/parking cart. Fixtures sit on the outer
 # left/right rim, away from the main beach approach, without changing sim radius.
 var fixture := Node3D.new()
 fixture.name = "Rim_bin_and_sign"
 var rim_side := -1.0 if p.x < 0.0 else 1.0
 fixture.position = Vector3(rim_side*1.5,0,0.35)
 root.add_child(fixture)
 root.set_meta("fixture_ground_center",p+Vector2(rim_side*1.5,0))
 # Receiving mouth is dark inset, framed by terracotta structural walls.
 _box(fixture,Vector3(0,0.32,-0.35),Vector3(1.12,0.55,0.74),CLAY)
 _box(fixture,Vector3(0,0.605,-0.35),Vector3(0.89,0.025,0.51),INK)
 for x in [-0.6,0.6]:
  _box(fixture,Vector3(x,0.35,-0.35),Vector3(0.09,0.7,0.87),CLAY.lightened(0.13))
 _box(fixture,Vector3(0,0.68,-0.75),Vector3(1.28,0.13,0.1),CLAY.lightened(0.2))
 _box(fixture,Vector3(0,1.05,-0.91),Vector3(0.09,2.0,0.09),INK)
 _box(fixture,Vector3(0,1.75,-0.91),Vector3(1.7,0.65,0.13),INK)
 var label := Label3D.new()
 label.text = "RETURN"
 label.font_size = 58
 label.pixel_size = 0.004
 label.position = Vector3(0,1.76,-0.83)
 label.modulate = Color("efe4c7")
 label.outline_size = 0
 fixture.add_child(label)
 # Clear down arrow, readable from the game camera without needing text.
 _box(root,Vector3(0,0.05,0.63),Vector3(0.12,0.03,0.35),Color("f2e8c9"))
 for side in [-1,1]:
  var arrow := _box(root,Vector3(side*0.12,0.055,0.55),Vector3(0.1,0.03,0.3),Color("f2e8c9"))
  arrow.rotation.y = side*0.7

func _zone(data: Dictionary, index: int) -> void:
 var root := Node3D.new()
 root.name = "Restored_"+str(data.id)
 root.visible = false
 add_child(root)
 _ecology[data.id] = root
 var rect: Rect2 = data.rect
 # Wildlife appears in deterministic zone positions; no collectible/collision nodes.
 var center := rect.get_center()
 for i in range(2):
  var offset := Vector2((i-1)*minf(rect.size.x*0.2,1.6),sin(float(i+index)*1.8)*minf(rect.size.y*0.22,1.0))
  var p := _safe_ecology_point(center+offset, rect, i)
  var animal := _bird(root,Vector3(p.x,0.03,p.y)) if (i+index)%2 == 0 else _crab(root,Vector3(p.x,0.02,p.y))
  animal.set_meta("origin",animal.position)
  _actors.append(animal)
 for i in range(4):
  var p := _safe_ecology_point(center+Vector2(cos(i*1.8)*rect.size.x*0.31,sin(i*1.8)*rect.size.y*0.31), rect, i+3)
  _grass(root,Vector3(p.x,0.0,p.y),0.58)
  for leaf in range(3):
   var angle := float(leaf)*TAU/3.0
   var succulent := _ellipsoid(root,Vector3(p.x+cos(angle)*0.18,0.1,p.y+sin(angle)*0.18),Vector3(0.42,0.18,0.25),Color("82957a"))
   succulent.rotation.y = -angle
  _ellipsoid(root,Vector3(p.x+0.38,0.06,p.y-0.24),Vector3(0.25,0.12,0.19),Color("d5cbb4"))

func _safe_ecology_point(preferred: Vector2, zone: Rect2, index: int) -> Vector2:
 # Avoid returning birds/crabs hidden inside the authoritative rock banks.
 if _ecology_clear(preferred):
  return preferred
 for row in range(7):
  for col in range(7):
   var candidate := zone.position + Vector2(zone.size.x*(0.12+0.12*((col+index)%7)),zone.size.y*(0.12+0.12*((row+index)%7)))
   if _ecology_clear(candidate):
    return candidate
 return preferred

func _ecology_clear(p: Vector2) -> bool:
 for obstacle in _map.get("obstacles",[]):
  var rect: Rect2 = obstacle.rect
  if rect.grow(0.75).has_point(p):
   return false
 for depot in _map.get("depots",[]):
  if p.distance_to(depot.pos)<float(depot.radius)+0.6:
   return false
 return true

func _bird(parent: Node3D, pos: Vector3) -> Node3D:
 var root := Node3D.new()
 root.position = pos
 root.set_meta("bird",true)
 parent.add_child(root)
 _ellipsoid(root,Vector3(0,0.28,0),Vector3(0.38,0.38,0.6),Color("e7e1cc"))
 _ellipsoid(root,Vector3(0,0.46,-0.19),Vector3(0.25,0.29,0.29),Color("efead7"))
 _ellipsoid(root,Vector3(0,0.29,0.12),Vector3(0.4,0.2,0.34),INK)
 _box(root,Vector3(0,0.44,-0.37),Vector3(0.095,0.07,0.2),CLAY)
 for side in [-1,1]:
  _box(root,Vector3(side*0.075,0.09,0),Vector3(0.035,0.18,0.035),CLAY)
  _ellipsoid(root,Vector3(side*0.12,0.5,-0.24),Vector3(0.035,0.035,0.035),INK)
 return root

func _crab(parent: Node3D, pos: Vector3) -> Node3D:
 var root := Node3D.new()
 root.position = pos
 parent.add_child(root)
 _ellipsoid(root,Vector3(0,0.16,0),Vector3(0.45,0.22,0.32),CLAY)
 for side in [-1,1]:
  for leg in range(3):
   var limb := _box(root,Vector3(side*0.24,0.07,(leg-1)*0.12),Vector3(0.24,0.035,0.045),CLAY)
   limb.rotation.y = side*(leg-1)*0.4
  _ellipsoid(root,Vector3(side*0.28,0.17,-0.23),Vector3(0.19,0.17,0.23),CLAY.lightened(0.12))
  _box(root,Vector3(side*0.09,0.28,-0.08),Vector3(0.035,0.14,0.035),CLAY)
  _ellipsoid(root,Vector3(side*0.09,0.35,-0.08),Vector3(0.055,0.055,0.055),INK)
 return root

func _grass(parent: Node3D, p: Vector3, height: float) -> void:
 for i in range(3):
  var blade := _box(parent,p+Vector3((i-1)*0.065,height*0.5,0),Vector3(0.055,height,0.045),REED)
  blade.rotation.z = (i-1)*0.23

func _coastal_details(size: Vector2, map_id: int) -> void:
 # Perimeter markers and shells stay outside gameplay bounds.
 for i in range(18):
  var x := -size.x*0.45+size.x*0.9*float(i)/17.0
  var z := -size.y*0.5-0.32
  if i%3 == 0:
   _grass(self,Vector3(x,0,z),0.5+0.1*(i%2))
  else:
   var shell := _ellipsoid(self,Vector3(x,0.06,z),Vector3(0.24,0.12,0.18),FOAM if i%2==0 else CLAY.lightened(0.35))
   shell.rotation.y = i*1.7
 # Different sculpted landmark silhouettes, entirely beyond the driveable edge.
 var p := Vector3(size.x*0.5+0.48,0,-size.y*0.26)
 if map_id == 0:
  for i in range(3):
   _cylinder(self,p+Vector3(0,i*0.34,0),0.47-i*0.09,0.36,SAND.lightened(0.05),0.4-i*0.09)
  _ellipsoid(self,p+Vector3(0,1.08,0),Vector3(0.42,0.2,0.42),CLAY)
 elif map_id == 1:
  for i in range(4):
   _box(self,p+Vector3(0,i*0.27,0),Vector3(0.65-i*0.12,0.28,1.4-i*0.25),SAND,true)
 else:
  for z in [-0.6,0.6]:
   _cylinder(self,p+Vector3(0,0.55,z),0.28,1.1,SAND,0.22)
  _box(self,p+Vector3(0,1.1,0),Vector3(0.55,0.2,1.7),SAND,true)

func _batch_branch(branch: Node3D, cell_size: float, skip_living: bool) -> void:
 # Every source surface is read with its own index buffer (or sequential triangles).
 # 12m buckets retain spatial culling; wildlife retains one local moving mesh each.
 var sources: Array[MeshInstance3D] = []
 _batch_sources(branch,branch,sources,skip_living)
 var buckets: Dictionary = {}
 for source in sources:
  var transform_to_branch := Transform3D.IDENTITY
  var cursor: Node3D = source
  while cursor != branch:
   transform_to_branch = cursor.transform * transform_to_branch
   cursor = cursor.get_parent() as Node3D
  var origin := transform_to_branch.origin
  var key := Vector2i.ZERO if cell_size<=0.0 else Vector2i(floori(origin.x/cell_size),floori(origin.z/cell_size))
  if not buckets.has(key):
   var tool := SurfaceTool.new()
   tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   buckets[key] = tool
  var surface: SurfaceTool = buckets[key]
  var color := Color.WHITE
  if source.material_override is ShaderMaterial:
   color = source.material_override.get_meta("author_srgb",Color.WHITE)
  elif source.material_override is StandardMaterial3D:
   color = source.material_override.albedo_color
  for slot in range(source.mesh.get_surface_count()):
   var arrays := source.mesh.surface_get_arrays(slot)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   var count := indices.size() if not indices.is_empty() else vertices.size()
   for n in range(count):
    var index := indices[n] if not indices.is_empty() else n
    surface.set_color(color.srgb_to_linear())
    surface.set_normal((transform_to_branch.basis.inverse().transposed()*normals[index]).normalized())
    surface.add_vertex(transform_to_branch*vertices[index])
  source.get_parent().remove_child(source)
  source.queue_free()
 var material := ShaderMaterial.new()
 material.shader = SAND_SHADER
 material.set_shader_parameter("sand_color",Color.WHITE)
 material.set_shader_parameter("grain_strength",0.035)
 for key in buckets:
  var surface: SurfaceTool = buckets[key]
  surface.index()
  var instance := MeshInstance3D.new()
  instance.name = "Spatial_batch_%s_%s" % [key.x,key.y]
  instance.mesh = surface.commit()
  instance.material_override = material
  branch.add_child(instance)

func _batch_sources(node: Node, branch: Node, result: Array[MeshInstance3D], skip_living: bool) -> void:
 if node != branch and skip_living and (_actors.has(node) or _ecology.values().has(node)):
  return
 if node is MeshInstance3D and not node.get_meta("terrain",false):
  result.append(node)
 for child in node.get_children():
  _batch_sources(child,branch,result,skip_living)

func _triangle_count(node: Node) -> int:
 var total := 0
 if node is MeshInstance3D and node.mesh:
  for slot in range(node.mesh.get_surface_count()):
   var arrays: Array = node.mesh.surface_get_arrays(slot)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   total += int(indices.size()/3) if not indices.is_empty() else int(arrays[Mesh.ARRAY_VERTEX].size()/3)
 for child in node.get_children():
  total += _triangle_count(child)
 return total

func _sandstone(parent: Node3D, size: Vector2, height: float) -> void:
 # Rounded wind-eroded bank, all rings strictly INSIDE simulation obstacle Rect2.
 var rings: Array[PackedVector3Array] = []
 for level in range(5):
  var y: float = [0.0,height*0.12,height*0.65,height*0.93,height+0.13][level]
  var inset: float = [0.0,0.035,0.08,0.17,0.29][level]
  var half := size*0.5-Vector2.ONE*minf(inset,minf(size.x,size.y)*0.23)
  var radius := minf(half.x,half.y)*0.42
  var ring := PackedVector3Array()
  for corner in range(4):
   var angle0 := -PI*0.5+corner*PI*0.5
   var center: Vector2 = Vector2(half.x-radius,half.y-radius)*[Vector2(1,-1),Vector2(1,1),Vector2(-1,1),Vector2(-1,-1)][corner]
   for n in range(6):
    var angle := angle0+float(n)/5.0*PI*0.5
    var pt: Vector2 = center+Vector2(cos(angle),sin(angle))*radius
    ring.append(Vector3(pt.x,y,pt.y))
  rings.append(ring)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for level in range(4):
  for i in range(24):
   var j := (i+1)%24
   _tri(surface,rings[level][i],rings[level][j],rings[level+1][j])
   _tri(surface,rings[level][i],rings[level+1][j],rings[level+1][i])
 for i in range(24):
  _tri(surface,Vector3(0,height+0.13,0),rings[4][i],rings[4][(i+1)%24])
  _tri(surface,Vector3.ZERO,rings[0][(i+1)%24],rings[0][i])
 surface.generate_normals()
 surface.index()
 _mesh(parent,surface.commit(),Vector3.ZERO,SAND,true)

func _beach_story(size: Vector2, map_id: int) -> void:
 # Picnic/restoration props occupy the extra sand apron, never navigable space.
 var half := size*0.5
 var shelter := Node3D.new()
 shelter.position = Vector3(-half.x-1.7,0,half.y*0.25)
 shelter.rotation.y = -0.35
 add_child(shelter)
 _cylinder(shelter,Vector3(0,1.25,0),0.055,2.5,Color("776d5b"))
 for i in range(10):
  var a := TAU*i/10.0
  var b := TAU*(i+1)/10.0
  var surf := SurfaceTool.new()
  surf.begin(Mesh.PRIMITIVE_TRIANGLES)
  _tri(surf,Vector3(0,2.65,0),Vector3(cos(a)*1.35,2.2,sin(a)*1.35),Vector3(cos(b)*1.35,2.2,sin(b)*1.35))
  _tri(surf,Vector3(0,2.62,0),Vector3(cos(b)*1.35,2.18,sin(b)*1.35),Vector3(cos(a)*1.35,2.18,sin(a)*1.35))
  surf.generate_normals()
  _mesh(shelter,surf.commit(),Vector3.ZERO,CLAY if i%2==0 else Color("d1c6ac"))
 for x in [-0.65,0.65]:
  _box(shelter,Vector3(x,0.055,0.48),Vector3(0.55,0.06,1.3),Color("9caa97"))
  for z in [-0.11,0.0,0.11]:
   _box(shelter,Vector3(x,0.09,0.88+z),Vector3(0.53,0.02,0.025),Color("d9d2bd"))
 # A short weathered boardwalk, on the apron and leading toward the receiving bay.
 for i in range(7):
  var plank := _box(self,Vector3(-half.x-1.4,0.055,half.y*0.52+i*0.26),Vector3(1.2,0.09,0.20),Color("93836c"))
  plank.rotation.y = -0.09
 # Different miniature sandcastle compositions at the far shore.
 var castle := Node3D.new()
 castle.position = Vector3(half.x*0.36,0,-half.y-1.65)
 add_child(castle)
 _box(castle,Vector3(0,0.26,0),Vector3(2.1,0.52,1.0),SAND,true)
 for x in [-0.88,0.88]:
  _cylinder(castle,Vector3(x,0.55,0),0.40,1.1,SAND,0.35)
  for i in range(6):
   var angle := TAU*i/6.0
   _box(castle,Vector3(x+cos(angle)*0.29,1.15,sin(angle)*0.29),Vector3(0.18,0.24,0.18),SAND,true)
 _cylinder(castle,Vector3(0,0.76,0),0.43,1.5,SAND,0.33)
 _cylinder(castle,Vector3(0,1.65,0),0.48,0.5,CLAY,0.0)
 _box(castle,Vector3(0,2.1,0),Vector3(0.045,0.6,0.045),INK)
 _box(castle,Vector3(0.22,2.3,0),Vector3(0.42,0.23,0.025),Color("879e91"))
 _box(castle,Vector3(0,0.22,0.508),Vector3(0.27,0.40,0.025),EDGE)
 # Fan shells and wind-bent reed clusters distinguish the ecological, non-trash apron.
 for i in range(9):
  var angle := float(i)*0.73+map_id*0.4
  var p := Vector3(half.x+1.15,0.02,-half.y*0.7+float(i)*half.y*0.16)
  for j in range(3):
   var shell := _ellipsoid(self,p+Vector3(cos(angle+j)*0.3,0.07,sin(angle+j)*0.3),Vector3(0.34,0.14,0.25),Color("d5cbb4"))
   shell.rotation.y = angle+j
  if i%2 == 0:
   _grass(self,p+Vector3(0.4,0,0.3),0.7)
