extends SceneTree
const Rules = preload("../rules.gd")
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: push_error(message); quit(1)
func _initialize() -> void:
	var s = Rules.new_run()
	check(s.board.size()==20 and s.wear.size()==6,"board and tools")
	check(Rules.affected(4,0).size()==3,"cross clipped at corner")
	check(Rules.affected(3,6)==[5,6,7,8,9],"row pattern")
	check(Rules.affected(5,6)==[1,6,11,16],"column pattern")
	check(not Rules.act(s,-1,0) and not Rules.act(s,0,20),"invalid input")
	var old = s.duplicate(true)
	check(not Rules.act(s,0,0) and s.moves==0,"empty action costs nothing")
	check(Rules.act(s,1,6) and s.exact==1 and s.shield==1 and s.wear[1]==5,"exact power rewards")
	check(s.board[6].kind=="water","killed target removed")
	check(old.board[6].hp==2,"deep-copy snapshot independent")
	# Deterministic salt-crystal cascade can hit two separate enemies.
	s = Rules.new_run()
	for c in s.board: c.kind="water"
	s.board[6]={"kind":"powder","hp":0,"timer":0,"attack":0}
	s.board[7]={"kind":"powder","hp":0,"timer":0,"attack":0}
	s.board[8]={"kind":"wisp","hp":2,"timer":3,"attack":1}
	s.board[11]={"kind":"wisp","hp":2,"timer":3,"attack":1}
	Rules.act(s,0,6)
	check(s.status=="upgrade" and s.exact==2,"chain resolves to room win")
	check(Rules.upgrade(s,1) and s.room==1 and s.wear[0]==7,"upgrade restores and raises wear")
	check(not Rules.upgrade(s,0),"cannot upgrade during play")
	# Predictable greedy player must finish the five-room demo using the actual engine.
	s = Rules.new_run()
	for turn in range(150):
		if s.status=="won": break
		if s.status=="upgrade": Rules.upgrade(s,0); continue
		check(s.status=="play","run remains playable")
		var best_score = -INF; var best_tool = -1; var best_cell = -1
		for tool in range(6):
			for cell in range(20):
				var trial = s.duplicate(true)
				if not Rules.act(trial,tool,cell): continue
				var score = float((s.hp-trial.hp)*-4 + (trial.exact-s.exact)*5 + trial.shield-s.shield)
				for i in range(20):
					if s.board[i].kind=="wisp":
						score += 12 if trial.board[i].kind=="water" else s.board[i].hp-trial.board[i].hp
				if trial.status in ["won","upgrade"]: score += 100
				if trial.status=="lost": score -= 1000
				if score>best_score: best_score=score; best_tool=tool; best_cell=cell
		check(best_tool>=0,"available move")
		Rules.act(s,best_tool,best_cell)
	check(s.status=="won" and s.room==4,"complete five encounters")
	# Enemies hurt the keeper, and exhausted relics cause a terminal result.
	s = Rules.new_run(); s.hp=1
	for c in s.board:
		if c.kind=="wisp": c.timer=1
	Rules.act(s,0,8)
	check(s.status=="lost" and s.hp==0,"enemy intent triggers loss")
	check(not Rules.act(s,0,8),"terminal actions blocked")
	s = Rules.new_run(); s.wear=[1,0,0,0,0,0]; Rules.act(s,0,8)
	check(s.status=="lost","exhaustion termination")
	print("Tide Lantern rules: %d checks passed"%checks); quit(0)
