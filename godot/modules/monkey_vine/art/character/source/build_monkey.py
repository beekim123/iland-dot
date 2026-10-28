import bpy, math, json, os
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(ROOT+'/previews',exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
P=lambda p:Vector((p[0],-p[2],p[1]))
M={}
for n,h in {'fur':'a15e39','light':'f3bd7d','muzzle':'ffe0a0','dark':'38251e','white':'fff9e9','cheek':'ed8c69','leaf':'57a976'}.items():
 m=bpy.data.materials.new(n);m.diffuse_color=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1,);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.72;M[n]=m
objects=[]
def finish(o,name,mat,bone):
 o.name=name;o.data.materials.append(M[mat]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 if bone:o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE')
 objects.append(o);return o
def ell(n,p,s,m,b,seg=16,rings=10):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=P(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);return finish(o,n,m,b)
bones={'root':((0,0,0),(0,.12,0),None),'body':((0,-.17,0),(0,.13,0),'root'),'head':((0,.13,0),(.02,.38,0),'body')}
for side,z in [('Near',.16),('Far',-.16)]:
 bones['upper'+side]=((-.035,.08,z),(-.25,.28,z),'body')
 bones['fore'+side]=((-.25,.28,z),(0,.45,z*.28),'upper'+side)
 bones['hand'+side]=((0,.45,z*.28),(.035,.48,z*.28),'fore'+side)
 bones['thigh'+side]=((0,-.17,z*.75),(.07,-.24,z*.75),'body')
 bones['shin'+side]=((.07,-.24,z*.75),(.03,-.30,z*.75),'thigh'+side)
 bones['foot'+side]=((.03,-.30,z*.75),(.15,-.30,z*.75),'shin'+side)
tail=[(-.13,-.12,0),(-.36,-.17,0),(-.55,-.08,0),(-.66,.09,0),(-.63,.28,0),(-.48,.37,0),(-.37,.29,0),(-.43,.21,0)]
for i in range(7):bones['tail'+str(i)]=(tail[i],tail[i+1],'body' if i==0 else 'tail'+str(i-1))
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='MonkeyRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(a,b,parent) in bones.items():
 e=rig.data.edit_bones.new(n);e.head=P(a);e.tail=P(b)
 if parent:e.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
ell('PearBody',(-.015,-.025,0),(.205,.255,.19),'fur','body')
ell('WarmBelly',(.14,-.035,.045),(.075,.18,.145),'light','body')
ell('BigHead',(.015,.285,0),(.265,.27,.235),'fur','head',24,16)
# Heart-like cheek mask, projecting muzzle and readable near/front eyes.
for z in [-.145,.145]:
 ell('FaceMask',(.17,.31,z),(.15,.18,.11),'light','head')
 ell('Ear',(-.16,.32,z*1.65),(.13,.14,.075),'fur','head')
 ell('EarInner',(-.15,.32,z*1.92),(.087,.093,.024),'cheek','head')
 ell('EyeWhite',(.20,.345,z*1.60),(.075,.095,.048),'white','head')
 ell('EyePupil',(.225,.347,z*1.86),(.044,.063,.024),'dark','head')
 ell('EyeGlint',(.232,.37,z*2.01),(.015,.021,.012),'white','head',12,8)
 ell('Cheek',(.22,.24,z*1.33),(.046,.026,.026),'cheek','head')
ell('Muzzle',(.245,.205,0),(.12,.08,.145),'muzzle','head')
ell('Nose',(.34,.245,0),(.035,.025,.047),'dark','head')
# three tuft lobes, not a bald human silhouette
for i in range(3):ell('Tuft',(-.08+i*.065,.54+i*.008,0),(.06,.085,.075),'fur','head')
# Tubes with continuous rings and smoothly blended bone weights.
def tube(name,points,radii,chain,mat):
 verts=[];faces=[];weights=[]
 for j in range((len(points)-1)*5+1):
  t=j/5;idx=min(int(t),len(points)-2);f=t-idx;a=P(points[idx]);b=P(points[idx+1]);c=a.lerp(b,f);axis=(b-a).normalized();
  if True:
   p0=P(points[max(0,idx-1)]);p3=P(points[min(len(points)-1,idx+2)]);c=.5*((2*a)+(-p0+b)*f+(2*p0-5*a+4*b-p3)*f*f+(-p0+3*a-3*b+p3)*f*f*f);axis=(.5*((-p0+b)+2*(2*p0-5*a+4*b-p3)*f+3*(-p0+3*a-3*b+p3)*f*f)).normalized()
  u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized();r=radii[idx]*(1-f)+radii[idx+1]*f
  for k in range(10):verts.append(c+r*(u*math.cos(k*math.tau/10)+v*math.sin(k*math.tau/10)));weights.append((idx,f))
 for j in range(len(verts)//10-1):
  for k in range(10):a=j*10+k;b=j*10+(k+1)%10;faces.append((a,b,b+10,a+10))
 faces.extend([tuple(reversed(range(10))),tuple(range(len(verts)-10,len(verts)))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(M[mat]);objects.append(o)
 for n in chain:o.vertex_groups.new(name=n)
 for i,(idx,f) in enumerate(weights):
  # blend across each joint, with distal half retaining following bone influence
  if idx+1<len(chain) and f>.55:
   w=(f-.55)/.9;o.vertex_groups[chain[idx]].add([i],1-w,'REPLACE');o.vertex_groups[chain[idx+1]].add([i],w,'REPLACE')
  elif idx>0 and f<.45:
   w=(.45-f)/.9;o.vertex_groups[chain[idx]].add([i],1-w,'REPLACE');o.vertex_groups[chain[idx-1]].add([i],w,'REPLACE')
  else:o.vertex_groups[chain[min(idx,len(chain)-1)]].add([i],1,'REPLACE')
 for p in mesh.polygons:p.use_smooth=p.index < len(mesh.polygons)-2
for side,z in [('Near',.16),('Far',-.16)]:
 tube('FlexibleArm'+side,[bones['upper'+side][0],bones['fore'+side][0],bones['hand'+side][0]],[.065,.055,.04],['upper'+side,'fore'+side],'fur')
 ell('Palm'+side,(0,.45,z*.28),(.065,.055,.052),'light','hand'+side)
 for j in range(3):ell('CurledFinger'+side,(.025+j*.018,.475,z*.21),(.018,.037,.025),'light','hand'+side,12,8)
 tube('FlexibleLeg'+side,[bones['thigh'+side][0],bones['shin'+side][0],bones['foot'+side][0]],[.065,.04,.035],['thigh'+side,'shin'+side],'fur')
 ell('Foot'+side,(.09,-.301,z*.75),(.11,.019,.07),'light','foot'+side)
tube('LongCurledTail',tail,[.055,.052,.047,.042,.037,.032,.027,.018],['tail'+str(i) for i in range(7)],'fur')
# Put the face ahead and below the grip, so grasping palms remain visibly outside the head.
for o in objects:
 if o.vertex_groups.get('head'):o.location += P((.165,-.105,0))
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='MonkeySkin';tri=mesh.modifiers.new('ExplicitTopology','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name);mesh.data.update()
# Locally flat-shade tight inside bends: averaged normals can point through an acute triangle.
for face in mesh.data.polygons:
 a,b,c=[mesh.data.vertices[i] for i in face.vertices];n=a.normal+b.normal+c.normal
 if (b.co-a.co).cross(c.co-a.co).dot(n)<0:face.use_smooth=False
mesh.parent=rig;mod=mesh.modifiers.new('WeightedDeform','ARMATURE');mod.object=rig
# Bake bone animation, arms world-solved to fixed physical grip in grab/swing.
rig.animation_data_create()
def orient(n,a,b):
 rest=rig.data.bones[n];q=(rest.tail_local-rest.head_local).rotation_difference(b-a);rig.pose.bones[n].matrix=Matrix.Translation(a)@(q@rest.matrix_local.to_quaternion()).to_matrix().to_4x4();bpy.context.view_layer.update()
def arm(side,target):
 n='upper'+side;rest=rig.data.bones[n];body=rig.pose.bones['body'];shoulder=body.matrix@body.bone.matrix_local.inverted()@rest.head_local
 l1=rest.length;l2=rig.data.bones['fore'+side].length;axis=target-shoulder;d=min(axis.length,l1+l2-.0001);axis.normalize();along=(l1*l1-l2*l2+d*d)/(2*d);out=P((-1,0,0));out=(out-axis*out.dot(axis)).normalized();elbow=shoulder+axis*along+out*math.sqrt(max(0,l1*l1-along*along));orient(n,shoulder,elbow);orient('fore'+side,elbow,target);orient('hand'+side,target,target+P((.035,.03,0)))
clips={'idle':60,'run':24,'grab':12,'swing':48,'air':36,'land':18,'fall':36}
for clip,duration in clips.items():
 act=bpy.data.actions.new(clip);rig.animation_data.action=act
 for frame in range(duration+1):
  t=frame/duration;phase=t*math.tau
  for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0);pb.scale=(1,1,1)
  def rot(n,axis,ang):rig.pose.bones[n].rotation_quaternion=__import__('mathutils').Quaternion(axis,ang)
  rot('body',(0,0,1),.035*math.sin(phase));rot('head',(0,0,1),-.025*math.sin(phase))
  for i in range(7):rot('tail'+str(i),(0,0,1),.07*math.sin(phase-i*.45))
  for side,off in [('Near',0),('Far',math.pi)]:
   if clip=='run':
    rot('thigh'+side,(0,0,1),.55*math.sin(phase+off));rot('shin'+side,(0,0,1),-.35*max(0,math.sin(phase+off)))
   if clip in ['air','fall','swing','grab']:
    rot('thigh'+side,(0,0,1),-.55+(.14*math.sin(phase+off)));rot('shin'+side,(0,0,1),.8)
  if clip=='land':rig.pose.bones['body'].scale=(1+.09*math.sin(math.pi*t),1-.15*math.sin(math.pi*t),1+.09*math.sin(math.pi*t))
  bpy.context.view_layer.update()
  for side,z in [('Near',.16),('Far',-.16)]:
   if clip in ['grab','swing']:target=P((0,.45,z*.28))
   elif clip=='run':target=P((.03+.13*math.sin(phase+(0 if side=='Near' else math.pi)),-.14,z))
   elif clip in ['air','fall']:target=P((-.16,.19+.04*math.sin(phase),z))
   else:target=P((.06,-.15,z))
   arm(side,target)
  for pb in rig.pose.bones:
   for path in ['rotation_quaternion','location','scale']:pb.keyframe_insert(path,frame=frame,group=pb.name)
 for fc in act.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
 track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,0,act)
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for pb in rig.pose.bones:pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0);pb.scale=(1,1,1)
bpy.context.scene.render.fps=30
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/source/monkey.blend')
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=ROOT+'/models/monkey.glb',use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True)
stats={'vertices':len(mesh.data.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'bones':len(bones),'blended_vertices':sum(len(v.groups)>1 for v in mesh.data.vertices),'clips':list(clips),'grip_local':[0,.45,0]};open(ROOT+'/source/stats.json','w').write(json.dumps(stats,indent=2));print(stats)
# Model-only review render; not a gameplay screenshot.
for tr in rig.animation_data.nla_tracks:tr.mute=True
rig.animation_data.action=bpy.data.actions['idle'];bpy.context.scene.frame_set(8)
bpy.ops.object.camera_add(location=P((2.0,.9,3.8)));cam=bpy.context.object;cam.rotation_euler=(P((-.1,.03,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.65;bpy.context.scene.camera=cam
for pos,power,size in [((2,3,4),200,4),((-2,1,2),100,3)]:
 bpy.ops.object.light_add(type='AREA',location=P(pos));l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
sc=bpy.context.scene;sc.world.color=(.08,.1,.09);sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=False;sc.render.resolution_x=900;sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.filepath=ROOT+'/previews/monkey_idle.png';bpy.ops.render.render(write_still=True)
