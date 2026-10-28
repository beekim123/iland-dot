extends SceneTree
const F = preload("res://modules/tide_gulp/art/tide_art_factory.gd")
func _initialize():
 var start=Time.get_ticks_msec();var factory=F.new();var species=["silver","fan","leaf","ribbon","lantern","parrot","sailjaw","whalejaw"]
 var fish=[]
 for i in 64:
  var f=factory.make_fish(species[i%8],0);root.add_child(f);fish.append(f)
 var player=factory.make_fish("moonfish",0);root.add_child(player);fish.append(player)
 var setup_ms=Time.get_ticks_msec()-start;start=Time.get_ticks_msec()
 for frame in 120:
  for f in fish:
   f.set_motion(3,.2,.0,.0,false);f.tick_pose(1.0/60.0,frame/60.0)
 print("TIDE_POOL_CPU_CHECK nodes=65 setup_ms=",setup_ms," 120_pose_frames_ms=",Time.get_ticks_msec()-start," (headless CPU only; not a GPU FPS claim)")
 for f in fish:f.free()
 quit()
