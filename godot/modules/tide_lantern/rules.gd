extends RefCounted
## Pure deterministic tactics. No scene, input, random, or persistence dependencies.
const TOOLS = [
	{"name":"萤火针", "power":1, "pattern":"point", "wear":6, "desc":"单格 · 精细收尾"},
	{"name":"贝壳灯", "power":2, "pattern":"point", "wear":5, "desc":"单格 · 稳定净化"},
	{"name":"灯塔镜", "power":3, "pattern":"point", "wear":4, "desc":"单格 · 穿透深雾"},
	{"name":"潮汐梳", "power":1, "pattern":"row", "wear":4, "desc":"整行 · 扫过横潮"},
	{"name":"月牙桨", "power":2, "pattern":"cross", "wear":3, "desc":"十字 · 邻格共鸣"},
	{"name":"引潮铃", "power":1, "pattern":"column", "wear":4, "desc":"整列 · 纵向回响"}
]
const ROOM_NAMES = ["浅滩微光", "漂流瓶湾", "珊瑚回声", "沉船暗礁", "月蚀灯塔"]
static func new_run() -> Dictionary:
	var s = {"room":0,"hp":18,"max_hp":18,"shield":0,"wear_bonus":0,"blast":2,"exact":0,"moves":0,"status":"play","board":[],"wear":[],"log":"选一盏遗灯，再点潮池。"}
	setup_room(s)
	return s
static func setup_room(s: Dictionary) -> void:
	s.board = []; s.wear = []; s.status = "play"; s.shield = mini(s.shield, 5)
	for t in TOOLS: s.wear.append(t.wear + s.wear_bonus)
	for i in range(20): s.board.append({"kind":"water","hp":0,"timer":0,"attack":0})
	var layouts = [
		[[6,2,3],[8,3,4],[12,1,3],[18,3,4]],
		[[1,3,3],[7,4,4],[9,2,3],[11,2,4],[17,3,3]],
		[[2,4,3],[5,3,4],[7,5,4],[13,2,3],[16,3,4]],
		[[1,5,3],[4,3,4],[6,4,3],[12,4,4],[18,5,4]],
		[[0,4,3],[3,5,4],[7,7,4],[11,3,3],[14,5,4],[18,4,4]]
	]
	for e in layouts[s.room]: s.board[e[0]] = {"kind":"wisp","hp":e[1],"timer":e[2],"attack":1 if s.room < 3 else 2}
	for i in [3, 10, 14]:
		if s.board[i].kind == "water": s.board[i].kind = "powder"
	for i in [4,15]:
		if s.board[i].kind == "water": s.board[i].kind = "coral"
	s.board[19].kind = "beacon"
	s.log = "潮影倒计时归零时袭击；清空潮影即可点亮航标。"
static func affected(tool: int, cell: int) -> Array:
	if tool < 0 or tool >= TOOLS.size() or cell < 0 or cell >= 20: return []
	var ids: Array = [cell]
	var x = cell % 5; var y = cell / 5
	match TOOLS[tool].pattern:
		"row":
			ids = []
			for xx in range(5): ids.append(int(y) * 5 + xx)
		"column":
			ids = []
			for yy in range(4): ids.append(yy * 5 + x)
		"cross":
			for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var p = Vector2i(x,int(y)) + off
				if p.x >= 0 and p.x < 5 and p.y >= 0 and p.y < 4: ids.append(p.y * 5 + p.x)
	return ids
static func act(s: Dictionary, tool: int, cell: int) -> bool:
	if s.status != "play" or tool < 0 or tool >= 6 or cell < 0 or cell >= 20 or s.wear[tool] <= 0: return false
	var ids = affected(tool,cell)
	var useful = false
	for i in ids:
		if s.board[i].kind != "water": useful = true
	if not useful: s.log = "这里已经平静了，试试别处。"; return false
	s.wear[tool] -= 1; s.moves += 1
	var events: Array[String] = []
	var visited: Array = []
	for i in ids: hit(s,i,TOOLS[tool].power,tool,visited,events)
	var remaining = 0
	for c in s.board:
		if c.kind == "wisp": remaining += 1
	if remaining == 0:
		s.status = "won" if s.room == 4 else "upgrade"
		s.log = "航标点亮！潮影消散，选择一份漂流礼物。"; return true
	var damage = 0
	for c in s.board:
		if c.kind == "wisp":
			c.timer -= 1
			if c.timer <= 0: damage += c.attack; c.timer = 3
	var absorbed = mini(s.shield, damage); s.shield -= absorbed; damage -= absorbed; s.hp -= damage
	if damage > 0: events.append("潮影袭击 −%d 心火" % damage)
	if s.hp <= 0: s.hp = 0; s.status = "lost"
	var total = 0
	for w in s.wear: total += w
	if total == 0 and s.status == "play": s.status = "lost"; events.append("遗灯耗尽")
	s.log = " · ".join(events) if not events.is_empty() else "光芒落下，潮影正在靠近。"
	return true
static func hit(s: Dictionary, i: int, power: int, tool: int, visited: Array, events: Array[String]) -> void:
	var c = s.board[i]
	if c.kind == "wisp":
		if c.hp == power:
			s.exact += 1; s.shield = mini(8,s.shield+1); s.wear[tool] = mini(TOOLS[tool].wear+s.wear_bonus,s.wear[tool]+1)
			events.append("精准！返还耐久 + 护光")
		c.hp -= power
		if c.hp <= 0: c.kind = "water"
	elif c.kind == "powder" and i not in visited:
		visited.append(i); c.kind = "water"; events.append("盐晶连爆")
		for j in affected(4,i):
			if j != i: hit(s,j,s.blast,tool,visited,events)
	elif c.kind == "coral":
		c.kind = "water"; s.hp = mini(s.max_hp,s.hp+3); events.append("珊瑚 +3 心火")
	elif c.kind == "beacon":
		c.kind = "water"; s.shield = mini(8,s.shield+3); events.append("航灯 +3 护光")
static func upgrade(s: Dictionary, choice: int) -> bool:
	if s.status != "upgrade" or choice < 0 or choice > 2: return false
	match choice:
		0: s.max_hp += 3; s.hp = mini(s.max_hp,s.hp+7)
		1: s.wear_bonus += 1; s.hp = mini(s.max_hp,s.hp+3)
		2: s.blast += 1; s.hp = mini(s.max_hp,s.hp+3)
	s.room += 1; setup_room(s); return true
