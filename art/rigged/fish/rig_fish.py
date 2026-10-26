"""Approved v3 fish: true deform bones, normalized smooth skinning, looping Swim action.
blender -b -t 2 --python rig_fish.py [-- --render]
"""
import bpy, os, sys, math, json
from mathutils import Vector, Matrix
OUT=os.path.dirname(os.path.abspath(__file__)); ROOT=os.path.abspath(os.path.join(OUT,'../../..'))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art/v3/animals.blend'))
r=bpy.data.objects['FishRoot']; keep={r,*r.children_recursive}
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
r.matrix_world=Matrix.Identity(4);bpy.context.view_layer.update()
# Bake subdivision and all transform offsets once, keeping approved rest geometry identical.
mesh_objects=[];dg=bpy.context.evaluated_depsgraph_get()
for o in list(keep):
 if o.type!='MESH':continue
 evaluated=o.evaluated_get(dg); me=bpy.data.meshes.new_from_object(evaluated,depsgraph=dg)
 world=o.matrix_world.copy();me.transform(world);o.modifiers.clear();o.parent=None;o.matrix_world=Matrix.Identity(4);o.data=me;mesh_objects.append(o)
for o in list(keep):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
arm=bpy.data.armatures.new('Fish_DeformSkeleton');rig=bpy.data.objects.new('Fish_Rig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('root',(0,0,-.30),(0,0,-.10))
chain=[('head',-.50,-.20),('spine_1',-.20,.0),('spine_2',0,.20),('spine_3',.20,.36),('tail_1',.36,.52),('tail_2',.52,.69)]
parent='root'
for n,a,b in chain:bone(n,(0,a,0),(0,b,0),parent);parent=n
for side,s in [('L',-1),('R',1)]:bone('pectoral_'+side,(s*.17,-.15,-.045),(s*.33,.035,-.07),'spine_1')
bone('dorsal',(0,-.22,.21),(0,.05,.33),'spine_1');bone('anal',(0,-.01,-.19),(0,.16,-.28),'spine_2')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;arm.display_type='BBONE'
centers=[-.32,-.10,.10,.28,.44,.60]; names=[c[0] for c in chain]
def axial(y):
 if y<=-.24:return {'head':1.0}
 # Head remains near-rigid, then continuous quadratic-distance blend through spine and tail.
 if y>=centers[-1]:return {names[-1]:1.0}
 for i in range(len(centers)-1):
  if centers[i]<=y<=centers[i+1]:
   t=(y-centers[i])/(centers[i+1]-centers[i]);t=t*t*(3-2*t)
   return {names[i]:1-t,names[i+1]:t}
 return {'head':1.0}
qa={'source':'art/v3/animals.blend approved FishRoot, evaluated rest mesh unchanged','bone_count':len(arm.bones),'meshes':[], 'unweighted_vertices':0,'max_weight_sum_error':0}
for o in mesh_objects:
 for b in arm.bones:o.vertex_groups.new(name=b.name)
 for v in o.data.vertices:
  p=v.co; w=axial(p.y)
  if 'Fish_Eye_' in o.name or 'Fish_Mouth' in o.name:w={'head':1.0}
  elif 'PectoralFin' in o.name:
   side='L' if p.x<0 else 'R';strength=max(0,min(1,(abs(p.x)-.17)/.09));w={k:value*(1-strength) for k,value in w.items()};w['pectoral_'+side]=strength
  elif 'DorsalRibbon' in o.name:
   strength=max(0,min(.8,(p.z-.21)/.12));w={k:value*(1-strength) for k,value in w.items()};w['dorsal']=strength
  elif 'AnalRibbon' in o.name:
   strength=max(0,min(.7,(-p.z-.19)/.10));w={k:value*(1-strength) for k,value in w.items()};w['anal']=strength
  for n,value in w.items():
   if value>1e-8:o.vertex_groups[n].add([v.index],value,'REPLACE')
  total=sum(g.weight for g in v.groups);qa['unweighted_vertices']+=int(total<.99);qa['max_weight_sum_error']=max(qa['max_weight_sum_error'],abs(total-1))
 mod=o.modifiers.new('True smooth skin deformation','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True;o.parent=rig
 qa['meshes'].append({'name':o.name,'vertices':len(o.data.vertices),'armature_modifier':True})
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=96;sc.render.fps=24
for p in rig.pose.bones:p.rotation_mode='XYZ'
for frame in range(1,98):
 t=0.0 if frame==97 else (frame-1)/24;phase=2*math.pi*1.5*t
 for j,(n,a,b) in enumerate(chain):
  p=rig.pose.bones[n];amp=[.012,.035,.065,.105,.17,.23][j]
  p.rotation_euler=(.007*math.sin(phase*.333+j*.25),0,amp*math.sin(phase-j*.50));p.keyframe_insert('rotation_euler',frame=frame,group=n)
 root=rig.pose.bones['root'];root.location=(.012*math.sin(2*math.pi*t/4),0,.009*math.sin(2*math.pi*t/2));root.keyframe_insert('location',frame=frame,group='root')
 for side,s in [('L',-1),('R',1)]:
  p=rig.pose.bones['pectoral_'+side];p.rotation_euler=(.10*math.sin(phase+.6*s),.08*math.sin(phase+.4),s*.18*math.sin(phase*.5));p.keyframe_insert('rotation_euler',frame=frame,group=p.name)
 for n,amp in [('dorsal',.08),('anal',.07)]:
  p=rig.pose.bones[n];p.rotation_euler=(0,amp*math.sin(phase-.8),0);p.keyframe_insert('rotation_euler',frame=frame,group=n)
action=rig.animation_data.action;action.name='Swim';action.use_fake_user=True
for fc in action.fcurves:
 for k in fc.keyframe_points:k.interpolation='LINEAR'
sc.frame_set(1)
# Export actual joints/weights/action. Only approved fish meshes and armature.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in mesh_objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
sc.frame_end=97
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'fish_rigged.glb'),use_selection=True,export_format='GLB',export_animations=True,export_skins=True,export_yup=True,export_frame_range=True,export_force_sampling=True,export_animation_mode='ACTIONS',export_apply=False)
sc.frame_end=96
# Clean illustrative studio: no changes to fish geometry or materials.
world=bpy.data.worlds.new('FishPreviewWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.48,.50,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;sc.world=world
mat=bpy.data.materials.new('StudioAqua');mat.diffuse_color=(.12,.35,.38,1);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.12,.35,.38,1);bs.inputs['Roughness'].default_value=.95
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.42));floor=bpy.context.object;floor.name='PREVIEW_FLOOR';floor.data.materials.append(mat)
def area(name,loc,power,color,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.size=size;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
area('PreviewKey',(1.7,-2.8,3),200,(1,.91,.79),3)
area('PreviewFill',(-2,-.5,1.5),100,(.7,.9,1),3)
area('PreviewRim',(0,3,2),140,(1,.96,.86),2)
bpy.ops.object.camera_add(location=(2.5,-3.5,1.7));cam=bpy.context.object;cam.name='PreviewCamera';cam.rotation_euler=(Vector((0,.035,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.7;sc.camera=cam
sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=8;sc.cycles.use_denoising=False;sc.cycles.max_bounces=3;sc.render.threads_mode='FIXED';sc.render.threads=2
qa['action']='Swim';qa['frames']=96;qa['fps']=24;qa['duration']=4.0;qa['deformation']='Head near-rigid; smooth axial spine-to-tail waves and blended fin roots'
assert qa['unweighted_vertices']==0 and qa['max_weight_sum_error']<1e-5
json.dump(qa,open(os.path.join(OUT,'rig_qa.json'),'w'),indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'fish_rigged.blend'))
sc.frame_set(8);sc.render.filepath=os.path.join(OUT,'fish_pose.png');bpy.ops.render.render(write_still=True)
print('FISH_POSE_READY',flush=True)
if '--render' in sys.argv:
 os.makedirs(os.path.join(OUT,'frames'),exist_ok=True);sc.render.filepath=os.path.join(OUT,'frames','fish_');sc.frame_set(1);bpy.ops.render.render(animation=True)
print('FISH_RIG_COMPLETE',json.dumps(qa),flush=True)
