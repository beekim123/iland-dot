extends SceneTree
## Independent renderer-only pool stress; does not claim subjective liquid quality.
const Liquid = preload("res://modules/bloom_skirmish/effects/nectar_effects.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok and failures.size() < 40:
  failures.append(label)
  printerr("FAIL ",label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 await process_frame
 var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var liquid = Liquid.new()
 root.add_child(liquid)
 var children: Array = liquid.get_children().map(func(n): return n.get_instance_id())
 check(children.size() == 4,"exactly four rendering nodes")
 var shots: Array = []
 for index in 150:
  shots.append({"id":index,"team":index % 2,"owner_id":index % 4,"world_pos":Vector3(5 + index * .025,1.2,5),"pos":Vector2(5 + index * .025,5),"dir":Vector2.RIGHT,"velocity":Vector3(15,1.5,0),"age":.12,"gravity":18.0})
 var before: Array = shots.duplicate(true)
 var peak_droplets := 0
 var peak_splashes := 0
 for frame in 600:
  for team in 2:
   liquid.shot({"id":frame % 4,"team":team})
   liquid.impact({"world_pos":Vector3(8,.8,6),"pos":Vector2(8,6),"normal":Vector3.LEFT if frame % 2 == 0 else Vector3.UP,"surface":"wall" if frame % 2 == 0 else "ground","team":team,"radius":1.4,"seed":frame})
  liquid.sync_projectiles(shots,[],1.0 / 60.0)
  var stats: Dictionary = liquid.debug_stats()
  check(stats.projectiles <= stats.max_projectiles and stats.max_projectiles == 64,"bounded visible projectiles")
  check(stats.droplets <= stats.max_droplets and stats.max_droplets == 160,"bounded splash droplets")
  check(stats.splashes <= stats.max_splashes and stats.max_splashes == 24,"bounded contact crowns")
  check(stats.render_nodes == 4 and stats.pooled_instances == 512,"fixed render-node/instance budget")
  check(liquid.get_children().map(func(n): return n.get_instance_id()) == children,"renderer nodes never grow or churn")
  check(liquid._last_shots.size() <= 4,"shot bookkeeping is actor-bounded")
  for child in liquid.get_children():
   if child is MultiMeshInstance3D:
    check(child.multimesh.visible_instance_count <= child.multimesh.instance_count and child.multimesh.instance_count == 256,"valid fixed MultiMesh pool")
  peak_droplets = maxi(peak_droplets,stats.droplets)
  peak_splashes = maxi(peak_splashes,stats.splashes)
  if frame % 30 == 0: await process_frame
 check(shots == before,"renderer never mutates authoritative projectile input")
 var paused_drops: Array = liquid._droplets.duplicate(true)
 var paused_splashes: Array = liquid._splashes.duplicate(true)
 var clock_before: float = liquid._clock
 liquid.sync_projectiles(shots,[],0)
 check(liquid._droplets == paused_drops and liquid._splashes == paused_splashes and liquid._clock == clock_before,"zero delta freezes droplet/splash motion")
 for frame in 120: liquid.sync_projectiles([],[],1.0 / 60.0)
 var drained: Dictionary = liquid.debug_stats()
 check(drained.projectiles == 0 and drained.droplets == 0 and drained.splashes == 0,"all transient liquid retires after inactivity")
 for cycle in 30:
  liquid.impact({"world_pos":Vector3(3,.5,4),"normal":Vector3.UP,"team":cycle % 2,"radius":3.2,"seed":cycle})
  liquid.sync_projectiles(shots,[],.02)
  liquid.reset()
  var reset: Dictionary = liquid.debug_stats()
  check(reset.projectiles == 0 and reset.droplets == 0 and reset.splashes == 0 and liquid._last_shots.is_empty(),"restart resets every liquid history/pool state")
  check(liquid.get_children().map(func(n): return n.get_instance_id()) == children,"reset reuses same render pools")
 liquid.queue_free()
 await process_frame
 await process_frame
 check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline,"liquid pool frees without orphan nodes")
 print("BLOOM INDEPENDENT LIQUID: %d checks, %d failures; peak droplets=%d crowns=%d; render nodes=4 fixed instances=512" % [checks,failures.size(),peak_droplets,peak_splashes])
 quit(0 if failures.is_empty() else 1)
