extends SceneTree
const Character=preload("res://modules/monkey_vine/art/character/monkey.tscn")
var checks=0
var failures=[]
var skins=0
var triangles=0
var inverted=0
func check(ok,label):
 checks+=1
 if not ok and not label in failures: failures.append(label);print("FAIL ",label)
func walk(n:Node):
 if n is MeshInstance3D and n.mesh:
  if n.skin:
   skins+=1
   check(n.skin.get_bind_count()>0,"skin has bone binds")
   for surface in range(n.mesh.get_surface_count()):
    var a=n.mesh.surface_get_arrays(surface)
    check(a[Mesh.ARRAY_BONES].size()>0 and a[Mesh.ARRAY_WEIGHTS].size()>0,"skinned surface weights")
  for surface in range(n.mesh.get_surface_count()):
   var a=n.mesh.surface_get_arrays(surface)
   var vertices=a[Mesh.ARRAY_VERTEX]
   var normals=a[Mesh.ARRAY_NORMAL]
   var indices=a[Mesh.ARRAY_INDEX]
   if indices.is_empty(): continue
   for j in range(0,indices.size(),3):
    var i0=indices[j];var i1=indices[j+1];var i2=indices[j+2]
    var cross=(vertices[i1]-vertices[i0]).cross(vertices[i2]-vertices[i0])
    if cross.length()<.0000001:continue
    var avg=normals[i0]+normals[i1]+normals[i2]
    triangles+=1
    if cross.dot(avg)>0:
     inverted+=1
     print("WINDING_DETAIL ",n.name," surface=",surface," tri=",j/3," area=",cross.length()," cosine=",cross.normalized().dot(avg.normalized()))
 for c in n.get_children():walk(c)
func _initialize():call_deferred("run")
func run():
 var c=Character.instantiate();root.add_child(c)
 await process_frame
 walk(c)
 check(skins>0,"real Skin exists")
 check(inverted==0,"all triangle winding clockwise against normals")
 var sk:Skeleton3D=c.skeleton
 check(sk!=null and sk.get_bone_count()>=10,"articulated skeleton")
 var ap:AnimationPlayer=c.player
 for clip in ["idle","run","grab","swing","air","land","fall"]:
  check(not c._key(clip).is_empty(),"animation exists "+clip)
 c.set_pose({"vine_id":"test","player_pos":Vector2(2,3),"grip_pos":Vector2(2,3.45),"facing":1})
 var changed=false
 var previous=[]
 for i in range(sk.get_bone_count()): previous.append(sk.get_bone_pose(i))
 for frame in range(30):
  ap.advance(1.0/30)
  sk.force_update_all_bone_transforms()
  check(c.get_grip_error()<.001,"hand anchor contact while swing")
  for i in range(sk.get_bone_count()):
   if not sk.get_bone_pose(i).is_equal_approx(previous[i]):changed=true
 check(changed,"swing changes bone transforms")
 c.set_pose({"vine_id":"test","facing":-1})
 ap.advance(.2);sk.force_update_all_bone_transforms()
 check(c.get_grip_error()<.001,"mirrored hand grip")
 root.remove_child(c)
 ap.advance(.1)
 c.queue_free()
 await process_frame
 print(JSON.stringify({"suite":"independent_rig","checks":checks,"skins":skins,"triangles":triangles,"inverted":inverted,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
