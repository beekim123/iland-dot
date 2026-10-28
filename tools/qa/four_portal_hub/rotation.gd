extends SceneTree
## Independent black-box properties of the production rotation/save API.
const Rotation = preload("res://app/portal_rotation.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40:
		failures.append(label); printerr("FAIL: ", label)
func unique(values: Array) -> int:
	var seen := {}
	for value in values: seen[value] = true
	return seen.size()
func valid_selection(values: Array, pool: Array, label: String) -> void:
	check(values.size() == mini(4, pool.size()), label+": bounded count")
	check(unique(values) == values.size(), label+": no repeated game")
	for value in values: check(value in pool, label+": member belongs to eligible pool")
func set_of(values: Array) -> Array:
	var copy := values.duplicate(); copy.sort(); return copy
func write(path: String, data: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var handle := FileAccess.open(path, FileAccess.WRITE)
	check(handle != null, "QA fixture writable")
	if handle: handle.store_string(data); handle.close()
func run() -> void:
	var displayed := {}
	for size in range(10):
		var pool: Array = []
		for index in size: pool.append("game_%d" % index)
		for seed_number in range(30):
			var rotation = Rotation.new(); rotation.rng.seed = seed_number
			var initial: Array = rotation.reconcile(pool)
			valid_selection(initial, pool, "initial %d/%d" % [size, seed_number])
			var original: Dictionary = rotation.snapshot()
			check(rotation.reconcile(pool) == initial, "reconcile never silently rotates valid session")
			check(rotation.snapshot() == original, "repeated reconcile does not inflate exposure statistics")
			for refresh in range(15):
				var previous := set_of(rotation.selected)
				var current: Array = rotation.shuffle(pool)
				valid_selection(current, pool, "refresh %d/%d/%d" % [size,seed_number,refresh])
				if size > 4: check(set_of(current) != previous, "refresh actually replaces an offer when alternatives exist")
				for id in current: displayed[id] = true
			var restored = Rotation.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(rotation.snapshot()))), "serialized snapshot roundtrip accepted")
			check(restored.reconcile(pool) == rotation.selected, "restart retains exact game/slot choices")
	check(displayed.size() == 9, "all nine pool members appear across deterministic sample, not a universal fairness claim")
	var rotation = Rotation.new(); rotation.rng.seed = 5
	var pool: Array = ["a","b","c","d","e"]
	rotation.reconcile(pool)
	var original: Array = rotation.selected.duplicate()
	var removed: String = original[1]
	pool.erase(removed); pool.append("new_game")
	var changed: Array = rotation.reconcile(pool)
	check(changed[0]==original[0] and changed[2]==original[2] and changed[3]==original[3], "repair only invalid slot, preserving other displayed slots")
	check(changed[1] != removed and changed[1] in pool, "unavailable game replaced from current pool")
	valid_selection(rotation.reconcile(["a","b"]), ["a","b"], "pool shrinks below four")
	valid_selection(rotation.reconcile([]), [], "no usable game means no fake portal")
	var entries: Array = [{"id":"a","enabled":true},{"id":"a","enabled":true},{"id":"b","enabled":true},{"id":"planned","enabled":false},{"id":"no_flag"}]
	valid_selection(rotation.reconcile(entries), ["a","b"], "duplicate/disabled metadata filtered")
	var stable: Dictionary = rotation.snapshot()
	for malformed in [null, [], {}, {"schema_version":1,"selected":[],"appearances":{},"revision":0,"future":"preserve"}, {"schema_version":2,"selected":[],"appearances":{},"revision":0},
		{"schema_version":true,"selected":[],"appearances":{},"revision":0},
		{"schema_version":1,"selected":["a","a"],"appearances":{},"revision":0},
		{"schema_version":1,"selected":["../other"],"appearances":{},"revision":0},
		{"schema_version":1,"selected":["a","b","c","d","e"],"appearances":{},"revision":0},
		{"schema_version":1,"selected":[],"appearances":{"a":-1},"revision":0},
		{"schema_version":1,"selected":[],"appearances":{"a":true},"revision":0},
		{"schema_version":1,"selected":[],"appearances":{"a":INF},"revision":0},
		{"schema_version":1,"selected":[],"appearances":{},"revision":0.5}]:
		check(not rotation.restore(malformed), "malformed/future state rejected")
		check(rotation.snapshot()==stable, "rejected restore is atomic, no partial mutation")
	# Unknown, well-formed IDs are a normal registry-version change, not corruption.
	check(rotation.restore({"schema_version":1,"selected":["old_game","a","b"],"appearances":{},"revision":0}), "old valid identifier is structurally accepted")
	var repaired: Array = rotation.reconcile(["a","b","c","d","e"])
	check(not "old_game" in repaired and repaired[1]=="a" and repaired[2]=="b", "removed game repaired after loading without shuffling surviving slots")
	storage()
	print("FOUR PORTAL INDEPENDENT ROTATION: %d checks; %s" % [checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
func storage() -> void:
	var path: String = Rotation.SAVE_PATH
	check(path=="user://hub/portal_rotation.json", "hub storage has fixed isolated path")
	DirAccess.make_dir_recursive_absolute("user://hub")
	var protected := {}
	for id in ["gummy_bomber","bloom_skirmish","tide_gulp","beach_cleanup","volcano_escape"]:
		var other := "user://games/%s/profile.json" % id
		write(other,"QA SENTINEL "+id); protected[other] = FileAccess.get_file_as_bytes(other)
	DirAccess.remove_absolute(path)
	var first = Rotation.new(); check(first.load_profile(), "new profile load allowed")
	first.reconcile(["a","b","c","d","e"])
	check(first.save_profile(), "new selection saves atomically")
	check(not FileAccess.file_exists(path+".tmp") and not DirAccess.dir_exists_absolute(path+".lock"), "successful write leaves no transaction state")
	var second = Rotation.new(); check(second.load_profile(), "new model reads disk")
	check(second.selected==first.selected and second.revision==first.revision and second.appearances.size()==first.appearances.size(), "disk restores exact choices/revision and bounded exposure keys")
	for id in first.appearances: check(int(second.appearances.get(id,-1))==int(first.appearances[id]), "disk restores exposure count; JSON number representation is not gameplay state")
	first.shuffle(["a","b","c","d","e"]); check(first.save_profile(), "fresh writer advances profile")
	var latest := FileAccess.get_file_as_string(path)
	second.shuffle(["a","b","c","d","e"])
	check(not second.save_profile() and FileAccess.get_file_as_string(path)==latest, "stale writer cannot overwrite changed disk state")
	for corrupt in ["{broken", "[]", "null", '{"schema_version":99,"future":"keep"}']:
		write(path,corrupt)
		var reader = Rotation.new(); check(not reader.load_profile(), "unreadable schema flagged")
		reader.reconcile(["a","b","c","d","e"])
		check(reader.selected.size()==4, "corrupt save does not prevent in-memory play")
		check(not reader.save_profile() and FileAccess.get_file_as_string(path)==corrupt, "corrupt/future save preserved, never silently replaced")
	write(path,JSON.stringify(first.snapshot()))
	var locked = Rotation.new(); check(locked.load_profile(), "read normal profile for lock fixture")
	DirAccess.make_dir_absolute(path+".lock")
	check(not locked.save_profile(), "existing concurrent-writer lock respected")
	DirAccess.remove_absolute(path+".lock")
	write(path+".tmp","pending transaction")
	check(not locked.save_profile() and FileAccess.get_file_as_string(path+".tmp")=="pending transaction", "unknown pending temp retained")
	DirAccess.remove_absolute(path+".tmp")
	for other in protected:
		check(FileAccess.get_file_as_bytes(other)==protected[other], "game namespace never modified by hub save: "+other)
