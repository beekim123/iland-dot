extends SceneTree
var module
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.remove_absolute("user://games/tide_lantern/run.json")
	module=load("res://modules/tide_lantern/main.tscn").instantiate()
	root.add_child(module); module.start({"game_id":"tide_lantern","schema_version":1})
	await process_frame
	assert(module.started and module.intro)
	module.action("begin"); assert(not module.intro)
	module.play_cell(6); assert(module.state.exact==1)
	module.action("undo"); assert(module.state.exact==0 and module.undo_used)
	module.action("pause"); assert(module.paused)
	module.action("pause"); assert(not module.paused)
	module.reset_run(); assert(not module.undo_used and module.state.room==0)
	module.state.hp=1
	for c in module.state.board:
		if c.kind=="wisp": c.timer=1
	module.selected=0; module.play_cell(8); assert(module.state.status=="lost")
	module.action("retry"); assert(module.state.status=="play" and module.state.hp==18)
	module.action("mute"); assert(module.muted)
	var seen=[0]
	module.exit_requested.connect(func(): seen[0]+=1)
	module.request_exit(); module.request_exit(); assert(seen[0]==1)
	module.queue_free(); await create_timer(0.25).timeout
	print("Tide Lantern runtime: intro/action/undo/pause/loss/retry/mute/idempotent exit passed")
	quit()
