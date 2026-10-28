extends SceneTree
const Rotation = preload("res://app/portal_rotation.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void:
	var model = Rotation.new(); model.rng.seed = 42
	var pool := ["a","b","c","d","e","f","g"]
	var selection: Array = model.reconcile(pool)
	check(selection.size()==4,"four recommendations")
	check(model.reconcile(pool)==selection,"repeat entry never reshuffles")
	var seen: Dictionary = {}
	for cycle in 500:
		var previous: Array = model.selected.duplicate()
		selection = model.shuffle(pool)
		check(selection.size()==4,"bounded selection")
		var unique := {}
		for id in selection: unique[id]=true; seen[id]=true; check(id in pool,"known IDs only")
		check(unique.size()==4,"without replacement")
		check(selection.any(func(id):return id not in previous),"refresh includes a new recommendation")
	check(seen.size()==7,"every game appears")
	var before: Array = model.selected.duplicate()
	pool.erase(before[1])
	selection=model.reconcile(pool)
	for i in [0,2,3]: check(selection[i]==before[i],"repair keeps unaffected fixed slots")
	check(selection[1]!=before[1],"only missing entry repaired")
	for count in 5:
		var small: Array = []
		for i in count: small.append("g%d"%i)
		check(model.reconcile(small).size()==count,"no fake doors when less than four")
	check(not model.restore({"schema_version":true,"selected":[],"appearances":{},"revision":0}),"boolean is not version")
	check(not model.restore({"schema_version":2,"selected":[],"appearances":{},"revision":0}),"future version retained")
	check(not model.restore({"schema_version":1,"selected":["a","a"],"appearances":{},"revision":0}),"duplicate persisted IDs rejected")
	check(not model.restore({"schema_version":1,"selected":["../bad"],"appearances":{},"revision":0}),"unsafe IDs rejected")
	check(not model.restore({"schema_version":1,"selected":[],"appearances":{"a":INF},"revision":0}),"nonfinite weights rejected")
	print("PORTAL ROTATION: ",checks," checks; ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
