import bpy, math, os, json
from mathutils import Vector
D=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
colors=[('Cocoa clay',(0.30,.16,.085,1)),('Oat muzzle',(.87,.66,.40,1)),('Lagoon helmet',(.045,.38,.48,1)),('Apricot pack',(.96,.48,.12,1)),('Deep ink',(.025,.042,.052,1)),('Lamp cream',(1,.87,.49,1)),('Boot slate',(.09,.16,.20,1))]
mats=[]
for n,c in colors:
 m=bpy.data.materials.new(n);m.diffuse_color=c;m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.84;mats.append(m)
verts=[]; faces=[]; mids=[]; weights=[]
def surf(name,center,scale,mat,bone='spine',seg=16,rings=10,weightfn=None,start=0,end=math.pi):
 # ring poles replaced with a small epsilon to avoid duplicate zero-area faces
 seg=max(8,int(seg*.8));rings=max(5,int(rings*.8))
 off=len(verts)
 for i in range(rings+1):
  th=start+(end-start)*i/rings; th=max(.015,min(math.pi-.015,th))
  for j in range(seg):
   ph=2*math.pi*j/seg;p=(center[0]+scale[0]*math.sin(th)*math.cos(ph),center[1]+scale[1]*math.sin(th)*math.sin(ph),center[2]+scale[2]*math.cos(th))
   verts.append(p);weights.append(weightfn(p) if weightfn else {bone:1})
 for i in range(rings):
  for j in range(seg):
   a=off+i*seg+j;b=off+i*seg+(j+1)%seg;c=b+seg;d=a+seg
   faces.append((a,d,c,b));mids.append(mat)
 # closed fans with unique center poles
 for row,reverse in [(0,True),(rings,False)]:
  ids=[off+row*seg+j for j in range(seg)];p=tuple(sum(verts[k][a] for k in ids)/seg for a in range(3));k=len(verts);verts.append(p);weights.append(weightfn(p) if weightfn else {bone:1})
  for j in range(seg):
   a=ids[j];b=ids[(j+1)%seg];faces.append((k,a,b) if reverse else (k,b,a));mids.append(mat)
def torso_w(p):
 t=max(0,min(1,(p[2]-.47)/.35));return {'root':1-t,'spine':t}
surf('body',(0,0,.56),(.235,.205,.33),0,weightfn=torso_w,seg=20,rings=12)
surf('bib',(0,.179,.62),(.157,.045,.205),1,weightfn=torso_w)
surf('head',(0,.025,1.00),(.295,.243,.247),0,'head',20,12)
for x in [-1,1]:
 surf('ear',(x*.265,.015,1.09),(.083,.065,.09),0,'head',12,8)
 surf('inner ear',(x*.274,.065,1.09),(.044,.018,.05),1,'head',10,6)
 surf('muzzle',(x*.083,.235,.94),(.103,.075,.074),1,'head',14,8)
 surf('eye',(x*.127,.235,1.057),(.043,.025,.052),4,'head',12,8)
 surf('spark',(x*.121,.257,1.075),(.012,.007,.014),5,'head',8,6)
 surf('brow',(x*.132,.22,1.122),(.055,.019,.014),0,'head',10,6)
surf('nose',(0,.3,.972),(.042,.025,.027),4,'head',12,8)
surf('mouth',(0,.274,.906),(.034,.014,.012),4,'head',10,6)
surf('helmet',(0,.005,1.108),(.286,.248,.18),2,'head',24,8,end=math.pi/2)
surf('helmet lip',(0,.005,1.115),(.303,.263,.027),2,'head',24,6)
surf('helmet badge',(0,.257,1.151),(.055,.012,.045),5,'head',12,8)
for x,side in [(-1,'L'),(1,'R')]:
 def armw(p,side=side):
  t=max(0,min(1,(.66-p[2])/.20));return {'arm.'+side:1-t,'paw.'+side:t}
 surf('arm',(x*.242,.016,.60),(.093,.099,.235),0,seg=14,rings=12,weightfn=armw)
 surf('paw',(x*.256,.057,.407),(.086,.09,.087),0,'paw.'+side,12,8)
 surf('leg',(x*.125,.005,.267),(.099,.113,.19),0,'leg.'+side,12,10)
 surf('boot',(x*.126,.063,.105),(.109,.151,.103),6,'foot.'+side,14,8)
 surf('boot cuff',(x*.126,.003,.196),(.104,.114,.031),3,'leg.'+side,12,6)
 surf('strap',(x*.16,-.03,.72),(.035,.213,.035),3,'spine',12,8)
surf('pack',(0,-.22,.66),(.174,.105,.204),3,'spine',16,10)
surf('pack panel',(0,-.316,.67),(.122,.025,.127),6,'spine',12,8)
surf('back lamp',(0,-.339,.72),(.079,.025,.083),5,'spine',12,8)
# continuous tapered tail tube, smoothly weighted along three actual joints
base=len(verts);N=15;S=12
for i in range(N+1):
 t=i/N;y=-.13-.57*t;z=.37-.23*t+.045*math.sin(math.pi*t);rad=.098*(1-t)**.7+.008
 q=min(1.999,t*2);j=int(q);f=q-j
 for k in range(S):
  a=k*2*math.pi/S;verts.append((rad*math.cos(a),y,z+rad*.65*math.sin(a)));weights.append({'tail'+str(j):1-f,'tail'+str(j+1):f})
for i in range(N):
 for k in range(S):
  a=base+i*S+k;b=base+i*S+(k+1)%S;faces.append((a,b,b+S,a+S));mids.append(0)
# Geometry normal correction is deterministic Blender mesh operation.
mesh=bpy.data.meshes.new('Otter continuous weighted clay');mesh.from_pydata(verts,[],faces);mesh.materials.clear()
for m in mats:mesh.materials.append(m)
obj=bpy.data.objects.new('OtterClay',mesh);bpy.context.collection.objects.link(obj)
for p,mi in zip(mesh.polygons,mids):p.material_index=mi;p.use_smooth=True
bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
arm=bpy.data.armatures.new('Otter skeleton');rig=bpy.data.objects.new('OtterRig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,parent=None):
 b=arm.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=arm.edit_bones[parent]
bone('root',(0,0,.30),(0,0,.52));bone('spine',(0,0,.52),(0,0,.83),'root');bone('head',(0,0,.83),(0,0,1.18),'spine')
for x,s in [(-1,'L'),(1,'R')]:
 bone('arm.'+s,(x*.21,0,.76),(x*.25,0,.52),'spine');bone('paw.'+s,(x*.25,0,.52),(x*.26,.035,.36),'arm.'+s)
 bone('leg.'+s,(x*.125,0,.39),(x*.125,0,.19),'root');bone('foot.'+s,(x*.125,0,.19),(x*.125,.12,.08),'leg.'+s)
for i in range(3):bone('tail'+str(i),(0,-.13-.19*i,.37-.077*i),(0,-.32-.19*i,.293-.077*i),'root' if i==0 else 'tail'+str(i-1))
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
for n in arm.bones:obj.vertex_groups.new(name=n.name)
for i,ws in enumerate(weights):
 for n,w in ws.items():
  if w>0:obj.vertex_groups[n].add([i],w,'REPLACE')
obj.parent=rig;obj.matrix_parent_inverse=rig.matrix_world.inverted();mod=obj.modifiers.new('Real articulated skin','ARMATURE');mod.object=rig
bpy.context.scene.render.fps=30
for name,duration in [('idle',60),('walk',24),('shelter',60),('interact',36),('hurt',24),('victory',48)]:
 rig.animation_data_create();act=bpy.data.actions.new(name);rig.animation_data.action=act
 for frame in range(1,duration+2,3):
  t=(frame-1)/duration;phase=t*2*math.pi
  for b in rig.pose.bones:b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0)
  rig.pose.bones['spine'].rotation_euler.x=.025*math.sin(phase)
  rig.pose.bones['head'].rotation_euler.y=.045*math.sin(phase)
  for i in range(3):rig.pose.bones['tail'+str(i)].rotation_euler.z=.18*math.sin(phase-i*.6)
  if name=='walk':
   for s,sg in [('L',1),('R',-1)]:
    rig.pose.bones['leg.'+s].rotation_euler.x=.48*math.sin(phase)*sg
    rig.pose.bones['foot.'+s].rotation_euler.x=-.14*math.sin(phase)*sg
    rig.pose.bones['arm.'+s].rotation_euler.x=-.42*math.sin(phase)*sg
    rig.pose.bones['paw.'+s].rotation_euler.x=.15+.12*math.cos(phase)
   rig.pose.bones['root'].location.y=.018*(1-math.cos(phase*2))
  elif name=='shelter':
   rig.pose.bones['spine'].rotation_euler.x=.27;rig.pose.bones['head'].rotation_euler.x=.12
   for s,sg in [('L',1),('R',-1)]:rig.pose.bones['arm.'+s].rotation_euler=(1.6,sg*.18,sg*.35);rig.pose.bones['paw.'+s].rotation_euler.x=.65
  elif name=='interact':
   for s,sg in [('L',1),('R',-1)]:rig.pose.bones['arm.'+s].rotation_euler.x=1.0+.16*math.sin(phase+sg);rig.pose.bones['paw.'+s].rotation_euler.x=.45
   rig.pose.bones['head'].rotation_euler.x=.12
  elif name=='hurt':rig.pose.bones['spine'].rotation_euler.y=.22*math.sin(phase);rig.pose.bones['head'].rotation_euler.x=-.18*math.sin(phase*.5)
  elif name=='victory':
   for s,sg in [('L',1),('R',-1)]:rig.pose.bones['arm.'+s].rotation_euler=(2.25,0,sg*.45);rig.pose.bones['paw.'+s].rotation_euler.x=.22*math.sin(phase*2)
   rig.pose.bones['root'].location.y=.045*(1-math.cos(phase*2))
  for b in rig.pose.bones:b.keyframe_insert('rotation_euler',frame=frame,group=b.name);b.keyframe_insert('location',frame=frame,group=b.name)
 # NLA tracks export explicit named clips
 tr=rig.animation_data.nla_tracks.new();tr.name=name;tr.strips.new(name,1,act)
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.location=(0,0,0)
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D,'otter.blend'))
# export all actions; muted NLA tracks do not affect pose
bpy.ops.export_scene.gltf(filepath=os.path.join(D,'..','otter.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True)
print('OTTER_MODEL',len(verts),sum(len(f)-2 for f in faces),'triangles',len(mats),'materials')
