"""True armature / skin / swim action for accepted turtle v3. Blender 4.3.2.
blender -b -t 2 --python art/rigged/turtle/rig_turtle.py [--render]
"""
import bpy, math, os, json, sys, struct
from mathutils import Vector, Matrix
from math import sin, cos, pi
OUT=os.path.dirname(os.path.abspath(__file__)); SOURCE=os.path.abspath(os.path.join(OUT,'../../v3/animals.blend'))
bpy.ops.wm.open_mainfile(filepath=SOURCE)
root=bpy.data.objects['TurtleRoot'];root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
bpy.context.view_layer.update()
keep={root,*root.children_recursive}
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
pivots={o.name:o.matrix_world.translation.copy() for o in keep if o.type=='EMPTY'}
mesh_info=[]
# Freeze evaluated accepted geometry at its rest pose; only rig changes motion.
for o in list(keep):
 if o.type!='MESH':continue
 family=o.parent.name if o.parent else ''
 ev=o.evaluated_get(deps);me=bpy.data.meshes.new_from_object(ev,depsgraph=deps)
 me.transform(o.matrix_world)
 o.modifiers.clear();o.data=me;o.parent=None;o.matrix_world=Matrix.Identity(4)
 mesh_info.append((o,family))
for o in list(keep):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
# Ground adjustment already baked by source; use actual pivot heights.
headpivot=pivots['HeadPivot'];bodyz=headpivot.z-.01
armdata=bpy.data.armatures.new('Turtle_Swim_Skeleton');arm=bpy.data.objects.new('TurtleRig',armdata);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
 e=armdata.edit_bones.new(name);e.head=a;e.tail=b
 if parent:e.parent=armdata.edit_bones[parent]
 return e
bone('root',(0,0,0),(0,0,.18))
bone('body',(0,.30,bodyz),(0,-.38,bodyz),'root')
bone('neck',(0,-.38,bodyz),(0,-.72,headpivot.z+.08),'body')
bone('head',(0,-.72,headpivot.z+.08),(0,-1.08,headpivot.z+.08),'neck')
chains={}
for side,s in [('L',-1),('R',1)]:
 for front in [True,False]:
  key=('Front' if front else 'Rear')+'FlipperPivot'+side;p=pivots[key]
  if front:offsets=[(0,0,0),(s*.22,-.13,-.075),(s*.43,-.29,-.15),(s*.55,-.43,-.16)]
  else:offsets=[(0,0,0),(s*.17,.11,-.08),(s*.30,.32,-.17)]
  pts=[p+Vector(v) for v in offsets];names=[]
  for i in range(len(pts)-1):
   n=('fore' if front else 'hind')+'_'+side+'_'+str(i+1)
   bone(n,pts[i],pts[i+1],names[-1] if names else 'body');names.append(n)
  chains[key]=(pts,names)
p=pivots['TurtleTailPivot'];bone('tail',p,p+Vector((0,.23,-.035)),'body')
bpy.ops.object.mode_set(mode='OBJECT')
# Piecewise projection drives continuous normalized shoulder / elbow / tip weights.
def chain_weights(v,pts,names):
 best=(1e9,0,0.0)
 for i in range(len(pts)-1):
  d=pts[i+1]-pts[i];u=max(0,min(1,(v-pts[i]).dot(d)/d.length_squared));dist=(v-(pts[i]+u*d)).length
  if dist<best[0]:best=(dist,i,u)
 _,i,u=best
 # Transition near each joint, rigid center of segment; all weights sum exactly 1.
 if i==0 and u<.23:return {'body':(.23-u)/.23,names[0]:u/.23}
 if u>.62 and i<len(names)-1:
  q=(u-.62)/.38;return {names[i]:1-q*.5,names[i+1]:q*.5}
 if u<.38 and i>0:
  q=u/.38;return {names[i-1]:(1-q)*.5,names[i]:.5+q*.5}
 return {names[i]:1.0}
weights_audit=[]
for o,family in mesh_info:
 groups={n:o.vertex_groups.new(name=n) for n in armdata.bones.keys()}
 for v in o.data.vertices:
  if family in chains:w=chain_weights(v.co,*chains[family])
  elif family=='HeadPivot':
   # Rigid eyes/lids/nose; smoothly weighted continuous neck/body mesh.
   if o.name=='Turtle_HeadNeck':
    y=v.co.y
    if y>-.49:
     a=max(0,min(1,(-y-.33)/.16));w={'body':1-a,'neck':a}
    else:
     a=max(0,min(1,(-y-.59)/.21));w={'neck':1-a,'head':a}
   else:w={'head':1.0}
  elif family=='TurtleTailPivot':w={'tail':1.0}
  else:w={'body':1.0}
  w={n:x for n,x in w.items() if x>1e-7};total=sum(w.values())
  for n,x in w.items():groups[n].add([v.index],x/total,'REPLACE')
 o.parent=arm;mod=o.modifiers.new('True skeletal skin deformation','ARMATURE');mod.object=arm;mod.use_deform_preserve_volume=True
 sums=[sum(g.weight for g in v.groups) for v in o.data.vertices]
 weights_audit.append({'mesh':o.name,'vertices':len(sums),'unweighted':sum(x<.999 for x in sums),'max_weight_sum_error':max(abs(x-1) for x in sums)})
# 4 seconds, cyclic endpoint at 97 (frames 1..96 shown, 24fps).
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=96;sc.render.fps=24
for pb in arm.pose.bones:pb.rotation_mode='XYZ'
for frame in range(1,98):
 t=(frame-1)/24;phase=2*pi*t/2
 rootpb=arm.pose.bones['root'];rootpb.location=(0,0,.38+.025*sin(phase));rootpb.rotation_euler=(.025*sin(phase+.5),.018*sin(phase),.025*sin(phase*.5))
 rootpb.keyframe_insert('location',frame=frame);rootpb.keyframe_insert('rotation_euler',frame=frame)
 arm.pose.bones['body'].rotation_euler=(.025*sin(phase-.3),.01*sin(phase*.5),0)
 arm.pose.bones['neck'].rotation_euler=(.025*sin(phase+.6),.012*sin(phase*.5),.03*sin(phase*.5))
 arm.pose.bones['head'].rotation_euler=(.035*sin(phase+.4),0,.035*sin(phase*.5))
 arm.pose.bones['tail'].rotation_euler=(0,0,.12*sin(phase+.6))
 for side,s in [('L',-1),('R',1)]:
  q=phase+.12*s
  # Foreflippers sweep down with delayed flexible tips; hind pair countersteers.
  for i in range(1,4):
   pb=arm.pose.bones['fore_'+side+'_'+str(i)]
   pb.rotation_euler=(s*(.18+(.30 if i==1 else .16)*sin(q-(i-1)*.42)),.10*sin(q+.5),s*.12*cos(q-.3))
  for i in range(1,3):
   pb=arm.pose.bones['hind_'+side+'_'+str(i)]
   pb.rotation_euler=(s*.12*sin(q+1.3-i*.25),0,s*.08*cos(q+1.0))
 for pb in arm.pose.bones:
  if pb.name!='root':pb.keyframe_insert('rotation_euler',frame=frame)
act=arm.animation_data.action;act.name='Turtle_Swim_Loop_4s'
for fc in act.fcurves:
 for k in fc.keyframe_points:k.interpolation='LINEAR'
 fc.modifiers.new('CYCLES')
# Preserve source neutral pose and store true deformation keypose tests.
sc.frame_set(1);bpy.context.view_layer.update()
posebounds=[]
for fr in [1,13,25,37,49,61,73,85,97]:
 sc.frame_set(fr);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 coords=[o.evaluated_get(dg).matrix_world@v.co for o,_ in mesh_info for v in o.evaluated_get(dg).data.vertices]
 posebounds.append({'frame':fr,'min':[min(v[k] for v in coords) for k in range(3)],'max':[max(v[k] for v in coords) for k in range(3)]})
assert all(x['unweighted']==0 and x['max_weight_sum_error']<1e-5 for x in weights_audit)
# GLB contains armature + skin only; no studio lights/camera.
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
for o,_ in mesh_info:o.select_set(True)
bpy.context.view_layer.objects.active=arm
sc.frame_end=97
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'turtle_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_skins=True,export_apply=False,export_frame_range=True,export_force_sampling=True,export_animation_mode='ACTIONS')
sc.frame_end=96
# Actual Blender-only presentation, shallow turquoise studio and restrained light.
def material(n,col,rough=1):
 m=bpy.data.materials.new(n);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough;return m
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.10));floor=bpy.context.object;floor.name='Preview_Only_SeaFloor';floor.data.materials.append(material('PreviewTurquoise',(.045,.26,.28)))
for name,loc,power,size in [('Key',(-3,-4,5),380,5),('Fill',(3,-1,3),230,4),('Rim',(0,4,4),300,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);li=bpy.context.object;li.name='Preview_'+name;li.data.energy=power;li.data.shape='DISK';li.data.size=size;li.rotation_euler=(Vector((0,0,.5))-li.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.4,-3.5,2.7));cam=bpy.context.object;cam.name='Preview_Camera';cam.rotation_euler=(Vector((0,-.12,.68))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.9;sc.camera=cam
sc.world.color=(.3,.3,.3);sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.frame_set(13);sc.render.filepath=os.path.join(OUT,'turtle_swim_pose.png');bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'turtle_rigged.blend'))
# Binary structural verification independent from Blender scene state.
b=open(os.path.join(OUT,'turtle_rigged.glb'),'rb').read();ln,typ=struct.unpack_from('<II',b,12);g=json.loads(b[20:20+ln]);a=g.get('animations',[]);skins=g.get('skins',[])
assert skins and a and any('WEIGHTS_0' in p['attributes'] and 'JOINTS_0' in p['attributes'] for m in g['meshes'] for p in m['primitives'])
qa={'bone_count':len(armdata.bones),'skinned_meshes':len(mesh_info),'weights':weights_audit,'pose_bounds':posebounds,'glb_skins':len(skins),'glb_joints':[len(s['joints']) for s in skins],'animation_names':[x.get('name') for x in a],'animation_channels':[len(x['channels']) for x in a],'source_unchanged':SOURCE,'preview':'real Blender Cycles frames','duration_seconds':4,'fps':24}
open(os.path.join(OUT,'rig_qa.json'),'w').write(json.dumps(qa,indent=2))
if '--skip-render' not in sys.argv:bpy.ops.render.render(write_still=True)
print('TURTLE_POSE_READY',sc.render.filepath,flush=True)
if '--render' in sys.argv:
 os.makedirs(os.path.join(OUT,'frames'),exist_ok=True);sc.render.filepath=os.path.join(OUT,'frames/frame_');bpy.ops.render.render(animation=True)
print('TURTLE_RIG_DONE',json.dumps({'bones':len(armdata.bones),'skin_meshes':len(mesh_info),'animations':len(a)}),flush=True)
