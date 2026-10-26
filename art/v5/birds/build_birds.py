import bpy, bmesh, math, os, sys, json, struct
from mathutils import Vector, Matrix, Quaternion
from math import sin, cos, pi
OUT=os.path.dirname(os.path.abspath(__file__)); ROOT=os.path.abspath(os.path.join(OUT,'../../..'))
VARIANT='tern' if '--tern' in sys.argv else 'gull'
OUT=os.path.join(OUT,VARIANT);os.makedirs(OUT,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art/v3/animals.blend'))
root=bpy.data.objects['SeagullRoot']; root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
bpy.context.view_layer.update(); keep={root,*root.children_recursive}
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
# Bake only source subdivision/curves and existing transforms, preserving approved surface.
meshes=[]
for o in list(keep):
 if o.type not in {'MESH','CURVE'}:continue
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.convert(target='MESH');o=bpy.context.object
 mw=o.matrix_world.copy();o.parent=None;o.matrix_world=mw
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);meshes.append(o)
for o in list(bpy.data.objects):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
# Replace only folded wings with continuous airfoil meshes and layered feather vanes.
for o in list(meshes):
 if 'Wing' in o.name or 'PrimaryFeather' in o.name:
  meshes.remove(o);bpy.data.objects.remove(o,do_unlink=True)
def newmat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82;return m
wingmat=newmat('Cloud silver' if VARIANT=='gull' else 'Blue dove',(.67,.76,.84) if VARIANT=='gull' else (.43,.61,.72))
feathermat=newmat('Cream feathers',(.92,.94,.90));tipmat=newmat('Ink tipped primaries',(.20,.29,.37))
def vane(name,sections,mat):
 vs=[];fs=[];N=16
 for x,y,z,width,thick in sections:
  for j in range(N):
   t=2*pi*j/N;vs.append((x,y+width*cos(t),z+thick*sin(t)))
 for i in range(len(sections)-1):
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
 fs.extend([tuple(reversed(range(N))),tuple((len(sections)-1)*N+j for j in range(N))])
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 for f in me.polygons:f.use_smooth=True
 sub=o.modifiers.new('Soft sculpted edges','SUBSURF');sub.levels=1
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=sub.name);o.select_set(False);meshes.append(o);return o
for s,label in [(-1,'L'),(1,'R')]:
 vane('WingAirfoil.'+label,[(s*x,y,z,w,h) for x,y,z,w,h in [(.18,-.08,.54,.14,.06),(.35,-.03,.56,.23,.055),(.65,.035,.58,.24,.047),(.95,.0,.59,.21,.036),(1.22,.05,.59,.16,.026),(1.48,.17,.58,.10,.018),(1.7,.31,.57,.005,.006)]],wingmat)
 # Broad secondary feathers overlap into one trailing edge; long outer primaries sweep back.
 for j in range(6):
  x=.40+j*.19;y=.16+max(0,j-2)*.065;length=.26+j*.025
  vane('WingFeather.%s.%d'%(label,j),[(s*(x-.14),y,.55,.065,.018),(s*x,y+.035,.55,.12,.022),(s*(x+length*.7),y+.11,.545,.105,.018),(s*(x+length),y+.19,.54,.015,.008)],feathermat if j<4 else tipmat)
if VARIANT=='tern':
 # Head stays recognisably Q; dark rounded cap and coral beak distinguish companion.
 cap=newmat('Tern charcoal cap',(.14,.23,.29))
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(0,-.335,.825));o=bpy.context.object;o.name='Tern_HeadCap';o.scale=(.192,.158,.082);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(cap);meshes.append(o)
 for o in meshes:
  if 'Beak' in o.name and 'Smile' not in o.name:o.data.materials.clear();o.data.materials.append(newmat('Apricot beak',(.96,.36,.19)))
  if 'TailFeather' in o.name:
   for v in o.data.vertices:
    if abs(v.co.x)>.035:v.co.y+=max(0,v.co.y-.45)*.65
armdat=bpy.data.armatures.new('Seagull_Skeleton');arm=bpy.data.objects.new('Seagull_Rig',armdat);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,parent=None):
 b=armdat.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=armdat.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.2));bone('body',(0,.18,.38),(0,-.12,.44),'root');bone('neck',(0,-.12,.44),(0,-.30,.64),'body');bone('head',(0,-.30,.64),(0,-.50,.70),'neck');bone('tail',(0,.39,.42),(0,.78,.46),'body')
for s,label in [(-1,'L'),(1,'R')]:
 bone('shoulder.'+label,(s*.20,-.12,.55),(s*.72,.02,.58),'body')
 bone('elbow.'+label,(s*.72,.02,.58),(s*1.18,.04,.59),'shoulder.'+label)
 bone('wrist.'+label,(s*1.18,.04,.59),(s*1.50,.19,.58),'elbow.'+label)
 bone('feather.'+label,(s*1.50,.19,.58),(s*1.78,.34,.57),'wrist.'+label)
 bone('leg.'+label,(s*.115,-.045,.21),(s*.115,-.06,.06),'body');bone('foot.'+label,(s*.115,-.06,.06),(s*.115,-.18,.035),'leg.'+label)
bpy.ops.object.mode_set(mode='OBJECT');arm.show_in_front=True;arm.data.display_type='OCTAHEDRAL'
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def weights(o,v):
 n=o.name;p=v.co
 if 'Wing' in n:
  label='L' if '.L' in n else 'R';y=abs(p.x)
  # Smooth adjacent weights maintain the exact source surface at bind pose.
  centers=[.36,.88,1.35,1.65];bs=['shoulder.','elbow.','wrist.','feather.']
  if y<=centers[0]:return {bs[0]+label:1}
  for i in range(3):
   if y<=centers[i+1]:
    t=smooth(centers[i],centers[i+1],y);return {bs[i]+label:1-t,bs[i+1]+label:t}
  return {bs[-1]+label:1}
 if 'Leg' in n:return {'leg.'+('L' if '-1' in n else 'R'):1}
 if 'Foot' in n or 'ToeSeam' in n:return {'foot.'+('L' if p.x<0 else 'R'):1}
 if 'Tail' in n:return {'tail':1}
 if 'HeadNeckBody' in n:
  a=smooth(-.12,-.32,-p.y) if False else smooth(.12,.32,-p.y)
  b=smooth(.27,.40,-p.y)
  return {'body':1-a,'neck':a*(1-b),'head':a*b}
 if any(k in n for k in ['Eye','Beak','HeadCap']):return {'head':1}
 return {'body':1}
report={'source':'art/v3/animals.blend','bones':len(armdat.bones),'meshes':[],'normalized_weights':True}
for o in meshes:
 o.parent=arm
 for b in armdat.bones:o.vertex_groups.new(name=b.name)
 blended=0
 for v in o.data.vertices:
  w={k:a for k,a in weights(o,v).items() if a>1e-7};total=sum(w.values())
  for k,a in w.items():o.vertex_groups[k].add([v.index],a/total,'REPLACE')
  if len(w)>1:blended+=1
 mod=o.modifiers.new('True skeletal deformation','ARMATURE');mod.object=arm;mod.use_deform_preserve_volume=False
 report['meshes'].append({'name':o.name,'vertices':len(o.data.vertices),'blended_vertices':blended,'unweighted_vertices':sum(not v.groups for v in o.data.vertices)})
# Pose bones use world-aligned rotation converted to local rest axes.
def rotate(pb,axis,angle):
 R=pb.bone.matrix_local.to_3x3();D=Matrix.Rotation(angle,3,axis);pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(R.inverted()@D@R).to_quaternion()
def compose(pb,D):
 R=pb.bone.matrix_local.to_3x3();pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(R.inverted()@D@R).to_quaternion()
arm.animation_data_create()
def action(name,glide=False):
 a=bpy.data.actions.new(name);arm.animation_data.action=a
 for f in range(1,98,2):
  t=(f-1)/24;phase=t*2*pi*1.5
  for p in arm.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=(1,0,0,0);p.location=(0,0,0)
  rootp=arm.pose.bones['root'];rootp.location.z=.020*sin(phase-.5) if not glide else .025*sin(t*pi/2)
  compose(arm.pose.bones['body'],Matrix.Rotation(.07*sin(phase-.7) if not glide else .025*sin(t*pi/2),3,'X')@Matrix.Rotation(.035*sin(t*pi/2),3,'Y'))
  rotate(arm.pose.bones['neck'],'X',-.025*sin(phase-.7));rotate(arm.pose.bones['head'],'X',-.015*sin(phase-.7));rotate(arm.pose.bones['tail'],'X',.045*sin(phase-.5))
  for s,label in [(-1,'L'),(1,'R')]:
   flap=(-.52*sin(phase) if not glide else -.06+.025*sin(t*pi/2))*s
   compose(arm.pose.bones['shoulder.'+label],Matrix.Rotation(flap,3,'Y'))
   rotate(arm.pose.bones['elbow.'+label],'X',s*.0)
   # Local child rotations follow delayed stroke, producing a bend rather than rigid whole-wing spin.
   rotate(arm.pose.bones['elbow.'+label],'Z',s*(.06+.13*(1+cos(phase))*.5) if not glide else s*.035)
   rotate(arm.pose.bones['wrist.'+label],'X',(.12*cos(phase-.55) if not glide else .02*sin(t*pi/2)))
   rotate(arm.pose.bones['feather.'+label],'X',(.09*sin(phase-1.05) if not glide else .02*sin(t*pi/2)))
   rotate(arm.pose.bones['leg.'+label],'X',1.25);rotate(arm.pose.bones['foot.'+label],'X',-.55)
  for p in arm.pose.bones:
   p.keyframe_insert('rotation_quaternion',frame=f,group=p.name);p.keyframe_insert('location',frame=f,group=p.name)
 for fc in a.fcurves:
  for k in fc.keyframe_points:k.interpolation='BEZIER'
 a.use_fake_user=True;return a
fly=action('Fly',False);glide=action('Glide',True);arm.animation_data.action=fly
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=96;sc.render.fps=24
# NLA export retains both separately-named animation clips.
arm.animation_data.action=None
for i,a in enumerate([fly,glide]):
 tr=arm.animation_data.nla_tracks.new();tr.name=a.name;strip=tr.strips.new(a.name,1,a);tr.mute=True
# Export both action clips with all baked tracks, then restore Fly for previews.
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=arm
arm.animation_data.action=fly
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'bird_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_apply=False,export_force_sampling=True,export_frame_range=False)
# Remove NLA contribution during preview; action Fly directly drives all bones.
for tr in arm.animation_data.nla_tracks:tr.mute=True
arm.location.z=1.15
# Clean bright studio; rendered motion is genuine evaluated armature animation.
def material(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.9;return m
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));bpy.context.object.data.materials.append(material('Warm Ivory Studio',(.72,.80,.78)))
world=bpy.data.worlds.new('RigStudioWorld');sc.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.76,.83,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
for n,loc,power,size,col in [('Key',(-3,-4,6),450,5,(1,.9,.78)),('Fill',(4,-1,4),260,4,(.78,.9,1)),('Rim',(0,4,4),340,3,(1,.95,.85))]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.name=n;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=col;l.rotation_euler=(Vector((0,0,1.5))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.6,-5.2,3.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.60))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.5;sc.camera=cam
sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.frame_set(5);sc.render.filepath=os.path.join(OUT,'bird_pose.png')
report['variant']=VARIANT;report['forward_blender']='-Y';report['up_blender']='+Z';report['forward_godot']='+Z';report['up_godot']='+Y';report['actions']=['Fly','Glide'];report['weights_valid']=all(x['unweighted_vertices']==0 for x in report['meshes']);report['blended_vertices']=sum(x['blended_vertices'] for x in report['meshes'])
with open(os.path.join(OUT,'rig_report.json'),'w') as f:json.dump(report,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'bird_rigged.blend'))
if '--no-render' not in sys.argv:bpy.ops.render.render(write_still=True)
print('RIG_READY',json.dumps({'bones':report['bones'],'weighted_meshes':len(meshes),'blended_vertices':report['blended_vertices']}))
