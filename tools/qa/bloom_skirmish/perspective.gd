extends SceneTree
## Independent shoulder-camera, pointer lifecycle, aim/physics and authority probes.
const Game = preload("res://modules/bloom_skirmish/main.tscn")
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok and failures.size() < 60:
  failures.append(label)
  printerr("FAIL ",label)
func press(code: int) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode=code; event.pressed=true
 return event
func capture_requested(game) -> bool:
 # Dummy DisplayServer cannot exercise OS pointer lock; native QA owns that check.
 return game.pointer_active and (DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
func probe_muzzle_alignment(game) -> int:
 # Measure actual animated world transforms, including runtime scale/root offset.
 # Use the imported model's actual named marker, not an arbitrary mesh centroid.
 var cases := 0
 for heading in 6:
  var facing := Vector2.from_angle(TAU*heading/6.0)
  var side := Vector2(-facing.y,facing.x)
  for pitch in [-.75,-.4,0.0,.28,.70]:
   for pose in [{"run":0.0,"shoot":false,"dash":false},{"run":1.0,"shoot":false,"dash":false},{"run":1.0,"shoot":true,"dash":false},{"run":1.0,"shoot":true,"dash":true}]:
    for phase in [0.0,.17,.66,1.21]:
     game.elapsed=phase
     for actor in game.sim.actors:
      actor.aim=facing
      actor.shot_cd=.07 if pose.shoot else 0.0
      actor.dash_left=.1 if pose.dash else 0.0
      game.previous_positions[actor.id]=actor.pos-facing*game.sim.MOVE_SPEED*.02*pose.run
      game.shot_pitches[actor.id]=pitch
     game._sync_visuals(.02)
     for actor in game.sim.actors:
      var rig: Node3D=game.actor_cache[actor.id]
      var muzzle: Node3D=rig.get_node_or_null("Weapon/Muzzle")
      check(muzzle!=null,"imported athlete exposes its actual physical nozzle marker")
      if muzzle==null: continue
      var actual := muzzle.global_position
      var physical: Vector3=Vector3(actor.pos.x,game.sim.SHOT_HEIGHT,actor.pos.y)+Vector3(facing.x,0,facing.y)*game.sim.MUZZLE_FORWARD+Vector3(side.x,0,side.y)*game.sim.MUZZLE_SIDE
      check(actual.is_finite() and actual.distance_to(physical)<.002,"animated nozzle matches physical emission: actor=%d yaw=%d pitch=%.2f phase=%.2f pose=%s error=%.5f"%[actor.id,heading,pitch,phase,pose,actual.distance_to(physical)])
      if heading==0 and is_zero_approx(phase):
       var skeleton:=rig.get_meta("skeleton") as Skeleton3D
       var head:=skeleton.find_bone("Head")
       var grip:=rig.get_node_or_null("Weapon/GunGrip") as Node3D
       check(head>=0 and grip!=null,"animal aim has real head bone and fixed grip")
       if head>=0 and grip!=null:
        var grip_before:=grip.global_position
        game._apply_weapon_pitch(rig,0)
        var base_head:=skeleton.get_bone_pose_rotation(head)
        game._apply_weapon_pitch(rig,pitch)
        var aimed_head:=skeleton.get_bone_pose_rotation(head)
        check(absf(base_head.angle_to(aimed_head)-absf(pitch)*.25)<.002,"head follows one quarter of aim pitch rather than remaining rigid")
        game._apply_weapon_pitch(rig,pitch)
        check(skeleton.get_bone_pose_rotation(head).angle_to(aimed_head)<.001,"repeated same-frame aim never accumulates head rotation")
        game._apply_weapon_pitch(rig,0)
        check(skeleton.get_bone_pose_rotation(head).angle_to(base_head)<.001,"return to neutral aim restores clip's original head pose")
        game._apply_weapon_pitch(rig,pitch)
        check(grip.global_position.distance_to(grip_before)<.0001 and muzzle.global_position.distance_to(physical)<.002,"head/nozzle aiming leaves grip and physical emission fixed")
      cases+=1
 return cases
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 var game = Game.instantiate(); root.add_child(game)
 game.start({"seed":4601}); game.set_process(false); game.sim.bots_enabled=false
 check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE,"actual perspective camera, not renamed orthographic")
 check(not game.pointer_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"start waits for intentional capture click")
 var initial_time: float = game.countdown_left
 game.previous_ticks = Time.get_ticks_usec() - 500000
 game._process(.001)
 check(game.countdown_left == initial_time and game.sim.time_left == 180,"waiting for capture never runs the round invisibly")
 var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
 game._unhandled_input(click)
 check(capture_requested(game) and not game.shoot_held,"capture click is consumed, not also a shot")
 game.countdown_left=0; game.input_guard=0
 # Movement uses the camera's actual projected forward/right, including diagonal normalization.
 for yaw in [-PI,-PI*.5,0.0,PI*.5,PI*.25]:
  game.camera_yaw=yaw; game.camera_pitch=-.4; game._update_camera(0,true)
  var forward3: Vector3 = -game.camera.global_basis.z
  var forward := Vector2(forward3.x,forward3.z).normalized()
  var right3: Vector3 = game.camera.global_basis.x
  var right := Vector2(right3.x,right3.z).normalized()
  for pair in [[KEY_W,forward],[KEY_S,-forward],[KEY_D,right],[KEY_A,-right]]:
   game.keys={pair[0]:true}
   var command: Dictionary = game._command()
   check(Vector2(command.move).is_equal_approx(pair[1]),"WASD follows camera yaw")
  game.keys={KEY_W:true,KEY_D:true}
  check(is_equal_approx(Vector2(game._command().move).length(),1.0),"camera-relative diagonal speed is normalized")
 game.clear_input()
 var motion := InputEventMouseMotion.new(); motion.relative=Vector2(250,10000)
 game._unhandled_input(motion)
 check(is_equal_approx(game.camera_pitch,-.75),"down-look pitch has a finite clamp")
 motion.relative=Vector2(0,-20000); game._unhandled_input(motion)
 check(is_equal_approx(game.camera_pitch,.28),"up-look pitch has a finite clamp")
 # Camera boom must stay outside actual solid cover for legal nearby actor positions.
 var camera_cases := 0
 for point in [Vector2(6.6,6),Vector2(12.4,6),Vector2(13.6,12),Vector2(18.4,12),Vector2(16,9.6),Vector2(16,14.4),Vector2(.4,.4),Vector2(31.6,23.6),Vector2(5,12)]:
  game.sim.actors[0].pos=point
  for angle in 24:
   game.camera_yaw=TAU*angle/24.0
   for pitch in [-.75,-.16,.28]:
    game.camera_pitch=pitch; game._update_camera(0,true)
    var camera_pos: Vector3 = game.camera.position
    check(camera_pos.is_finite() and camera_pos.y >= .279,"finite camera above floor")
    for rect in game.sim.obstacles:
     var solid := AABB(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.size.x,game.sim.OBSTACLE_HEIGHT,rect.size.y)).grow(.075)
     check(not solid.has_point(camera_pos),"camera near plane does not enter solid cover")
    camera_cases+=1
 var safe: Vector3 = game.camera_safe_position(Vector3(12,.8,12),Vector3(20,.8,12))
 check(safe.x < 14.0 and safe.x > 12.0,"camera obstruction shortens a horizontal boom at a wall")
 var muzzle_cases := probe_muzzle_alignment(game)
 # Fixed center reticle, not free-screen mouse position; solve a nearby unobstructed floor hit.
 game.sim.start(4601); game.sim.bots_enabled=false; game.countdown_left=0
 game.sim.actors[0].pos=Vector2(5,2)
 game.camera_yaw=-PI*.5; game.camera_pitch=-.4
 game._update_camera(0,true); game._update_aim()
 check(game.aim_has_hit and absf(game.aim_world.y) < .01,"center ray resolves physical ground")
 var screen_center := game.get_viewport().get_visible_rect().size*.5
 check(game.camera.unproject_position(game.aim_world).distance_to(screen_center)<.1,"aim point projects precisely to center reticle")
 var target: Vector3 = game.aim_world
 game.shoot_held=true
 var command: Dictionary = game._command()
 check(command.has("aim_world") and not command.has("aim_direction"),"hit-target input cannot be overridden by sky direction")
 game.sim.step(1.0/60.0,command)
 game.shoot_held=false
 var impact := Vector3.INF
 for frame in 150:
  game.sim.step(1.0/60.0,{})
  for event in game.sim.events:
   if event.type=="splash" and event.get("surface","")=="ground": impact=event.world_pos
  if impact.is_finite(): break
 check(impact.is_finite() and impact.distance_to(target)<.09,"physical ballistic impact converges to nearby center-reticle point")
 # A raised sky ray must retain vertical direction rather than flattening onto the floor.
 game.sim.start(4601); game.sim.bots_enabled=false; game.sim.actors[0].pos=Vector2(5,2)
 game.camera_yaw=-PI*.5; game.camera_pitch=.24; game._update_camera(0,true); game._update_aim()
 game.shoot_held=true; command=game._command(); game.shoot_held=false
 check(not game.aim_has_hit and command.has("aim_direction") and not command.has("aim_world"),"sky aiming preserves a 3D direction")
 game.sim.step(1.0/60.0,command)
 check(not game.sim.projectiles.is_empty() and game.sim.projectiles[0].velocity.y>0,"upward aim creates an upward ballistic shot")
 # Shoulder camera visibility may never teleport a muzzle beyond the near wall.
 game.sim.start(4601); game.sim.bots_enabled=false; game.sim.actors[0].pos=Vector2(13.5,12)
 game.sim.step(1.0/60.0,{"aim":Vector2(20,12),"aim_world":Vector3(20,.9,12),"shoot":true})
 var wall_seen := false
 for event in game.sim.events:
  if event.type=="splash":
   wall_seen = event.surface=="wall" and event.world_pos.x<14.01
 check(wall_seen and game.sim.projectiles.is_empty(),"center-to-muzzle sweep blocks barrel protrusion through wall")
 check(game.sim.owner_at(Vector2(18.25,12.25))==-1,"near-wall shot does not score behind cover")
 # CPU ownership upload must be exactly the same fine mask used to count coverage.
 game.sim.start(4601); game.sim.bots_enabled=false
 game.sim._paint_splat(Vector2(6,2),1.2,0,0,17)
 game.sim._paint_splat(Vector2(6.5,2.5),1.2,1,2,18)
 game._update_turf(true)
 check(game.turf_image.get_size()==Vector2i(game.sim.GRID_W,game.sim.GRID_H),"visual texture uses authoritative fine resolution")
 var owned := [0,0]
 for y in game.sim.GRID_H:
  for x in game.sim.GRID_W:
   var value: int = game.sim.ownership[y*game.sim.GRID_W+x]
   var pixel: Color = game.turf_image.get_pixel(x,y)
   check(is_equal_approx(pixel.r,1.0 if value==0 else 0.0) and is_equal_approx(pixel.g,1.0 if value==1 else 0.0),"render upload exactly matches ownership texel")
   if value>=0: owned[value]+=1
 check(owned==game.sim.score_cells,"same fine ownership pixels determine score")
 var material: ShaderMaterial = game.floor_mesh.material_override
 check(material.get_shader_parameter("coverage_map")==game.turf_texture,"ground material consumes verified ownership texture")
 # All interruption paths release capture and held inputs. Replay reacquires only intentionally.
 game._capture_mouse(); game.shoot_held=true; game.keys={KEY_W:true}
 game.set_paused(true)
 check(not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and game.keys.is_empty() and not game.shoot_held,"pause releases cursor and held inputs")
 var paused_yaw: float = game.camera_yaw
 motion.relative=Vector2(200,200); game._unhandled_input(motion)
 check(game.camera_yaw==paused_yaw,"paused mouse motion cannot rotate camera")
 game.set_paused(false)
 check(capture_requested(game),"resume intentionally reacquires pointer")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.paused and not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"focus loss releases mouse capture")
 game.restart(); game.set_process(false); game.sim.bots_enabled=false; game.countdown_left=0
 check(capture_requested(game),"replay button starts captured play cleanly")
 game.step_simulation(180.0)
 check(game.sim.state=="finished" and not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"results release pointer for replay and exit buttons")
 game.restart(); game.set_process(false); game.leave_game()
 check(not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"exit restores previous mouse mode")
 game.queue_free(); await process_frame; await process_frame; await create_timer(.5).timeout
 print("OS pointer capture verified: ", DisplayServer.get_name()!="headless", "; intent and release paths checked")
 print("BLOOM INDEPENDENT PERSPECTIVE: %d checks, %d failures; %d camera poses; %d animated muzzle poses; fine-mask and physical-aim probes" % [checks,failures.size(),camera_cases,muzzle_cases])
 quit(0 if failures.is_empty() else 1)
