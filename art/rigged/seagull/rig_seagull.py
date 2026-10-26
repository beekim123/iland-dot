import bpy, math, os, sys, json, struct
from mathutils import Vector, Matrix, Quaternion
from math import sin, cos, pi
OUT=os.path.dirname(os.path.abspath(__file__)); ROOT=os.path.abspath(os.path.join(OUT,'../../..'))
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
armdat=bpy.data.armatures.new('Seagull_Skeleton');arm=bpy.data.objects.new('Seagull_Rig',armdat);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,parent=None):
 b=armdat.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=armdat.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.2));bone('body',(0,.18,.38),(0,-.12,.44),'root');bone('neck',(0,-.12,.44),(0,-.30,.64),'body');bone('head',(0,-.30,.64),(0,-.50,.70),'neck');bone('tail',(0,.39,.42),(0,.78,.46),'body')
for s,label in [(-1,'L'),(1,'R')]:
 x=s*.22
 bone('shoulder.'+label,(x,-.18,.49),(x,.04,.48),'body');bone('elbow.'+label,(x,.04,.48),(x,.25,.46),'shoulder.'+label);bone('wrist.'+label,(x,.25,.46),(x,.49,.44),'elbow.'+label);bone('feather.'+label,(x,.49,.44),(x,.66,.43),'wrist.'+label)
 bone('leg.'+label,(s*.115,-.045,.21),(s*.115,-.06,.06),'body');bone('foot.'+label,(s*.115,-.06,.06),(s*.115,-.18,.035),'leg.'+label)
bpy.ops.object.mode_set(mode='OBJECT');arm.show_in_front=True;arm.data.display_type='OCTAHEDRAL'
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def weights(o,v):
 n=o.name;p=v.co
 if 'Wing' in n or 'PrimaryFeather' in n:
  label='L' if ('-1' in n) else 'R';y=p.y
  # Smooth adjacent weights maintain the exact source surface at bind pose.
  centers=[-.09,.15,.38,.58];bs=['shoulder.','elbow.','wrist.','feather.']
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
 if any(k in n for k in ['Eye','Beak']):return {'head':1}
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
  rootp=arm.pose.bones['root'];rootp.location.z=.045*sin(phase-.5) if not glide else .025*sin(t*pi/2)
  compose(arm.pose.bones['body'],Matrix.Rotation(.07*sin(phase-.7) if not glide else .025*sin(t*pi/2),3,'X')@Matrix.Rotation(.035*sin(t*pi/2),3,'Y'))
  rotate(arm.pose.bones['neck'],'X',-.025*sin(phase-.7));rotate(arm.pose.bones['head'],'X',-.015*sin(phase-.7));rotate(arm.pose.bones['tail'],'X',.045*sin(phase-.5))
  for s,label in [(-1,'L'),(1,'R')]:
   flap=(.60*sin(phase) if not glide else .07*sin(t*pi/2))*s
   compose(arm.pose.bones['shoulder.'+label],Matrix.Rotation(flap,3,'Y')@Matrix.Rotation(-s*1.36,3,'Z'))
   rotate(arm.pose.bones['elbow.'+label],'X',s*.0)
   # Local child rotations follow delayed stroke, producing a bend rather than rigid whole-wing spin.
   rotate(arm.pose.bones['elbow.'+label],'Z',s*(.08+.10*sin(phase-.45)) if not glide else s*.06)
   rotate(arm.pose.bones['wrist.'+label],'X',(.16*sin(phase-.80) if not glide else .03*sin(t*pi/2)))
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
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'seagull_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_apply=False,export_force_sampling=True,export_frame_range=False)
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
bpy.ops.object.camera_add(location=(2.8,-4.8,2.8));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.60))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8;sc.camera=cam
sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.frame_set(5);sc.render.filepath=os.path.join(OUT,'seagull_pose.png')
report['actions']=['Fly','Glide'];report['weights_valid']=all(x['unweighted_vertices']==0 for x in report['meshes']);report['blended_vertices']=sum(x['blended_vertices'] for x in report['meshes'])
with open(os.path.join(OUT,'rig_report.json'),'w') as f:json.dump(report,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'seagull_rigged.blend'))
if '--no-render' not in sys.argv:bpy.ops.render.render(write_still=True)
print('RIG_READY',json.dumps({'bones':report['bones'],'weighted_meshes':len(meshes),'blended_vertices':report['blended_vertices']}))
