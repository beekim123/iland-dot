extends SceneTree
## Actual game-to-skeleton routing, pause/result clocks, respawn and retirement.
const Game = preload("res://modules/bloom_skirmish/main.tscn")
const Art = preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok and failures.size()<60:failures.append(label);printerr("FAIL ANIMAL GAME ",label)
func poses(rig: Node3D) -> Array:
 var output: Array=[]
 for skeleton in rig.find_children("*","Skeleton3D",true,false):
  for bone in skeleton.get_bone_count():output.append(skeleton.get_bone_pose(bone))
 return output
func snapshot(game) -> Dictionary:
 var output: Dictionary={}
 for id in game.actor_cache:
  var rig: Node3D=game.actor_cache[id]
  var player: AnimationPlayer=rig.get_meta("animation_player")
  var values: Array=[poses(rig),rig.get_meta("animation_clip",""),rig.get_meta("last_evaluated_time",-1),player.current_animation,player.current_animation_position if not player.current_animation.is_empty() else 0.0]
  for path in ["Weapon/Muzzle","Weapon/GunGrip","Weapon/AimNozzle"]:
   var node:=rig.get_node_or_null(path) as Node3D
   if node:values.append(node.global_transform)
  output[id]=values
 return output
func clip_is(rig: Node3D,expected: String,label: String) -> void:
 var player:=rig.get_meta("animation_player") as AnimationPlayer
 check(str(rig.get_meta("animation_clip",""))==expected and player!=null and player.current_animation==expected,label+": actual AnimationPlayer selects "+expected)
func sole_geometry(rig: Node3D,skeleton: Skeleton3D,bone: int) -> Dictionary:
 # Real sole vertices retain full foot weight inside the skin (not a helper
 # marker). Convert their actual inverse-bind coordinates into foot space.
 var points:=PackedVector3Array()
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null:continue
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_WEIGHTS]==null:continue
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var stride:=int(weights.size()/vertices.size())
   for vertex in vertices.size():
    for slot in stride:
     var index:=vertex*stride+slot
     if weights[index]<.999:continue
     var bind:=bones[index]
     var name: StringName=mesh.skin.get_bind_name(bind)
     var target: int=skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
     if target==bone:points.append(mesh.skin.get_bind_pose(bind)*vertices[vertex])
 check(points.size()>=8,"contact test uses actual fully foot-weighted sole mesh vertices")
 var low:=INF
 var rest:=skeleton.get_bone_global_rest(bone)
 for point in points:low=minf(low,(rest*point).y)
 var center:=Vector3.ZERO;var count:=0
 for point in points:
  if (rest*point).y<=low+.001:center+=point;count+=1
 if count>0:center/=count
 return {"points":points,"center":center}
func probe_ground_contact(game) -> void:
 # Drive the real game's run selection/rate at its actual world movement speed.
 # This measures planted imported foot bones, not a claimed stride multiplier.
 var tracks: Dictionary={}
 var phases: Dictionary={}
 var soles: Dictionary={}
 var heights: Dictionary={}
 var durations: Dictionary={}
 for actor in game.sim.actors:
  actor.pos=Vector2(5+actor.id*3,2);actor.aim=Vector2.RIGHT
  actor.shot_cd=0.0;actor.dash_left=0.0
  tracks[actor.id]=[PackedVector3Array(),PackedVector3Array()]
  phases[actor.id]=[]
  heights[actor.id]=[[],[]];soles[actor.id]=[]
  var rig: Node3D=game.actor_cache[actor.id]
  var skeleton:=rig.get_meta("skeleton") as Skeleton3D
  durations[actor.id]=rig.get_meta("animation_player").get_animation("run").length
  for side in 2:soles[actor.id].append(sole_geometry(rig,skeleton,skeleton.find_bone("Foot.L" if side==0 else "Foot.R")))
 for frame in 120:
  for actor in game.sim.actors:
   game.previous_positions[actor.id]=actor.pos
   actor.pos+=Vector2.RIGHT*game.sim.MOVE_SPEED/60.0
  game.elapsed+=1.0/60.0;game._sync_visuals(1.0/60.0)
  for actor in game.sim.actors:
   var rig: Node3D=game.actor_cache[actor.id]
   var skeleton:=rig.get_meta("skeleton") as Skeleton3D
   phases[actor.id].append(float(rig.get_meta("animation_player").current_animation_position))
   for side in 2:
    var bone:=skeleton.find_bone("Foot.L" if side==0 else "Foot.R")
    check(bone>=0,"run has actual articulated foot bones")
    if bone>=0:
     var world:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
     tracks[actor.id][side].append(world*soles[actor.id][side].center)
     var low:=INF
     for point: Vector3 in soles[actor.id][side].points:low=minf(low,(world*point).y)
     heights[actor.id][side].append(low)
 for id in tracks:
  var contacts:=0;var peak_slip:=0.0;var minimum_sole:=INF;var maximum_sole:=-INF
  for side in 2:
   var foot: PackedVector3Array=tracks[id][side]
   # The authored contact contract is the first third of each foot's cycle,
   # with the right foot half a cycle later. Do not infer contact from ankle Y:
   # it varies with the foot arch and imported joint interpolation.
   var start: float=durations[id]*.5*side
   var end: float=start+durations[id]/3.0
   for frame in range(1,foot.size()):
    var previous:=foot[frame-1];var current:=foot[frame]
    var previous_phase: float=phases[id][frame-1]
    var current_phase: float=phases[id][frame]
    if previous_phase<start or previous_phase>end or current_phase<start or current_phase>end or current_phase<previous_phase:continue
    contacts+=1
    peak_slip=maxf(peak_slip,Vector2(current.x-previous.x,current.z-previous.z).length())
    minimum_sole=minf(minimum_sole,heights[id][side][frame])
    maximum_sole=maxf(maximum_sole,heights[id][side][frame])
  check(contacts>=20,"actual forward run has sustained planted contact for animal %d"%id)
  check(peak_slip<.004,"planted foot does not slide at actual %.2fm/s: animal=%d peak=%.5fm/frame"%[game.sim.MOVE_SPEED,id,peak_slip])
  var floor_height: float=game.floor_mesh.global_position.y
  check(minimum_sole>=floor_height-.005 and maximum_sole<=floor_height+.025,"actual skinned sole remains at visible ground during contact, not underground/floating: animal=%d min=%.5f max=%.5f floor=%.5f"%[id,minimum_sole,maximum_sole,floor_height])
  print("ANIMAL_GAME_FOOT_CONTACT actor=",id," species=",game.actor_cache[id].get_meta("species")," samples=",contacts," peak_world_slip_per_frame=",peak_slip," actual_sole_y=",[minimum_sole,maximum_sole]," floor_y=",floor_height)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--gait-trace="):
   var trace: Dictionary={}
   for id in tracks:
    trace[id]={"phase":phases[id],"feet":[[],[]]}
    for side in 2:
     for point: Vector3 in tracks[id][side]:trace[id].feet[side].append([point.x,point.y,point.z])
   var file:=FileAccess.open(arg.trim_prefix("--gait-trace="),FileAccess.WRITE)
   file.store_string(JSON.stringify(trace));file.close()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 await process_frame
 var baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var game=Game.instantiate();root.add_child(game);game.start({"seed":819});game.set_process(false)
 game.sim.bots_enabled=false;game.countdown_left=0;game.input_guard=0
 var expected_species: Array=["otter","rabbit","fox","raccoon"]
 for id in 4:
  var rig: Node3D=game.actor_cache[id]
  check(rig.get_meta("species","")==expected_species[id] and rig.get_meta("team",-1)==game.sim.actors[id].team,"game uses intended species independently of team")
  check(bool(rig.get_meta("skinned",false)) and not poses(rig).is_empty(),"gameplay animal is actually skinned, not human/rigid fallback")
  var player:=rig.get_meta("animation_player") as AnimationPlayer
  check(player!=null and player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"gameplay clips have explicit pause-safe manual clock")
  for clip in ["idle","run","spray","dash","hit","pod","respawn","celebration","defeat"]:
   check(player!=null and player.has_animation(clip),"gameplay required skeletal clip exists: "+clip)
  for path in ["Weapon/Muzzle","Weapon/GunGrip","Weapon/AimNozzle"]:check(rig.has_node(path),"runtime physical weapon contract: "+path)
 for state in [{"run":0.0,"shoot":false,"dash":false,"clip":"idle"},{"run":1.0,"shoot":false,"dash":false,"clip":"run"},{"run":0.0,"shoot":true,"dash":false,"clip":"spray"},{"run":1.0,"shoot":true,"dash":true,"clip":"dash"}]:
  game.elapsed+=.17
  for actor in game.sim.actors:
   actor.shot_cd=.07 if state.shoot else 0.0;actor.dash_left=.1 if state.dash else 0.0
   game.previous_positions[actor.id]=actor.pos-Vector2.RIGHT*game.sim.MOVE_SPEED*.02*state.run
  game._sync_visuals(.02)
  for rig in game.actor_cache.values():clip_is(rig,state.clip,"actual movement/shoot/dash state")
 probe_ground_contact(game)
 var frozen:=snapshot(game)
 game.set_paused(true)
 for frame in 3:
  game._sync_visuals(.2)
  await process_frame
 await create_timer(.06).timeout
 check(snapshot(game)==frozen,"pause freezes full bones, chosen clip, player time, grip and nozzle even across render frames")
 game.set_paused(false)
 for actor in game.sim.actors:actor.shot_cd=0.0;actor.dash_left=0.0
 game._handle_event({"type":"hit","id":0})
 game.elapsed+=.10;game._sync_visuals(.02)
 clip_is(game.actor_cache[0],"hit","hit event routes to its actual animal")
 var hit_pose:=poses(game.actor_cache[0])
 game.elapsed+=.10;game._sync_visuals(.02)
 check(poses(game.actor_cache[0])!=hit_pose,"hit clip really changes bone pose with game clock")
 for rig in game.actor_cache.values():Art.react_gardener(rig,"clear")
 game._handle_event({"type":"pod_placed","id":9999,"owner_id":2,"team":1,"pos":Vector2(22,2)})
 game.elapsed+=.10;game._sync_visuals(.02)
 clip_is(game.actor_cache[2],"pod","pod uses owner_id, not pod object id")
 for id in [0,1,3]:check(game.actor_cache[id].get_meta("animation_clip","")!="pod","pod animation does not leak to other actors")
 # Exercise actual defeat/4s respawn simulation, not just an animation name setter.
 game.sim.actors[0].pos=Vector2(5,2)
 game.sim.damage_actor(0,100,2)
 for event in game.sim.drain_events():game._handle_event(event)
 game._sync_visuals(.02)
 check(not game.sim.actors[0].alive and not game.actor_cache[0].visible,"actual defeat hides only the eliminated actor")
 game.elapsed+=4;game.step_simulation(4.0);game._sync_visuals(.02)
 check(game.sim.actors[0].alive and game.actor_cache[0].visible,"actual four-second respawn restores the same animal")
 clip_is(game.actor_cache[0],"respawn","respawn replaces stale death/hit reaction with skeletal respawn")
 # Results can animate the winners, while authoritative game state is frozen.
 game.sim._paint_disc(Vector2(6,2),2.0,0)
 game.elapsed=180;game.step_simulation(180.0);game._sync_visuals(.02)
 check(game.sim.state=="finished" and game.sim.winner==0,"result fixture is a genuine finished coverage win")
 for actor in game.sim.actors:clip_is(game.actor_cache[actor.id],"celebration" if actor.team==0 else "defeat","finished event chooses each team's result clip")
 var actors: Array=game.sim.actors.duplicate(true)
 var paint: PackedInt32Array=game.sim.ownership.duplicate()
 var remaining: float=game.sim.time_left
 var first_result:=snapshot(game)
 var result_clock: float=game.results_animation_elapsed
 game._sync_visuals(.21)
 check(game.results_animation_elapsed>result_clock and snapshot(game)!=first_result,"results advance only actual animal visual animation")
 check(game.sim.actors==actors and game.sim.ownership==paint and game.sim.time_left==remaining,"result animation never advances authoritative simulation")
 game.restart();game.set_process(false)
 check(game.results_animation_elapsed==0 and game.sim.state=="playing" and game.actor_cache.size()==4,"replay resets visual result clock and recreates four live animals")
 for rig in game.actor_cache.values():
  check(not rig.has_meta("reaction") and rig.get_meta("animation_clip","")=="idle","replay has no retained victory/death/respawn pose")
 game.leave_game()
 for rig in game.actor_cache.values():
  check(rig.process_mode==Node.PROCESS_MODE_DISABLED,"exit disables imported animal subtree processing")
  for player in rig.find_children("*","AnimationPlayer",true,false):check(not player.active and not player.is_playing(),"exit stops every imported AnimationPlayer")
 var retired:=snapshot(game)
 await create_timer(.08).timeout
 check(snapshot(game)==retired,"retired animation poses cannot keep advancing after exit")
 game.queue_free();await process_frame;await process_frame;await create_timer(.5).timeout
 check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"actual game with animal skins retires without orphan nodes")
 print("BLOOM ANIMAL GAME: %d checks, %d failures; real clip/event/pose routing, pause/respawn/result/replay/retirement"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
