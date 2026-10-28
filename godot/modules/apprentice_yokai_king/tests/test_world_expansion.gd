extends SceneTree
## Isolated M2 fixtures, not completion evidence.
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
const Store = preload("res://modules/apprentice_yokai_king/profile_store.gd")
var checks = 0
var failures = 0
func check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures += 1; printerr("FAIL ",label)
func fixture():
	var m=Model.new(); m.reset(51,"standard",false); m.phase="combat"
	m.pending=[{"kind":"grunt","at":1000.0,"pos":Vector2(100,100),"warned":false}]
	return m
func _initialize():
	var m=fixture()
	check(Model.WORLD_SIZE == Vector2(3200,2200),"large world dimensions")
	check(m.camera_origin()==Vector2(960,670),"center camera follows player")
	m.player=Model.BOUNDS.position
	check(m.camera_origin()==Vector2.ZERO,"top-left camera clamped")
	m.player=Model.BOUNDS.end
	check(m.camera_origin()==Vector2(1920,1400),"bottom-right camera clamped")
	for point in [Vector2(1600,1100),Vector2(90,110),Vector2(3110,2090)]:
		m.player=point
		for i in range(20):
			var pos=m.spawn_position()
			check(pos.x >= Model.BOUNDS.position.x and pos.y >= Model.BOUNDS.position.y and pos.x <= Model.BOUNDS.end.x and pos.y <= Model.BOUNDS.end.y,"spawn inside world")
			check(pos.distance_to(m.player)>250,"edge spawn safety")
	m=fixture(); m.spawn_enemy("grunt",m.player+Vector2(167,0)); m.spawn_enemy("grunt",m.player+Vector2(170,0))
	m.perform_attack(0.0); m.resolve_attack()
	check(m.enemies[0].hp==2 and m.enemies[1].hp==3,"giant light sweep exact 168 range")
	m.resolve_attack()
	check(m.enemies[0].hp==2,"attack ID deduplicates even repeated resolver entry")
	check(m.attack_contains(m.player+Vector2(167,0)) and not m.attack_contains(m.player+Vector2(-20,0)),"bubble breaking uses same visible attack geometry")
	m=fixture(); m.spawn_enemy("grunt",m.player+Vector2(219,0)); m.spawn_enemy("grunt",m.player+Vector2(222,0))
	m.perform_attack(0.8); m.resolve_attack()
	check(m.enemies[0].hp==0 and m.enemies[1].hp==3,"giant slam exact forward92 radius128")
	m=fixture(); m.spawn_enemy("dart",m.player+Vector2(220,0)); var e=m.enemies[0]
	e.state="windup"; e.timer=0.01; e.face=Vector2.LEFT; e.target=m.player
	m.step_enemy(e,0.02)
	check(e.state=="dash","dart has locked straight dash after warning")
	var old: Vector2=e.pos; m.step_enemy(e,0.1)
	check(e.pos.x<old.x and e.face==Vector2.LEFT,"dart travels along locked face")
	for kind in ["lobber","warder"]:
		m=fixture(); m.spawn_enemy(kind,m.player+Vector2(300,0)); e=m.enemies[0]
		e.state="windup"; e.timer=0.01; e.target=m.player
		m.step_enemy(e,0.02)
		check(m.hazards.size()==1,"new ranged enemy creates bounded ground hazard")
		check(m.hazards[0].delay>=0.9 and m.hazards[0].age==0,"ground hazard grants explicit warning before damage")
		check(m.hazards[0].kind==("lob" if kind=="lobber" else "field"),"distinct projectile versus persistent field")
	m=fixture(); m.reserved_summons=4; m.spawn_enemy("caller",m.player+Vector2(300,0)); e=m.enemies[0]
	for i in range(3):
		e.state="windup"; e.timer=0.01; m.step_enemy(e,0.02)
	check(e.summons_left==0 and m.reserved_summons==0 and m.pending.size()==5,"caller lifetime budget exactly four plus fixture pending")
	for p in m.pending: check(p.kind=="grunt","caller cannot recursively summon callers")
	m=fixture(); m.reserved_summons=4; m.spawn_enemy("caller",m.player+Vector2(300,0)); m.enemies[0].hp=0
	m.advance(1.0/60.0,{})
	check(m.reserved_summons==0,"defeating caller cancels unspent reserved adds")
	for kind in ["dart","lobber","warder","caller"]: check(kind in Store.ENEMIES,"M2 discoveries use whitelisted schema IDs")
	print("YOKAI M2 world/enemy/giant-hammer fixtures: ",checks," checks / ",failures," failures (not gameplay clear evidence)")
	quit(0 if failures == 0 else 1)
