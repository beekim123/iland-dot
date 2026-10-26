"""Chibi Island — sculpted wildlife v3.
Repro: blender -b -t 8 --python art/v3/build_animals.py
No external assets, textures, addons or old-model dependencies.
"""
import bpy, math, os, json, bmesh, sys
from mathutils import Vector
from math import sin,cos,pi,sqrt
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for d in list(bpy.data.materials):bpy.data.materials.remove(d)
M={}
def mat(name,col,rough=.48):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough;p.inputs['Specular IOR Level'].default_value=.28;M[name]=m;return m
for n,c in {'seafoam':(.18,.53,.35),'mint':(.38,.68,.40),'mint_lid':(.36,.65,.40),'shell':(.018,.22,.17),'shell_seam':(.16,.43,.31),'shell_rim':(.66,.79,.39),'ivory':(.94,.89,.71),'pearl':(.91,.95,.91),'ink':(.012,.041,.055),'iris':(.055,.17,.19),'white':(1,.98,.88),'coral':(.90,.13,.045),'coral_light':(1,.27,.09),'coral_belly':(1,.52,.28),'claw_tip':(1,.68,.39),'blush':(.94,.38,.25),'wing':(.28,.47,.51),'wing_light':(.33,.53,.57),'wing_dark':(.16,.32,.37),'gold':(1,.53,.055),'gold_light':(1,.70,.16),'mouth':(.35,.16,.10)}.items():mat(n,c)
roots={};P=None

def empty(n,loc=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o

def root(n):
 global P
 P=empty(n);roots[n]=P;return P

def mesh(n,vs,fs,ma,parent=None,sub=2,face_mats=None):
 me=bpy.data.meshes.new(n+'Mesh');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.parent=parent or P
 for m in ma if isinstance(ma,list) else [ma]:me.materials.append(M[m])
 for i,p in enumerate(me.polygons):p.use_smooth=True;p.material_index=face_mats[i] if face_mats else 0
 if sub:mod=o.modifiers.new('Sculpted continuous surface','SUBSURF');mod.levels=sub;mod.render_levels=sub
 return o

def loft(n,rings,ma,parent=None,N=24,sub=2,face_mats=None):
 # Each ring: y, radius_x, center_z, radius_z. Hand-shaped profiles, not primitives.
 vs=[];fs=[]
 for y,rx,cz,rz in rings:
  for j in range(N):
   t=j*2*pi/N;vs.append((rx*cos(t),y,cz+rz*sin(t)))
 for i in range(len(rings)-1):
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
 fs += [tuple(reversed(range(N))),tuple((len(rings)-1)*N+j for j in range(N))]
 return mesh(n,vs,fs,ma,parent,sub,face_mats)

def sweep(n,stations,ma,parent=None,N=12,sub=2,axis_hint=(0,0,1)):
 # Organic tube: path xyz, transverse width and thickness; supports tapered bent limbs.
 vs=[];fs=[]
 for i,(pt,w,h) in enumerate(stations):
  p=Vector(pt);prev=Vector(stations[max(0,i-1)][0]);nxt=Vector(stations[min(len(stations)-1,i+1)][0]);t=(nxt-prev).normalized();a=Vector(axis_hint);u=t.cross(a).normalized()
  if u.length<.1:u=t.cross(Vector((0,1,0))).normalized()
  v=u.cross(t).normalized()
  for j in range(N):ang=2*pi*j/N;vs.append(tuple(p+u*w*cos(ang)+v*h*sin(ang)))
 for i in range(len(stations)-1):
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
 fs.extend([tuple(reversed(range(N))),tuple((len(stations)-1)*N+j for j in range(N))]);return mesh(n,vs,fs,ma,parent,sub)

def line(n,pts,ma,r=.008,parent=None):
 cu=bpy.data.curves.new(n+'Curve','CURVE');cu.dimensions='3D';cu.resolution_u=20;cu.bevel_depth=r;cu.bevel_resolution=3;s=cu.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for b,co in zip(s.bezier_points,pts):b.co=co;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(n,cu);bpy.context.collection.objects.link(o);o.data.materials.append(M[ma]);o.parent=parent or P;return o

def oval(n,loc,sc,ma,parent=None,normal=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,0,0));o=bpy.context.object;o.name=n;o.parent=parent or P;o.location=loc;o.scale=sc
 if normal:o.rotation_euler=Vector(normal).to_track_quat('Y','Z').to_euler()
 o.data.materials.append(M[ma]);
 for p in o.data.polygons:p.use_smooth=True
 return o

def eye(n,center,normal,r,parent=None,lid='mint_lid'):
 p=Vector(center);no=Vector(normal).normalized();side=no.cross(Vector((0,0,1))).normalized();up=side.cross(no).normalized()
 oval(n+'_Socket',p-no*.006,(r*1.10,r*.40,r*1.16),lid,parent,normal=no)
 oval(n+'_Eye',p+no*.010,(r*.82,r*.42,r*.93),'ink',parent,normal=no)
 oval(n+'_Iris',p+no*(r*.39),(r*.50,r*.13,r*.60),'iris',parent,normal=no)
 oval(n+'_Pupil',p+no*(r*.49),(r*.32,r*.09,r*.46),'ink',parent,normal=no)
 oval(n+'_Catchlight',p+no*(r*.59)-side*(r*.23)+up*(r*.30),(r*.19,r*.065,r*.21),'white',parent,normal=no)
 # Soft upper eyelid embedded into head, not a floating eyebrow.
 pts=[tuple(p+side*(r*1.03*cos(a))+up*(r*1.10*sin(a))+no*.012) for a in [0,.4,.8,1.2,1.6,2.0,2.4,2.8,pi]]
 line(n+'_UpperLid',pts,lid,r*.11,parent)

def blade(n,outline,depth,ma,parent=None,axis='Z',sub=2):
 # Rounded, closed organic silhouette with concentric support rings. outline 2D.
 cx=sum(p[0] for p in outline)/len(outline);cy=sum(p[1] for p in outline)/len(outline);vs=[];N=len(outline)
 for scale,z in [(.04,-depth*.7),(.78,-depth*.65),(1,0),(.78,depth*.65),(.04,depth*.7)]:
  for x,y in outline:
   a=cx+(x-cx)*scale;b=cy+(y-cy)*scale
   vs.append((a,b,z) if axis=='Z' else (z,a,b))
 fs=[]
 for j in range(4):
  for k in range(N):fs.append((j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k))
 fs.extend([tuple(reversed(range(N))),tuple(4*N+k for k in range(N))]);return mesh(n,vs,fs,ma,parent,sub)

# New original Q dolphin: short melon, compact fusiform body, horizontal flukes.
mat('dolphin',(.22,.59,.70));mat('belly',(.77,.92,.88));mat('fin',(.15,.43,.55));mat('smile',(.045,.16,.22))
root('DolphinRoot')
body=loft('DolphinBody',[(-1.12,.018,-.08,.025),(-1.09,.12,-.075,.085),(-.95,.16,-.06,.105),(-.83,.19,-.025,.13),(-.76,.27,.055,.27),(-.62,.36,.055,.36),(-.38,.38,.035,.38),(-.08,.35,0,.34),(.20,.27,-.01,.27),(.43,.19,-.025,.19),(.64,.12,-.04,.13),(.82,.075,-.04,.09),(1.02,.06,-.04,.055),(1.10,.025,-.04,.035)],['dolphin','belly'],N=32)
for p in body.data.polygons:
 if p.center.z<-.1:p.material_index=1
# lower quarter ring assignment gives clean continuous countershaded underside
for p in body.data.polygons:
 if p.index<13*32 and 18<=p.index%32<=29:p.material_index=1
for s in [-1,1]:
 f=blade('Flipper_'+str(s),[(s*.21,-.45),(s*.42,-.38),(s*.64,-.12),(s*.70,.10),(s*.63,.16),(s*.48,.08),(s*.26,-.13)],.075,'fin')
 for v in f.data.vertices:v.co.z-=.16
 f=blade('Fluke_'+str(s),[(s*.035,.87),(s*.26,.91),(s*.49,1.08),(s*.55,1.21),(s*.44,1.19),(s*.18,1.09),(s*.025,1.16)],.055,'dolphin')
 for v in f.data.vertices:v.co.z-=.04
fin=blade('Dorsal',[(-.10,.24),(.04,.45),(.23,.69),(.29,.71),(.27,.52),(.29,.36),(.42,.18)],.08,'fin',axis='X')
for s in [-1,1]:
 eye('DolphinEye_'+str(s),(s*.292,-.70,.14),(s*.88,-.42,.12),.085,lid='dolphin')
 line('Smile_'+str(s),[(s*.085,-1.09,-.075),(s*.16,-.91,-.09),(s*.23,-.77,-.09),(s*.265,-.71,-.05)],'smile',.008)
 oval('Cheek_'+str(s),(s*.283,-.69,.005),(.014,.059,.026),'blush')
oval('Blowhole',(0,-.48,.398),(.055,.027,.009),'fin')
# Freeze evaluated geometry, all vertices use world-rest coordinates.
from mathutils import Matrix
objects=[];dg=bpy.context.evaluated_depsgraph_get()
for o in list(bpy.context.scene.objects):
 if o.type not in {'MESH','CURVE'}:continue
 me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg);me.transform(o.matrix_world)
 n=bpy.data.objects.new(o.name+'_Skin',me);bpy.context.collection.objects.link(n);objects.append(n);bpy.data.objects.remove(o,do_unlink=True)
for o in list(bpy.context.scene.objects):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
arm=bpy.data.armatures.new('DolphinSkeleton');rig=bpy.data.objects.new('Dolphin_Rig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,pa=None):
 b=arm.edit_bones.new(n);b.head=h;b.tail=t
 if pa:b.parent=arm.edit_bones[pa]
bone('root',(0,0,-.4),(0,0,-.2))
chain=[('head',-.85,-.5),('spine_1',-.5,-.1),('spine_2',-.1,.3),('tail_1',.3,.65),('tail_2',.65,.94),('flukes',.94,1.16)]
pa='root'
for n,a,b in chain:bone(n,(0,a,0),(0,b,0),pa);pa=n
for s in [-1,1]:bone('flipper_'+str(s),(s*.24,-.35,-.16),(s*.66,.08,-.16),'spine_1')
bone('dorsal',(0,.1,.25),(0,.26,.65),'spine_2')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
centers=[-.65,-.30,.12,.46,.78,1.03]
def weights(y):
 if y<centers[0]:return {'head':1.}
 if y>=centers[-1]:return {'flukes':1.}
 for i in range(5):
  if centers[i]<=y<=centers[i+1]:
   t=(y-centers[i])/(centers[i+1]-centers[i]);t=t*t*(3-2*t);return {chain[i][0]:1-t,chain[i+1][0]:t}
qa={'unweighted':0,'max_weight_sum_error':0,'source':'Original dolphin v5, researched Q stylization','bones':len(arm.bones)}
for o in objects:
 for b in arm.bones:o.vertex_groups.new(name=b.name)
 for v in o.data.vertices:
  w=weights(v.co.y)
  if any(k in o.name for k in ['Eye','Smile','Cheek','Blowhole']):w={'head':1.}
  if 'Flipper' in o.name:
   t=max(0,min(1,(abs(v.co.x)-.24)/.20));w={k:x*(1-t) for k,x in w.items()};w['flipper_'+str(-1 if v.co.x<0 else 1)]=t
  if 'Dorsal' in o.name:w={'spine_2':1.}
  for k,x in w.items():
   if x>1e-8:o.vertex_groups[k].add([v.index],x,'REPLACE')
  total=sum(g.weight for g in v.groups);qa['unweighted']+=int(total<.99);qa['max_weight_sum_error']=max(qa['max_weight_sum_error'],abs(1-total))
 mo=o.modifiers.new('TrueArmatureSkin','ARMATURE');mo.object=rig;mo.use_deform_preserve_volume=True;o.parent=rig
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=97;sc.render.fps=24
for p in rig.pose.bones:p.rotation_mode='XYZ'
for frame in range(1,98):
 t=(frame-1)/24;ph=2*pi*t
 for j,(n,a,b) in enumerate(chain):
  p=rig.pose.bones[n];p.rotation_euler=([.018,.035,.065,.15,.23,.13][j]*sin(ph-j*.52),0,0);p.keyframe_insert('rotation_euler',frame=frame,group=n)
 for s in [-1,1]:
  p=rig.pose.bones['flipper_'+str(s)];p.rotation_euler=(.045*sin(ph+.4),.04*sin(ph*.5),s*.025*sin(ph));p.keyframe_insert('rotation_euler',frame=frame,group=p.name)
a=rig.animation_data.action;a.name='Swim';a.use_fake_user=True
for fc in a.fcurves:
 for k in fc.keyframe_points:k.interpolation='LINEAR'
sc.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=OUT+'/dolphin_rigged.glb',use_selection=True,export_format='GLB',export_animations=True,export_skins=True,export_yup=True,export_frame_range=True,export_force_sampling=True,export_animation_mode='ACTIONS',export_apply=False)
pts=[v.co for o in objects for v in o.data.vertices];qa['rest_bounds']={'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)]};qa['duration']=4.;qa['clip']='Swim';qa['forward']='-Y Blender / +Z glTF';qa['meshes']=len(objects)
json.dump(qa,open(OUT+'/rig_qa.json','w'),indent=2)
world=bpy.data.worlds.new('Studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.40,.62,.64,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;sc.world=world
mat('floor',(.11,.30,.34));bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.62));bpy.context.object.data.materials.append(M['floor'])
for loc,power,size in [((2,-3,4),350,4),((-3,-1,2),200,3),((0,3,3),250,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-3.7,2.1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.04))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.05;sc.camera=cam
sc.render.resolution_x=480;sc.render.resolution_y=360;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.engine='CYCLES';sc.cycles.samples=4;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
sc.frame_end=96;sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=OUT+'/dolphin_rigged.blend');sc.render.filepath=OUT+'/dolphin_pose.png';bpy.ops.render.render(write_still=True)
if '--render' in sys.argv:
 os.makedirs(OUT+'/frames',exist_ok=True)
 for i in range(48):sc.frame_set(1+i*2);sc.render.filepath=OUT+'/frames/%03d.png'%i;bpy.ops.render.render(write_still=True)
