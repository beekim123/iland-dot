extends SceneTree
## Real imported Skeleton3D/Skin proof. Native mode additionally uses Godot's
## actual skeleton bake API; Dummy/headless only proves CPU-evaluated skinning.
const Art = preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var checks := 0
var failures: Array[String] = []
var native_probe := false
var raw_model := ""
var only_species := ""
var only_team := -1
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok and failures.size()<60:
  failures.append(label);printerr("FAIL ANIMAL SKIN ",label)
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--native-skin-probe":native_probe=true
  elif arg.begins_with("--raw-model="):raw_model=arg.trim_prefix("--raw-model=")
  elif arg.begins_with("--only-species="):only_species=arg.trim_prefix("--only-species=")
  elif arg.begins_with("--only-team="):only_team=int(arg.trim_prefix("--only-team="))
 call_deferred("run")
func refresh(skeleton: Skeleton3D) -> void:
 skeleton.force_update_all_bone_transforms()
func bind_bone(skin: Skin,skeleton: Skeleton3D,index: int) -> int:
 var named:=skin.get_bind_name(index)
 return skeleton.find_bone(named) if not named.is_empty() else skin.get_bind_bone(index)
func weighted_vertices(mesh: MeshInstance3D,surface: int,skeleton: Skeleton3D) -> PackedVector3Array:
 # Consume actual Godot-imported inverse binds and bone poses, independently of
 # node animation metadata or a developer-written claimed-deformation counter.
 var arrays: Array=mesh.mesh.surface_get_arrays(surface)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var stride:=int(weights.size()/vertices.size())
 var transforms: Array[Transform3D]=[]
 for index in mesh.skin.get_bind_count():
  var bone:=bind_bone(mesh.skin,skeleton,index)
  if bone<0: return PackedVector3Array()
  transforms.append(skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(index))
 var result:=PackedVector3Array();result.resize(vertices.size())
 for vertex in vertices.size():
  var point:=Vector3.ZERO
  for slot in stride:
   var index:=vertex*stride+slot
   if weights[index]>0:point+=transforms[bones[index]]*vertices[vertex]*weights[index]
  result[vertex]=point
 return result
func deformation(before: PackedVector3Array,after: PackedVector3Array) -> Dictionary:
 if before.size()!=after.size() or before.is_empty():return {"changed":0,"max":0.0,"shape":0.0}
 var changed:=0;var maximum:=0.0;var shape:=0.0
 for index in before.size():
  var delta:=before[index].distance_to(after[index])
  if delta>.0001:changed+=1
  maximum=maxf(maximum,delta)
  # Compare many non-neighbor pairs: rigid whole-mesh motion preserves distances.
  var other: int=(index*7919+before.size()/2)%before.size()
  shape=maxf(shape,absf(before[index].distance_to(before[other])-after[index].distance_to(after[other])))
 return {"changed":changed,"max":maximum,"shape":shape}
func choose_weighted_surface(rig: Node3D) -> Dictionary:
 var best: Dictionary={};var best_blends:=0
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null:continue
  var skeleton:=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
  check(skeleton!=null,"Skin points to an actual imported Skeleton3D")
  if skeleton==null:continue
  check(mesh.skin.get_bind_count()>0,"Skin contains actual inverse binds")
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_WEIGHTS]==null:continue
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   if vertices.is_empty():continue
   var stride:=int(weights.size()/vertices.size())
   check(stride in [4,8] and bones.size()==weights.size(),"Godot surface retains real 4/8 bone influence arrays")
   if stride not in [4,8] or bones.size()!=weights.size():continue
   var blends:=0;var influence: Dictionary={}
   for vertex in vertices.size():
    var active:=0;var sum:=0.0
    for slot in stride:
     var index:=vertex*stride+slot
     sum+=weights[index]
     if weights[index]>.01:
      active+=1
      var bone:=bind_bone(mesh.skin,skeleton,bones[index])
      if bone>=0 and skeleton.get_bone_parent(bone)>=0 and weights[index]<.99:
       influence[bone]=int(influence.get(bone,0))+1
    check(absf(sum-1.0)<.002,"Godot import retains normalized skin weights")
    if active>=2:blends+=1
   if blends>best_blends and not influence.is_empty():
    var bone: int=influence.keys()[0]
    for candidate in influence:
     if influence[candidate]>influence[bone]:bone=candidate
    best_blends=blends;best={"mesh":mesh,"surface":surface,"skeleton":skeleton,"bone":bone,"blends":blends}
 return best
func probe_grip_tracks(rig: Node3D,skeleton: Skeleton3D,players: Array) -> void:
 var grip:=rig.find_child("GunGrip",true,false) as Node3D
 var muzzle:=rig.find_child("Muzzle",true,false) as Node3D
 var hand:=skeleton.find_bone("Hand.R")
 check(grip!=null and muzzle!=null and hand>=0,"actual palm bone, fixed grip and emission markers exist")
 if grip==null or muzzle==null or hand<0:return
 var grip_anchor:=grip.global_position
 var muzzle_anchor:=muzzle.global_position
 var peak_error:=0.0
 var peak_at:=""
 var samples:=0
 for player in players:
  for clip_name in player.get_animation_list():
   if str(clip_name).to_upper()=="RESET":continue
   var clip: Animation=player.get_animation(clip_name)
   for sample in 13:
    var at: float=clip.length*sample/13.0
    player.play(clip_name);player.seek(at,true);refresh(skeleton)
    var palm: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
    var error:=palm.distance_to(grip.global_position)
    if error>peak_error:peak_error=error;peak_at="%s @ %.6fs"%[clip_name,at]
    check(error<.003,"real Hand.R palm remains on grip across %s at %.3f: %.5fm"%[clip_name,at,error])
    check(grip.global_position.distance_to(grip_anchor)<.002 and muzzle.global_position.distance_to(muzzle_anchor)<.002,"bone clip cannot pull physical gun grip or nozzle off their anchors")
    samples+=1
  player.stop()
 print("ANIMAL_ACTUAL_PALM_GRIP samples=",samples," peak_world_error=",peak_error," at=",peak_at)
func probe_imported_colors(rig: Node3D) -> void:
 var colored_surfaces:=0
 var material_colors: Dictionary={}
 var chromatic_materials:=0
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   check(material!=null,"imported animal surface retains a material")
   if material!=null:
    var color:=material.albedo_color
    check(is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.a>0,"material keeps finite visible albedo")
    material_colors[color.to_html()]=true
    if maxf(absf(color.r-color.g),absf(color.g-color.b))>.03:chromatic_materials+=1
   if arrays[Mesh.ARRAY_COLOR]==null or arrays[Mesh.ARRAY_COLOR].is_empty():continue
   check(material!=null and material.vertex_color_use_as_albedo,"factory enables actual imported animal vertex colors")
   colored_surfaces+=1
 check(colored_surfaces>0 or (material_colors.size()>1 and chromatic_materials>0),"animal retains its authored vertex-color OR material-color palette, not a white fallback")
func run() -> void:
 if native_probe and DisplayServer.get_name()=="headless":
  printerr("Native skin probe requires non-headless Godot; Dummy renderer has no valid skeleton RID.")
  quit(2);return
 await process_frame
 var baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var cases: Array=[]
 if not raw_model.is_empty():cases.append({"path":raw_model,"species":"RAW PILOT","team":-1})
 else:
  for species in ["otter","rabbit","fox","raccoon"]:
   if not only_species.is_empty() and species!=only_species:continue
   for team in 2:
    if only_team<0 or team==only_team:cases.append({"species":species,"team":team})
 check(not cases.is_empty(),"animal probe selects actual models")
 for item in cases:
  var rig: Node3D
  if item.has("path"):
   var scene:=load(item.path) as PackedScene
   if scene:rig=scene.instantiate()
  else:rig=Art.make_animal(item.species,item.team)
  check(rig!=null,"requested animal loads without human fallback")
  if rig==null:continue
  root.add_child(rig)
  if not item.has("path"):
   check(str(rig.get_meta("species",""))==item.species and int(rig.get_meta("team",-1))==item.team,"factory preserves requested species/team")
   check(bool(rig.get_meta("skinned",false)) and "/rigged/" in str(rig.get_meta("asset_path","")),"factory uses actual rigged animal asset, not explicit modeling-preview mode")
   probe_imported_colors(rig)
  var players: Array=rig.find_children("*","AnimationPlayer",true,false)
  check(not players.is_empty(),"animal has an actual AnimationPlayer")
  for player in players:
   player.set_process_callback(AnimationPlayer.ANIMATION_PROCESS_MANUAL);player.stop()
  var skeletons: Array=rig.find_children("*","Skeleton3D",true,false)
  check(not skeletons.is_empty(),"animal has real Skeleton3D, not seven rigid pivots")
  for skeleton in skeletons:skeleton.reset_bone_poses();refresh(skeleton)
  await process_frame
  await process_frame
  if native_probe:await RenderingServer.frame_post_draw
  var selected:=choose_weighted_surface(rig)
  check(not selected.is_empty() and int(selected.get("blends",0))>=16,"real mixed-weight animal surface is available for deformation")
  if selected.is_empty():
   rig.queue_free();await process_frame;continue
  var mesh: MeshInstance3D=selected.mesh
  var skeleton: Skeleton3D=selected.skeleton
  var bone: int=selected.bone
  var surface: int=selected.surface
  var mesh_transform: Transform3D=mesh.global_transform
  var rig_transform: Transform3D=rig.global_transform
  var before:=weighted_vertices(mesh,surface,skeleton)
  var baked_before: ArrayMesh
  if native_probe:baked_before=mesh.bake_mesh_from_current_skeleton_pose()
  var original:=skeleton.get_bone_pose_rotation(bone)
  skeleton.set_bone_pose_rotation(bone,original*Quaternion(Vector3.FORWARD,.55));refresh(skeleton)
  await process_frame
  if native_probe:await RenderingServer.frame_post_draw
  var after:=weighted_vertices(mesh,surface,skeleton)
  var change:=deformation(before,after)
  check(change.changed>=16 and change.max>.005,"actual bone rotation moves weighted animal vertices")
  check(change.shape>.001,"weighted surface changes shape, not merely rigid whole-part transform")
  check(mesh.global_transform==mesh_transform and rig.global_transform==rig_transform,"deformation did not come from moving a Node3D or whole mesh")
  if native_probe:
   var baked_after:=mesh.bake_mesh_from_current_skeleton_pose()
   check(baked_before!=null and baked_after!=null,"native renderer registers real skeleton skin and can bake it")
   if baked_before!=null and baked_after!=null:
    var native_change:=deformation(baked_before.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],baked_after.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
    check(native_change.changed>=16 and native_change.shape>.001,"native Godot skeleton bake proves actual non-rigid mesh deformation")
    print("NATIVE_SKIN_DEFORMATION ",item," bone=",skeleton.get_bone_name(bone)," metrics=",native_change)
  skeleton.set_bone_pose_rotation(bone,original);refresh(skeleton)
  var restored:=weighted_vertices(mesh,surface,skeleton)
  check(deformation(before,restored).max<.00001,"restoring the bone restores the actual mesh, with no deformation drift")
  var animated:=false
  for player in players:
   for clip_name in player.get_animation_list():
    if str(clip_name).to_lower().split("/")[-1]!="run":continue
    var clip: Animation=player.get_animation(clip_name)
    player.play(clip_name);player.seek(clip.length*.13,true);refresh(skeleton)
    var first:=weighted_vertices(mesh,surface,skeleton)
    player.seek(clip.length*.63,true);refresh(skeleton)
    var second:=weighted_vertices(mesh,surface,skeleton)
    var movement:=deformation(first,second)
    check(movement.changed>=16 and movement.max>.001,"actual imported run clip changes weighted mesh via bone tracks")
    animated=true;player.stop()
  check(animated,"actual run animation is present and evaluated, not only named metadata")
  probe_grip_tracks(rig,skeleton,players)
  print("CPU_SKIN_DEFORMATION ",item," bone=",skeleton.get_bone_name(bone)," mixed_vertices=",selected.blends," metrics=",change)
  rig.queue_free();await process_frame;await process_frame
 check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"animal skeletons/skins/players free without orphan nodes")
 print("BLOOM ANIMAL RUNTIME SKIN: %d checks, %d failures; %d models; native_bake=%s; scope=%s"%[checks,failures.size(),cases.size(),native_probe,"PILOT" if not raw_model.is_empty() or not only_species.is_empty() or only_team>=0 else "FULL CAST"])
 quit(0 if failures.is_empty() else 1)
