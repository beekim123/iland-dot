extends SceneTree
func _initialize():
 var art=load("res://modules/fruit_gummy_snake/art/underwater_art.gd").new()
 var ocean=art.ocean();root.add_child(ocean)
 var snake=art.snake();root.add_child(snake)
 var points:Array[Vector3]=[]
 for i in 120:points.append(Vector3(sin(i*.13),12+sin(i*.08),i*.55))
 art.update_snake(snake,points,Vector3.FORWARD,1.0)
 var mesh=snake.get_node("ContinuousBody").mesh
 var arrays=mesh.surface_get_arrays(0)
 var verts=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 var reversed=0
 for t in range(0,indices.size(),3):
  var a=indices[t];var b=indices[t+1];var c=indices[t+2]
  if (verts[b]-verts[a]).cross(verts[c]-verts[a]).dot(normals[a])>=0:reversed+=1
 var t0=Time.get_ticks_usec()
 for frame in 100:art.update_snake(snake,points,Vector3.FORWARD,frame/60.0)
 print("120 point CPU update mean ms=",(Time.get_ticks_usec()-t0)/100000.0)
 print("MAX_BODY vertices=",verts.size()," triangles=",indices.size()/3," non_clockwise=",reversed)
 assert(reversed==0)
 quit()
