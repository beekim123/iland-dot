extends SceneTree
func _initialize():
 call_deferred("_run")
func _run():
 var args=OS.get_cmdline_user_args()
 var path=args[0]
 var doc=GLTFDocument.new()
 var state=GLTFState.new()
 var err=doc.append_from_file(path,state)
 if err!=OK:
  push_error('append failed %s'%err);quit(2);return
 var scene=doc.generate_scene(state)
 root.add_child(scene)
 var result={"path":path,"skeletons":[],"skinned_meshes":[],"animations":{},"weapon":{},"errors":[]}
 scan(scene,result)
 var skeleton=scene.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
 var player=scene.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var grip=scene.find_child("GunGrip",true,false) as Node3D
 var muzzle=scene.find_child("Muzzle",true,false) as Node3D
 var nozzle=scene.find_child("AimNozzle",true,false) as Node3D
 var hand=skeleton.find_bone("Hand.R")
 var errors={}
 for name in player.get_animation_list():
  var clip=player.get_animation(name)
  player.play(name)
  var maximum=0.0
  for frame in range(int(clip.length*240)+1):
   player.seek(minf(frame/240.0,clip.length),true)
   skeleton.force_update_all_bone_transforms()
   var palm=skeleton.global_transform*skeleton.get_bone_global_pose(hand).origin
   maximum=maxf(maximum,palm.distance_to(grip.global_position))
  errors[name]=maximum
  if maximum>.003:result.errors.append("Palm drift "+name+" "+str(maximum))
 result["actual_bone_palm_grip_error"]=errors
 result["animation_player_path"]=str(player.get_path())
 if player.has_animation("run"):
  var stance=.2
  var report=[]
  player.play("run")
  for side in ["L","R"]:
   var index=skeleton.find_bone("Foot."+side)
   var start=0.0 if side=="L" else .3
   player.seek(start,true);skeleton.force_update_all_bone_transforms()
   var first=skeleton.get_bone_global_pose(index).origin
   var slip=0.0
   var final_position=first
   for step in 49:
    var elapsed=stance*float(step)/48.0
    player.seek(start+elapsed,true);skeleton.force_update_all_bone_transforms()
    final_position=skeleton.get_bone_global_pose(index).origin
    var forward_slip=(final_position.z-first.z)*1.3-4.6*elapsed/2.6
    slip=maxf(slip,absf(forward_slip))
   report.append({"foot":side,"clip_stance_seconds":stance,"world_stance_seconds_at_2_6x":stance/2.6,"world_contact_speed":(final_position.z-first.z)*1.3/(stance/2.6),"predicted_world_foot_slip_during_contact":slip})
  result["run_contact_4_6_world_per_second"]=report
 var fixed_muzzle=muzzle.global_position
 var fixed_grip=grip.global_position
 var nozzle_checks=[]
 for pitch in [-.75,-.4,0.0,.4,.70]:
  nozzle.rotation.x=pitch
  nozzle.force_update_transform()
  var delta=maxf(muzzle.global_position.distance_to(fixed_muzzle),grip.global_position.distance_to(fixed_grip))
  nozzle_checks.append({"pitch":pitch,"muzzle_or_grip_drift":delta})
  if delta>.000001:result.errors.append("Nozzle moved fixed grip/muzzle")
 result["nozzle_pitch_checks"]=nozzle_checks
 nozzle.rotation.x=0
 print('GODOT_RIG_PROBE '+JSON.stringify(result))
 quit(0 if result.skeletons.size()>0 and result.skinned_meshes.size()>0 and result.animations.size()>0 and result.errors.size()==0 else 3)
func scan(n:Node,r:Dictionary):
 if n is Skeleton3D:
  var names=[]
  for i in n.get_bone_count():names.append(n.get_bone_name(i))
  r.skeletons.append({"path":str(n.get_path()),"bone_count":n.get_bone_count(),"bones":names})
 if n is MeshInstance3D and n.skin:
  var count=0;var multi=0
  for si in n.mesh.get_surface_count():
   var arrays=n.mesh.surface_get_arrays(si)
   if arrays[Mesh.ARRAY_WEIGHTS]!=null:
    var w=arrays[Mesh.ARRAY_WEIGHTS]
    var inf=8 if n.mesh.surface_get_format(si)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
    count+=w.size()/inf
    for i in range(0,w.size(),inf):
     var nonzero=0
     for j in inf:
      if w[i+j]>.01:nonzero+=1
     if nonzero>1:multi+=1
  r.skinned_meshes.append({"name":n.name,"skin_binds":n.skin.get_bind_count(),"vertices":count,"multi_bone_vertices":multi,"skeleton_path":str(n.skeleton)})
 if n is AnimationPlayer:
  for a in n.get_animation_list():
   var anim=n.get_animation(a)
   r.animations[a]={"length":anim.length,"tracks":anim.get_track_count()}
 if n.name in ["Weapon","Muzzle","GunGrip","AimNozzle"]:
  r.weapon[n.name]={"path":str(n.get_path()),"local":str(n.position),"global":str(n.global_position)}
 for c in n.get_children():scan(c,r)
