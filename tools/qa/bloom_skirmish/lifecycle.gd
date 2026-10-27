extends SceneTree
## Independent repeated start/pause/replay/exit/release tests; not graphical QA.
const Game = preload("res://modules/bloom_skirmish/main.tscn")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FAIL ", label)
func skeleton_snapshot(game) -> Dictionary:
 var snapshot := {}
 for skeleton in game.find_children("*","Skeleton3D",true,false):
  var poses: Array = []
  for bone in skeleton.get_bone_count(): poses.append(skeleton.get_bone_pose(bone))
  snapshot[skeleton.get_instance_id()]=poses
 for player in game.find_children("*","AnimationPlayer",true,false):
  snapshot[player.get_instance_id()]=[player.current_animation,player.current_animation_position if not player.current_animation.is_empty() else 0.0]
 return snapshot
func seed_live_entities(game) -> void:
 game.countdown_left = 0.0
 game.sim.bots_enabled = false
 game.sim.actors[0].pos = Vector2(5.5,2.5)
 game.sim._paint_disc(game.sim.actors[0].pos,0.6,0)
 game.sim.deploy_pod(0)
 game.sim._fire(game.sim.actors[0],Vector2(11,2.5))
 game._sync_visuals(0.02)
 game._add_effect({"team":0,"pos":Vector2(5.5,2.5)},0.7,1.0)
 game.fx.impact({"team":0,"world_pos":Vector3(5.5,.2,2.5),"normal":Vector3.UP,"radius":1.4})
 check(game.fx.debug_stats().droplets > 0 and game.fx.debug_stats().splashes > 0,"lifecycle fixture includes live liquid droplets and crowns")
 check(not game.projectile_cache.is_empty() and not game.pod_cache.is_empty() and not game.effects.is_empty(), "lifecycle fixture contains real live transient visuals")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 await process_frame
 var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var object_samples: Array[int] = []
 var initial_quit_policy: bool = auto_accept_quit
 for cycle in 20:
  var game = Game.instantiate()
  root.add_child(game)
  game.start({"seed": cycle + 100})
  await process_frame
  check(game.running and game.has_started, "started %d" % cycle)
  check(game.music != null and game.music.stream is AudioStreamWAV and game.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.music.stream.loop_end > game.music.stream.loop_begin, "music has a real nonempty loop interval")
  check(game.sim.actors.size() == 4, "exactly four gardeners %d" % cycle)
  var species: Array=[]
  for rig in game.actor_cache.values():
   species.append(str(rig.get_meta("species","")))
   check(not rig.find_children("*","Skeleton3D",true,false).is_empty(),"each live animal has a real Skeleton3D, not a human or rigid fallback")
  species.sort()
  check(species==["fox","otter","rabbit","raccoon"],"full four-species cast remains instantiated")
  check(game.find_children("*", "WorldEnvironment", true, false).is_empty(), "no host-global environment")
  seed_live_entities(game)
  game.set_paused(true)
  check(game.paused and not game.pointer_active, "pause releases pointer intent")
  var before: Array = game.sim.actors.duplicate(true)
  var ownership: PackedInt32Array = game.sim.ownership.duplicate()
  var frozen_skeletons := skeleton_snapshot(game)
  await create_timer(.06).timeout
  game._process(0.4)
  check(game.sim.actors == before and game.sim.ownership == ownership, "pause freezes movement and paint")
  check(skeleton_snapshot(game)==frozen_skeletons,"pause freezes actual skeleton poses and AnimationPlayer clocks across real frames")
  game.set_paused(false)
  check(not game.paused, "resume accepted")
  game.restart()
  check(game.running and not game.paused and game.sim.state == "playing", "replay restores playable state")
  check(game.sim.pods.is_empty() and game.sim.projectiles.is_empty(), "replay clears transient actors")
  check(game.projectile_cache.is_empty() and game.pod_cache.is_empty() and game.effects.is_empty() and game.actor_cache.size() == 4, "replay clears live visual caches without duplicating gardeners")
  var clean_fx: Dictionary = game.fx.debug_stats()
  check(clean_fx.projectiles == 0 and clean_fx.droplets == 0 and clean_fx.splashes == 0,"replay clears liquid pool state")
  seed_live_entities(game)
  var received := [0]
  game.exit_requested.connect(func(): received[0] += 1)
  game.leave_game()
  check(not game.running and not game.is_processing() and not game.is_processing_unhandled_input(), "exit stops processing %d" % cycle)
  check(received[0] == 1, "one exit event %d" % cycle)
  check(not game.pointer_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"exit releases captured mouse")
  for voice in game.find_children("*", "AudioStreamPlayer", true, false):
   check(not voice.playing, "audio stopped on exit")
  game.leave_game()
  check(received[0] == 1, "exit is idempotent")
  game.queue_free()
  await process_frame
  await process_frame
  check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline, "no orphan nodes after cycle %d" % cycle)
  check(auto_accept_quit == initial_quit_policy,"module releases ownership of window-close policy")
  object_samples.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
  root.size_changed.emit()
 await create_timer(0.5).timeout
 print("BLOOM INDEPENDENT LIFECYCLE: %d checks, %d failures; baseline orphans=%d; post-free object samples=%s" % [checks, failures.size(), baseline, object_samples])
 quit(0 if failures.is_empty() else 1)
