extends SceneTree
class Store extends RefCounted:
	var value: Dictionary = {}
	var writes := 0
	func load_game(_id: String) -> Dictionary: return value
	func save_game(_id: String, data: Dictionary) -> void:
		writes += 1; value = data
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://modules/gummy_bomber/main.tscn").instantiate()
	root.add_child(game)
	var legacy := Store.new(); legacy.value = {"highscore": 777}
	game.start({"save_service": legacy, "seed": 42})
	game.save_score()
	var ok: bool = game.highscore == 777 and legacy.value.get("schema_version") == 1
	var future := Store.new(); future.value = {"schema_version": 2, "highscore": 999, "unknown": "preserve"}
	game.start({"save_service": future, "seed": 42}); game.save_score()
	ok = ok and future.writes == 0 and future.value.unknown == "preserve"
	game.leave_game(); game.queue_free()
	await create_timer(0.5).timeout
	print("GUMMY SAVE SCHEMA legacy migration + future preservation: ", ok)
	quit(0 if ok else 1)
