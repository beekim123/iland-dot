extends SceneTree
## Independent invariants and adversarial rules; no production code modification.
const Sim = preload("res://modules/bloom_skirmish/sim.gd")
var failures: Array[String] = []
var checks := 0
var max_projectiles := 0
var max_pods := 0
var completed_matches := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok and failures.size() < 60:
  failures.append(label)
  printerr("FAIL ", label)
func fresh(seed_id := 123):
 var s = Sim.new()
 s.bots_enabled = false
 s.start(seed_id)
 return s
func circle_clear(s, pos: Vector2, team: int) -> bool:
 if not pos.is_finite() or pos.x < s.ACTOR_RADIUS - 0.00001 or pos.y < s.ACTOR_RADIUS - 0.00001 or pos.x > s.GRID_W * s.CELL_SIZE - s.ACTOR_RADIUS + 0.00001 or pos.y > s.GRID_H * s.CELL_SIZE - s.ACTOR_RADIUS + 0.00001:
  return false
 var barriers: Array = s.obstacles.duplicate()
 barriers.append(s.spawn_zones[1 - team])
 for rect in barriers:
  var nearest := Vector2(clampf(pos.x,rect.position.x,rect.end.x),clampf(pos.y,rect.position.y,rect.end.y))
  if pos.distance_squared_to(nearest) < s.ACTOR_RADIUS * s.ACTOR_RADIUS - 0.000001: return false
 return true
func audit_state(s, label: String) -> void:
 var counts := [0,0]
 var denominator := 0
 for y in s.GRID_H:
  for x in s.GRID_W:
   var cell := Vector2i(x,y)
   var value: int = s.ownership[y * s.GRID_W + x]
   if s.is_scoreable(cell):
    denominator += 1
    check(value >= -1 and value <= 1, label + ": legal ownership")
    if value >= 0: counts[value] += 1
   else: check(value == -1,label + ": walls/spawns never painted")
 check(denominator == s.scoreable_cells and denominator == roundi(640.0 / (s.CELL_SIZE * s.CELL_SIZE)),label + ": exact scoring denominator")
 check(counts == s.score_cells,label + ": coverage tally matches actual cells")
 for team in 2:
  check(is_equal_approx(s.score[team],100.0 * counts[team] / denominator),label + ": coverage percentage")
 for actor in s.actors:
  check(circle_clear(s,actor.pos,int(actor.team)),label + ": actor does not intersect wall/spawn/bounds")
  check(is_finite(actor.hp) and actor.hp >= 0 and actor.hp <= s.MAX_HP,label + ": bounded HP")
  check(is_finite(actor.water) and actor.water >= 0 and actor.water <= s.MAX_WATER,label + ": bounded water")
  check(actor.alive == (actor.hp > 0),label + ": HP/alive consistent")
  check(actor.respawn_left >= 0 and actor.respawn_left <= s.RESPAWN_TIME,label + ": bounded respawn")
 var owners := {}
 for pod in s.pods:
  check(not owners.has(pod.owner_id),label + ": one active pod per gardener")
  owners[pod.owner_id] = true
  check(pod.fuse > 0 and pod.fuse <= s.POD_FUSE and pod.hp > 0,label + ": valid live pod")
 for shot in s.projectiles:
  check(shot.pos.is_finite() and shot.life > 0 and shot.life <= s.SHOT_MAX_LIFE + 0.00001 and shot.world_pos.is_finite() and shot.velocity.is_finite(),label + ": bounded live projectile")
 check(s.projectiles.size() <= 128 and s.pods.size() <= 4,label + ": bounded transient entities")
 max_projectiles = maxi(max_projectiles,s.projectiles.size())
 max_pods = maxi(max_pods,s.pods.size())
func _initialize() -> void:
 var s = fresh()
 check(s.MATCH_DURATION == 180 and s.RESPAWN_TIME == 4 and s.POD_FUSE == 3,"approved timing constants")
 check(s.actors.size() == 4 and s.actors[0].is_player and not s.actors[1].is_player,"four gardeners, exactly one human")
 check(s.actors.map(func(a):return a.team) == [0,0,1,1],"two versus two")
 check(s.state == "playing" and s.winner == -2 and s.score == [0.0,0.0],"fresh match state")
 audit_state(s,"fresh")
 # Whole scoreable arena is connected around obstacles, from either protected base.
 for team in 2:
  var begin := Vector2i(floori(s.actors[team * 2].pos.x), floori(s.actors[team * 2].pos.y))
  var reached := {begin:true}
  var queue: Array[Vector2i] = [begin]
  var index := 0
  while index < queue.size():
   var cell: Vector2i = queue[index]
   index += 1
   for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next: Vector2i = cell + direction
    if reached.has(next) or not circle_clear(s,Vector2(next) + Vector2(0.5,0.5),team): continue
    reached[next] = true
    queue.append(next)
  for y in int(s.GRID_H * s.CELL_SIZE):
   for x in int(s.GRID_W * s.CELL_SIZE):
    var point := Vector2(x + 0.5,y + 0.5)
    if s.is_scoreable(s.cell_at(point)): check(reached.has(Vector2i(x,y)),"every 1-unit scoring navigation cell reachable for team %d" % team)
 # Protected spawn rejects damage and paint; own shots cannot paint a base.
 for actor in s.actors:
  check(not s.damage_actor(actor.id,999,2 if actor.team == 0 else 0),"spawn invulnerability")
 s._paint_disc(Vector2(2,12),10,1)
 s._paint_disc(Vector2(30,12),10,0)
 audit_state(s,"spawn protection")
 # Cover blocks projectile damage, splash ownership, and dash tunnelling.
 s = fresh()
 s.actors[0].pos = Vector2(13,12)
 s.actors[2].pos = Vector2(19,12)
 s.step(1.0,{"shoot":true,"aim":Vector2(19,12)})
 check(s.actors[2].hp == s.MAX_HP,"wall blocks bullets")
 check(s.owner_at(Vector2(18.5,12.5)) == -1,"no splash on opposite wall side")
 s.actors[0].water = 100
 s.step(0.5,{"move":Vector2.RIGHT,"dash":true,"aim":Vector2(20,12)})
 check(s.actors[0].pos.x <= 14.0 - s.ACTOR_RADIUS + 0.00001,"dash cannot tunnel through wall")
 check(not s.try_dash(0,Vector2.RIGHT),"dash cooldown enforced")
 s = fresh()
 s._paint_disc(Vector2(9.5,4.5),3.2,0)
 check(s.owner_at(Vector2(9.5,7.5)) == -1,"pod-sized disc blocked through thin cover")
 # Finite water empties under held fire, then refills only after fire release.
 s = fresh()
 s.actors[0].pos = Vector2(5,2)
 s.step(8.0,{"shoot":true,"aim":Vector2(13,2)})
 check(s.actors[0].shots == int(s.MAX_WATER / s.SHOT_WATER) and is_zero_approx(s.actors[0].water),"held fire is limited to water budget")
 s.step(0.3)
 check(is_zero_approx(s.actors[0].water),"refill delay after release")
 s.step(4.0)
 check(is_equal_approx(s.actors[0].water,s.MAX_WATER),"finite tank regenerates and caps")
 # Direct hostile damage defeats but never awards territory; exactly four-second return.
 s = fresh()
 s.actors[0].pos = Vector2(5,2)
 check(not s.damage_actor(0,50,1),"friendly fire ignored")
 check(s.damage_actor(0,100,2) and not s.actors[0].alive,"hostile damage can defeat")
 check(s.score_cells == [0,0] and s.actors[2].kills == 1,"kill itself does not score territory")
 check(not s.try_dash(0,Vector2.RIGHT) and not s.deploy_pod(0),"defeated gardener cannot act")
 s.step(3.983333333)
 check(not s.actors[0].alive,"no early respawn")
 s.step(1.0 / 60.0)
 check(s.actors[0].alive and s.actors[0].hp == 100 and s.actors[0].water == 100,"four-second full respawn")
 # One destructible pod, friendly turf only, three seconds and wall-aware paint.
 s = fresh()
 s.actors[0].pos = Vector2(5.5,2.5)
 check(not s.deploy_pod(0),"neutral turf cannot host pod")
 s._paint_disc(s.actors[0].pos,0.6,1)
 check(not s.deploy_pod(0),"hostile turf cannot host pod")
 s._paint_disc(s.actors[0].pos,0.6,0)
 check(s.deploy_pod(0),"friendly turf accepts pod")
 s.actors[0].pod_cd = 0.0
 check(not s.deploy_pod(0),"one active pod per actor even if cooldown reset")
 var before_cells: int = s.score_cells[0]
 s.step(2.983333333)
 check(s.pods.size() == 1 and s.score_cells[0] == before_cells,"pod has full three-second fuse")
 s.step(1.0/60.0)
 check(s.pods.is_empty() and s.score_cells[0] > before_cells,"pod bursts at three seconds and paints")
 s = fresh()
 s.actors[0].pos = Vector2(5.5,2.5)
 s._paint_disc(s.actors[0].pos,0.6,0)
 s.deploy_pod(0)
 s.actors[0].pos = Vector2(5.5,4.5)
 s.actors[2].pos = Vector2(8.5,2.5)
 s._fire(s.actors[2],Vector2(5.5,2.5))
 s.step(0.3)
 check(s.pods.size() == 1 and s.pods[0].hp < s.POD_HP,"enemy shot damages pod")
 for shot in range(1,ceili(s.POD_HP / s.SHOT_DAMAGE)):
  s._fire(s.actors[2],Vector2(5.5,2.5))
  s.step(0.3)
 check(s.pods.is_empty(),"sufficient enemy shots destroy pod before fuse")
 s.step(3)
 check(not s.events.any(func(e):return e.type == "pod_burst"),"destroyed pod never bursts")
 # Coverage, not kill count, decides final result; complete 180-second game and freeze.
 s = fresh()
 s._paint_disc(Vector2(6,2),2.4,0)
 s.actors[2].kills = 999
 s.step(179.983333333)
 check(s.state == "playing" and s.time_left > 0,"not finished before 180 seconds")
 s.step(1.0/60.0)
 check(s.state == "finished" and s.winner == 0 and is_equal_approx(s.elapsed,180),"coverage wins despite enemy kill lead")
 var frozen: Array = s.actors.duplicate(true)
 var frozen_grid: PackedInt32Array = s.ownership.duplicate()
 s.step(20,{"move":Vector2.ONE,"shoot":true,"dash":true,"pod":true})
 check(s.actors == frozen and s.ownership == frozen_grid and s.time_left == 0,"results freeze all gameplay")
 s = fresh()
 s.step(180)
 check(s.state == "finished" and s.winner == -1,"equal coverage produces draw")
 s.start(123)
 check(s.time_left == 180 and s.pods.is_empty() and s.projectiles.is_empty() and s.actors[2].kills == 0,"restart completely resets match")
 check(s.events.size() == 1 and s.events[0].type == "start","restart clears stale events")
 # Frame partitioning must not alter clocks or bot decisions.
 var a = Sim.new(); a.start(77)
 var b = Sim.new(); b.start(77)
 a.step(5.0)
 for frame in 300: b.step(1.0/60.0)
 check(a.actors == b.actors and a.ownership == b.ownership and a.projectiles == b.projectiles,"fixed-step frame-partition determinism")
 # Twelve full matches with random human actions, paired deterministic replay.
 var match_count := 2 if "--bloom-qa-quick" in OS.get_cmdline_user_args() else 12
 for seed_id in match_count:
  a = Sim.new(); a.start(seed_id + 200)
  b = Sim.new(); b.start(seed_id + 200)
  var actions := RandomNumberGenerator.new()
  actions.seed = seed_id + 900
  var hits := 0
  for frame in 1800:
   var input := {"move":Vector2(actions.randf_range(-1,1),actions.randf_range(-1,1)),"aim":Vector2(actions.randf_range(0,32),actions.randf_range(0,24)),"shoot":actions.randf() < 0.76,"dash":actions.randf() < 0.08,"pod":actions.randf() < 0.05}
   a.step(0.1,input); b.step(0.1,input)
   check(a.actors == b.actors and a.ownership == b.ownership and a.projectiles == b.projectiles and a.pods == b.pods and a.score_cells == b.score_cells,"replay seed %d chunk %d" % [seed_id,frame])
   for event in a.events:
    if event.type == "hit": hits += 1
   if frame % 60 == 0: audit_state(a,"seed %d second %d" % [seed_id,frame / 10])
  audit_state(a,"final seed %d" % seed_id)
  check(a.state == "finished" and a.time_left == 0 and is_equal_approx(a.elapsed,180),"complete exact 180-second random match")
  check(a.actors[1].painted > 0 and a.actors[2].painted > 0 and a.actors[3].painted > 0,"all three bots paint territory")
  check(hits > 0,"bots and player actually fight, not just paint")
  check(a.winner == (-1 if a.score_cells[0] == a.score_cells[1] else (0 if a.score_cells[0] > a.score_cells[1] else 1)),"coverage determines random-match winner")
  completed_matches += 1
  print("BLOOM RANDOM MATCH ",seed_id," score=",a.score," hits=",hits," max projectiles=",max_projectiles," max pods=",max_pods)
 print("BLOOM INDEPENDENT RULES: %d checks, %d failures; %d paired full matches; max projectiles=%d max pods=%d" % [checks,failures.size(),completed_matches,max_projectiles,max_pods])
 quit(0 if failures.is_empty() else 1)
