extends SceneTree
const Sim = preload("res://modules/gummy_bomber/sim.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FAIL ", label)
func clear_board(s) -> void:
 for p in s.grid:
  if s.grid[p] != s.WALL: s.grid[p] = s.EMPTY
 s.enemies.clear(); s.events.clear(); s.invulnerable = 0
func _initialize() -> void:
 for seed_id in range(1000):
  var s = Sim.new(); s.start(seed_id)
  var twin = Sim.new(); twin.start(seed_id)
  check(s.grid == twin.grid and s.enemies == twin.enemies, "deterministic seed %d" % seed_id)
  check(s.grid.size() == 143 and s.enemies.size() == 3, "bounded valid seed %d" % seed_id)
  var visited := {s.player: true}; var frontier: Array[Vector2i] = [s.player]
  while not frontier.is_empty():
   var p: Vector2i = frontier.pop_back()
   for d in s.DIRS:
    var q: Vector2i = p + d
    if s.grid.get(q, s.WALL) != s.WALL and not visited.has(q):
     visited[q] = true; frontier.append(q)
  for enemy in s.enemies:
   check(visited.has(enemy.pos), "reachable after crates seed %d" % seed_id)
   check(enemy.pos.distance_to(s.player) >= 6, "enemy clearance seed %d" % seed_id)
  check(s.grid[Vector2i(4,1)] == 0 and s.grid[Vector2i(1,4)] == 0, "escape corridor seed %d" % seed_id)
 var s = Sim.new(); s.start(42); clear_board(s)
 s.grid[Vector2i(4,3)] = s.CRATE
 s.bombs[Vector2i(3,3)] = {"timer":1.0,"range":6}
 s.bombs[Vector2i(5,3)] = {"timer":2.0,"range":6}
 s.explode(Vector2i(3,3))
 check(s.bombs.has(Vector2i(5,3)) and not s.flames.has(Vector2i(5,3)), "crate shields next bomb")
 s.bombs.clear(); s.flames.clear(); s.player = Vector2i(1,1)
 s.capacity = 5
 for x in range(1,6): s.bombs[Vector2i(x,1)] = {"timer":2.0,"range":2}
 s.explode(Vector2i(1,1))
 check(s.bombs.is_empty(), "five bomb chain clears capacity")
 check(s.score >= 10, "crate scoring")
 s.start(42); clear_board(s); s.player = Vector2i(1,1)
 s.place_bomb(); check(s.move(Vector2i.RIGHT), "step off")
 s.move_wait = 0; check(not s.move(Vector2i.LEFT), "no reentry")
 s.tick(2.4); check(not s.alive, "timed own blast death")
 check(not s.place_bomb() and not s.move(Vector2i.RIGHT), "dead cannot act")
 s.start(2); check(s.alive and s.capacity == 1 and s.speed == 1 and s.score == 0, "restart resets")
 clear_board(s)
 for kind in ["capacity","range","speed"]:
  for i in range(30):
   s.player = Vector2i(1,1); s.move_wait = 0; s.pickups[Vector2i(2,1)] = kind
   s.move(Vector2i.RIGHT)
 check(s.capacity == 5 and s.blast_range == 6 and is_equal_approx(s.speed,1.65), "powerup caps")
 for wave_id in range(1,501):
  s.enemies.clear(); s.bombs.clear(); s.flames.clear(); s.events.clear()
  for i in 31: s.tick(0.05)
  check(s.wave == wave_id + 1 and s.enemies.size() <= 6 and not s.enemies.is_empty(), "endless bounded wave %d" % wave_id)
  check(s.grid.size() == 143 and s.bombs.is_empty() and s.flames.is_empty(), "wave cleanup %d" % wave_id)
 for seed_id in range(100):
  var a = Sim.new(); a.start(seed_id)
  var b = Sim.new(); b.start(seed_id)
  var actions := RandomNumberGenerator.new(); actions.seed = seed_id + 77
  for frame in range(600):
   var direction: Vector2i = a.DIRS[actions.randi_range(0,3)]
   var drop := actions.randf() < 0.08
   for subject in [a,b]:
    subject.move(direction)
    if drop: subject.place_bomb()
    subject.tick(0.05); subject.events.clear()
   check(a.grid == b.grid and a.enemies == b.enemies and a.player == b.player and a.alive == b.alive and a.score == b.score, "action replay seed %d frame %d" % [seed_id,frame])
   check(a.bombs.size() <= a.capacity and a.grid[a.player] == a.EMPTY, "valid player/bomb state")
   for enemy in a.enemies: check(a.grid[enemy.pos] == a.EMPTY, "enemy never inside wall/crate")
 s.start(1); clear_board(s); s.enemies.append({"id":0,"pos":s.player,"wait":1.0,"kind":0})
 s.check_damage(); check(not s.alive, "enemy contact kills")
 s.start(1); clear_board(s); s.enemies.append({"id":0,"pos":Vector2i(3,3),"wait":1.0,"kind":0})
 s.flames[Vector2i(3,3)] = 0.55; s.check_damage()
 check(s.enemies.is_empty() and s.score == 100, "blast kills and scores enemy")
 print("INDEPENDENT QA: %d checks; %d failures" % [checks, failures.size()])
 quit(0 if failures.is_empty() else 1)
