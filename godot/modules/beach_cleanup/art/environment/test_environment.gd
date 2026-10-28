extends SceneTree
const BEACH = preload("res://modules/beach_cleanup/art/environment/beach_environment.gd")
const MAPS = preload("res://modules/beach_cleanup/data/maps.gd")
func _initialize() -> void:
 for id in range(3):
  var beach := BEACH.new()
  root.add_child(beach)
  beach.build(MAPS.definition(id,0))
  for station in beach.get_children():
   if station.has_meta("fixture_ground_center"):
    var center: Vector2 = station.get_meta("fixture_ground_center")
    var depot_center := Vector2(station.position.x,station.position.z)
    assert(is_equal_approx(center.distance_to(depot_center),1.5),"bin not on rim")
    var bin_rect := Rect2(center-Vector2(0.65,0.5),Vector2(1.3,1.0))
    assert(not bin_rect.grow(0.78).has_point(depot_center),"bin overlaps parked cart centre")
    for variant in range(3):
     for trash in MAPS.definition(id,variant).trash:
      assert(not bin_rect.grow(0.35).has_point(trash.pos),"bin overlaps variant trash")
  var total := [0,0]
  _count(beach,total)
  assert(total[0]<45000,"environment exceeds triangle budget")
  assert(beach.source_triangle_count==beach.batched_triangle_count,"batching lost triangles")
  assert(total[1]<=40,"environment mesh budget exceeded")
  var ground: MeshInstance3D = beach.get_child(0)
  var normals: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
  assert(normals[0].y>0.9,"terrain upper face must face UP")
  var zone_ids: Array = beach._ecology.keys()
  for zone_id in zone_ids:
   assert(not beach._ecology[zone_id].visible)
  beach.update_state({"restored_zones":[zone_ids[0]]})
  assert(beach._ecology[zone_ids[0]].visible)
  assert(not beach._ecology[zone_ids[1]].visible)
  beach.update_state({"restored_zones":zone_ids})
  for zone_id in zone_ids:
   assert(beach._ecology[zone_id].visible)
  assert(beach._actors.size()==zone_ids.size()*2)
  for actor in beach._actors:
   assert(beach._ecology_clear(Vector2(actor.position.x,actor.position.z)),"wildlife hidden in rock / depot")
  print("ENVIRONMENT map=",id," triangles=",total[0]," meshes=",total[1]," top_normal=",normals[0]," restoration PASS")
  beach.free()
 quit()
func _count(node: Node,total: Array) -> void:
 assert(not node is CollisionObject3D,"ecology/environment must not compete with sim")
 if node is MeshInstance3D and node.mesh:
  total[1]+=1
  for s in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(s)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   total[0] += indices.size()/3 if indices.size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
 for child in node.get_children():
  _count(child,total)
