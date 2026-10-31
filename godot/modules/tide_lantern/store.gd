extends RefCounted
const PATH = "user://games/tide_lantern/run.json"
const Rules = preload("rules.gd")
static func valid(s: Variant) -> bool:
	if not s is Dictionary: return false
	for key in ["room","hp","max_hp","shield","wear_bonus","blast","exact","moves","status","board","wear","log"]:
		if not s.has(key): return false
	for key in ["room","hp","max_hp","shield","wear_bonus","blast","exact","moves"]:
		if not (s[key] is int or s[key] is float): return false
		if float(s[key]) != floor(float(s[key])): return false
	if s.room<0 or s.room>4 or s.hp<1 or s.hp>s.max_hp or s.max_hp<18 or s.max_hp>30: return false
	if s.shield<0 or s.shield>8 or s.wear_bonus<0 or s.wear_bonus>4 or s.blast<2 or s.blast>6: return false
	if s.exact<0 or s.exact>500 or s.moves<0 or s.moves>1000 or not s.log is String: return false
	if s.status not in ["play","upgrade"] or (s.status=="upgrade" and s.room==4): return false
	if not s.board is Array or s.board.size()!=20 or not s.wear is Array or s.wear.size()!=6: return false
	for i in range(6):
		if not (s.wear[i] is int or s.wear[i] is float): return false
		if s.wear[i]<0 or s.wear[i]>Rules.TOOLS[i].wear+s.wear_bonus: return false
	var enemies=0
	for c in s.board:
		if not c is Dictionary or not c.has_all(["kind","hp","timer","attack"]): return false
		if c.kind not in ["water","wisp","powder","coral","beacon"]: return false
		for key in ["hp","timer","attack"]:
			if not (c[key] is int or c[key] is float): return false
		if c.kind=="wisp":
			enemies+=1
			if c.hp<1 or c.hp>7 or c.timer<1 or c.timer>4 or c.attack<1 or c.attack>2: return false
	return enemies>0 if s.status=="play" else enemies==0
static func load_run() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var json=JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH))!=OK: return {}
	var data=json.data
	if not data is Dictionary or data.get("schema",0)!=1 or not valid(data.get("state")): return {}
	if not data.get("undo_used") is bool: return {}
	var previous=data.get("undo",{})
	if not previous is Dictionary: return {}
	if not previous.is_empty() and (not valid(previous) or previous.status!="play" or previous.room!=data.state.room): return {}
	normalize(data.state)
	if not previous.is_empty(): normalize(previous)
	return data
static func normalize(s: Dictionary) -> void:
	for key in ["room","hp","max_hp","shield","wear_bonus","blast","exact","moves"]: s[key]=int(s[key])
	for i in range(6): s.wear[i]=int(s.wear[i])
	for c in s.board:
		for key in ["hp","timer","attack"]: c[key]=int(c[key])
static func save_run(s: Dictionary, undo: Dictionary, used: bool) -> void:
	if s.status not in ["play","upgrade"]:
		DirAccess.remove_absolute(PATH); return
	if not valid(s): return
	DirAccess.make_dir_recursive_absolute("user://games/tide_lantern")
	var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"schema":1,"state":s,"undo":undo,"undo_used":used})); file.close()
		DirAccess.rename_absolute(PATH+".tmp",PATH)
