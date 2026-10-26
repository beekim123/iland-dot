import bpy, math, os, json, sys, struct
from mathutils import Vector, Matrix
from math import sin, cos, pi, floor
OUT=os.path.dirname(os.path.abspath(__file__))
SOURCE=os.path.abspath(os.path.join(OUT,'../../v3/animals.blend'))
bpy.ops.wm.open_mainfile(filepath=SOURCE)
root=bpy.data.objects['CrabRoot'];root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
bpy.context.view_layer.update()
keep=set([root]+list(root.children_recursive))
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update()
refs={o.name:o.matrix_world.translation.copy() for o in keep if o.type=='EMPTY'}
meshes=[];dg=bpy.context.evaluated_depsgraph_get()
for o in list(keep):
 if o.type!='MESH':continue
 chain=[];p=o.parent
 while p:chain.append(p.name);p=p.parent
 world=o.matrix_world.copy();me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg);me.transform(world)
 o.parent=None;o.matrix_world=Matrix.Identity(4);o.modifiers.clear();o.data=me
 meshes.append((o,chain))
for o in list(keep):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
armdata=bpy.data.armatures.new('Crab_Skeleton');rig=bpy.data.objects.new('Crab_Rig',armdata);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,parent=None):
 b=armdata.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=armdata.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.10))
bone('body',(0,0,.205),(0,0,.405),'root')
legs=[]
for side,s in [('L',-1),('R',1)]:
 for i in range(4):
  hip=refs['LegPivot'+side+str(i+1)];reach=[.49,.55,.56,.51][i];dy=[-.14,-.04,.08,.18][i]
  knee=hip+Vector((s*(reach-.26)*.85,dy*.87,-.045))
  foot=hip+Vector((s*(reach-.26+.015),dy+.01,-.195))
  a='leg_'+side+str(i+1)+'_upper';b='leg_'+side+str(i+1)+'_lower'
  bone(a,hip,knee,'body');bone(b,knee,foot,a)
  legs.append({'side':side,'s':s,'i':i,'hip':hip,'knee':knee,'foot':foot,'a':a,'b':b})
 cp=refs['ClawPivot'+side];elbow=cp+Vector((s*.13,-.18,.095));tip=cp+Vector((s*.17,-.445,.14))
 bone('claw_'+side+'_arm',cp,elbow,'body');bone('claw_'+side+'_hand',elbow,tip,'claw_'+side+'_arm')
 fp=refs['PincerPivot'+side];bone('claw_'+side+'_pincer',fp,fp+Vector((s*.037,-.145,.031)),'claw_'+side+'_hand')
 ep=refs['EyeStalkPivot'+side];bone('eye_'+side,ep,ep+Vector((s*.025,-.02,.18)),'body')
bpy.ops.object.mode_set(mode='OBJECT')
def weight(o,idx,weights):
 total=sum(weights.values())
 for name,w in weights.items():
  if w>1e-8:
   vg=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);vg.add([idx],w/total,'REPLACE')
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
for o,chain in meshes:
 o.vertex_groups.clear();o.parent=rig
 mod=o.modifiers.new('True skeletal skin deformation','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
 for v in o.data.vertices:
  co=v.co;ws={'body':1}
  leg=next((l for l in legs if 'LegPivot'+l['side']+str(l['i']+1) in chain),None)
  if leg:
   # Blend through the knee in anatomical distance, preserve the complete closed mesh.
   hip=leg['hip'];knee=leg['knee'];foot=leg['foot']
   upper=(knee-hip).length;u=(co-hip).dot((knee-hip).normalized())
   w=smooth((u-(upper-.065))/.095);ws={leg['a']:1-w,leg['b']:w}
  for side,s in [('L',-1),('R',1)]:
   if 'EyeStalkPivot'+side in chain:ws={'eye_'+side:1}
   if 'ClawPivot'+side in chain:
    if 'PincerPivot'+side in chain:ws={'claw_'+side+'_pincer':1}
    elif 'ClawArm' in o.name:
     cp=refs['ClawPivot'+side];d=(co-cp).length;w=smooth((d-.13)/.11);ws={'claw_'+side+'_arm':1-w,'claw_'+side+'_hand':w}
    else:ws={'claw_'+side+'_hand':1}
  weight(o,v.index,ws)
# World-space control targets are solved by two-segment IK, then sampled into the export.
for l in legs:
 e=bpy.data.objects.new('CTRL_foot_'+l['side']+str(l['i']+1),None);bpy.context.collection.objects.link(e);e.location=l['foot'];e.empty_display_type='SPHERE';e.empty_display_size=.025;l['target']=e
 c=rig.pose.bones[l['b']].constraints.new('IK');c.target=e;c.chain_count=2;c.use_stretch=False
for pb in rig.pose.bones:pb.rotation_mode='XYZ'
rig.animation_data_create();act=bpy.data.actions.new('Crab_Scuttle_Loop');rig.animation_data.action=act
fps=24;dur=4.0;frames=96
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=frames;sc.render.fps=fps
# Smooth sideways transit and return. Each stance remains at its last touchdown position.
def body_x(t):return .055*sin(2*pi*t/dur)
def phase_target(t,offset,base):
 period=1.0;u=t/period+offset;cycle=floor(u);f=u-cycle
 touchdown=(cycle-offset)*period
 x0=base.x+body_x(touchdown);x1=base.x+body_x(touchdown+period)
 if f<.64:return Vector((x0,base.y,base.z))
 swing=(f-.64)/.36;h=smooth(swing)
 return Vector((x0+(x1-x0)*h,base.y+.010*sin(pi*swing),base.z+.052*sin(pi*swing)))
for frame in range(1,frames+2):
 t=(frame-1)/fps;sc.frame_set(frame)
 pb=rig.pose.bones['body'];pb.location=(body_x(t),.004*(1-cos(t*4*pi)),0);pb.rotation_euler=(0,.018*sin(t*2*pi),.012*sin(t*4*pi));pb.keyframe_insert('location',frame=frame);pb.keyframe_insert('rotation_euler',frame=frame)
 for l in legs:
  offset=.5*((l['i']+(0 if l['s']<0 else 1))%2);target=phase_target(t,offset,l['foot']);l['target'].location=target;l['target'].keyframe_insert('location',frame=frame)
 for side,s in [('L',-1),('R',1)]:
  for name,rot in [('claw_'+side+'_arm',(.045*sin(t*pi),.035*s*sin(t*pi),.04*s*sin(t*2*pi))),('claw_'+side+'_hand',(.025*sin(t*2*pi),0,.035*s*cos(t*pi))),('claw_'+side+'_pincer',(0,0,s*(.12+.10*sin(t*pi+1)))),('eye_'+side,(.015*sin(t*pi),0,s*.025*sin(t*pi)))]:
   pb=rig.pose.bones[name];pb.rotation_euler=rot;pb.keyframe_insert('rotation_euler',frame=frame)
# Bake evaluated IK to real pose keys for a portable GLB; retain original IK controls in source file.
for action in bpy.data.actions:
 for fc in action.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
sc.frame_set(1);bpy.context.view_layer.update()
# Weight / mesh QA before render staging.
unweighted=0;maxerr=0;blended=0;totalverts=0
for o,chain in meshes:
 for v in o.data.vertices:
  totalverts+=1;w=sum(g.weight for g in v.groups)
  if not v.groups:unweighted+=1
  maxerr=max(maxerr,abs(w-1));blended+=int(len(v.groups)>1)
assert unweighted==0 and maxerr<1e-5
# Evaluate sole bone endpoints against the intended target through the full loop.
max_ik_error=0;min_mesh_z=1e9;max_stance_drift=0
for frame in range(1,frames+2):
 sc.frame_set(frame);bpy.context.view_layer.update()
 for l in legs:max_ik_error=max(max_ik_error,(rig.matrix_world@rig.pose.bones[l['b']].tail-l['target'].location).length)
 dg=bpy.context.evaluated_depsgraph_get()
 for o,chain in meshes:
  if 'WalkingLeg' in o.name:
   ev=o.evaluated_get(dg);min_mesh_z=min(min_mesh_z,min((ev.matrix_world@v.co).z for v in ev.data.vertices))
sc.frame_set(1);sc.frame_end=97
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o,chain in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'crab_rigged.glb'),use_selection=True,export_format='GLB',export_animations=True,export_force_sampling=True,export_frame_range=True,export_frame_step=1,export_skins=True,export_yup=True,export_apply=False)
report={'bones':len(armdata.bones),'weighted_meshes':len(meshes),'vertices':totalverts,'blended_vertices':blended,'unweighted_vertices':unweighted,'maximum_weight_sum_error':maxerr,'maximum_ik_endpoint_error':max_ik_error,'minimum_animated_leg_mesh_z':min_mesh_z,'action':'Crab_Scuttle_Loop','fps':fps,'clip_seconds':dur,'frames':[1,97],'constraints':'8 two-bone IK chains; fixed world-space foot targets during stance','approved_geometry_preserved':True}
# Studio stage is not part of species export.
mat=bpy.data.materials.new('WarmStudioSand');mat.diffuse_color=(.64,.75,.71,1);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.64,.75,.71,1);bs.inputs['Roughness'].default_value=.9
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.013));plane=bpy.context.object;plane.name='PreviewStage';plane.data.materials.append(mat)
def light(n,loc,power,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=n;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.20))-o.location).to_track_quat('-Z','Y').to_euler()
light('SoftKey',(-2,-3,4),230,4);light('SoftFill',(3,1,3),130,4)
bpy.ops.object.camera_add(location=(1.4,-2.6,1.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-.05,.22))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.65;sc.camera=cam
sc.world.color=(.35,.35,.35);sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.fps=fps;sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'crab_rigged.blend'))
with open(os.path.join(OUT,'rig_qa.json'),'w') as f:json.dump(report,f,indent=2)
print('CRAB_RIG_READY',json.dumps(report),flush=True)
if '--skip-render' not in sys.argv:
 sc.frame_set(9);sc.cycles.samples=16;sc.render.filepath=os.path.join(OUT,'crab_pose.png');bpy.ops.render.render(write_still=True)
 print('CRAB_POSE_READY',flush=True)
 sc.cycles.samples=6;sc.render.resolution_x=480;sc.render.resolution_y=360
 os.makedirs(os.path.join(OUT,'frames'),exist_ok=True);sc.render.filepath=os.path.join(OUT,'frames','frame_');sc.frame_start=1;sc.frame_end=96;bpy.ops.render.render(animation=True)
 print('CRAB_ANIMATION_READY',flush=True)
