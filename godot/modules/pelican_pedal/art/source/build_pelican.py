import bpy, math, json, os
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
for k,h in {'cream':'fff2d9','wing':'e9dcc1','beak':'ffbd57','pouch':'f49b75','eye':'182e3b','white':'ffffff','mint':'64bda8','coral':'ed775f','navy':'274958','rubber':'38464a','metal':'c2d9cb','leather':'805546'}.items():
 m=bpy.data.materials.new(k);m.diffuse_color=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1,);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.72;M[k]=m
P=lambda v:Vector((v[0],-v[2],v[1]))
objects=[]
def finish(o,name,mat,bone=None):
 o.name=name;o.data.materials.append(M[mat]);
 for f in o.data.polygons:f.use_smooth=True
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bone:
  g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 objects.append(o);return o
def ell(name,pos,scale,mat,bone=None,seg=12,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=P(pos));o=bpy.context.object;o.scale=(scale[0],scale[2],scale[1]);return finish(o,name,mat,bone)
def rod(name,a,b,r,mat,bone=None,verts=10):
 aa,bb=P(a),P(b);bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=(bb-aa).length,location=(aa+bb)/2);o=bpy.context.object;o.rotation_euler=(bb-aa).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,bone)
def tor(name,pos,major,minor,mat,axis='X'):
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=P(pos),major_radius=major,minor_radius=minor);o=bpy.context.object
 if axis=='X':o.rotation_euler[1]=math.pi/2
 return finish(o,name,mat)
def join(name,obs):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
bones={
 'root':((0,0,0),(0,.3,0),None),'body':((0,.7,.12),(0,1.15,.08),'root'),
 'neck':((0,1.12,.04),(0,1.48,-.06),'body'),'head':((0,1.45,-.06),(0,1.78,-.09),'neck'),
 'beak':((0,1.53,-.24),(0,1.5,-.83),'head'),
 'tail':((0,.89,.28),(0,.87,.55),'body')}
for s,x in [('L',-1),('R',1)]:
 bones.update({f'wing_{s}':((x*.24,1.18,.04),(x*.43,1.03,-.26),'body'),f'hand_{s}':((x*.43,1.03,-.26),(x*.43,1.04,-.62),f'wing_{s}'),f'thigh_{s}':((x*.16,.83,.08),(x*.22,.62,-.16),'body'),f'shin_{s}':((x*.22,.62,-.16),(x*.22,.34,.0),f'thigh_{s}'),f'foot_{s}':((x*.22,.34,0),(x*.22,.31,-.18),f'shin_{s}')})
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='PelicanSkeleton';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(a,b,p) in bones.items():
 e=rig.data.edit_bones.new(n);e.head=P(a);e.tail=P(b)
 if p:e.parent=rig.data.edit_bones[p]
bpy.ops.object.mode_set(mode='OBJECT')
# Plush seated silhouette and sculpted large bill/pouch.
ell('PearBody',(0,1.02,.11),(.29,.36,.27),'cream','body')
ell('Breast',(0,1.05,-.11),(.24,.28,.14),'white','body')
ell('LongNeck',(0,1.34,-.01),(.15,.25,.15),'cream','neck')
ell('RoundHead',(0,1.65,-.11),(.235,.245,.22),'cream','head',16,10)
ell('UpperBill',(0,1.55,-.50),(.125,.075,.38),'beak','beak',16,8)
ell('BillTip',(0,1.51,-.83),(.095,.072,.095),'beak','beak')
ell('SoftPouch',(0,1.465,-.49),(.13,.10,.28),'pouch','beak',16,8)
rod('BillSeam',(-.11,1.505,-.3),(-.04,1.505,-.84),.008,'coral','beak',6);rod('BillSeamR',(.11,1.505,-.3),(.04,1.505,-.84),.008,'coral','beak',6)
for s,x in [('L',-1),('R',1)]:
 ell('EyeWhite'+s,(x*.181,1.685,-.25),(.066,.081,.043),'white','head')
 ell('Eye'+s,(x*.189,1.681,-.284),(.036,.052,.019),'eye','head')
 ell('Glint'+s,(x*.18,1.701,-.3),(.012,.015,.009),'white','head')
 ell('Cheek'+s,(x*.205,1.605,-.245),(.042,.025,.015),'pouch','head')
 # Wingtips wrap grips, with obvious feather lobes.
 ell('WingUpper'+s,(x*.33,1.12,-.12),(.14,.135,.21),'wing','wing_'+s)
 ell('WingForearm'+s,(x*.43,1.065,-.39),(.105,.075,.22),'cream','hand_'+s)
 for j in range(3):ell('Feather'+s+str(j),(x*(.36+.06*j),1.045,-.55),(.044,.045,.115),'cream','hand_'+s)
 ell('Thigh'+s,(x*.19,.75,-.055),(.10,.15,.13),'cream','thigh_'+s)
 rod('Shin'+s,(x*.22,.62,-.16),(x*.22,.34,0),.035,'beak','shin_'+s)
 ell('WebFoot'+s,(x*.22,.31,-.10),(.115,.035,.15),'beak','foot_'+s)
 for j in range(3):ell('Toe'+s+str(j),(x*.22+(j-1)*.065,.31,-.21),(.04,.028,.06),'beak','foot_'+s)
for j in range(3):ell('TailFeather'+str(j),((j-1)*.09,.91,.37),(.07,.08,.23),'wing','tail')
# Coral delivery cap and neckerchief create a friendly original courier identity.
ell('Cap',(0,1.835,-.105),(.24,.072,.215),'mint','head',16,8)
ell('CapBrim',(0,1.81,-.30),(.21,.018,.15),'mint','head')
ell('CapButton',(0,1.91,-.11),(.035,.024,.035),'coral','head')
ell('ScarfBand',(0,1.28,-.035),(.165,.048,.16),'coral','neck')
ell('ScarfKnot',(.12,1.23,-.16),(.05,.065,.045),'coral','neck')
full=join('PelicanSkin',objects[:]);objects=[]
# Genuine non-rigid shoulder transition: blend upper feather vertices between arm and body.
for s in ['L','R']:
 vg=full.vertex_groups.get('wing_'+s);body=full.vertex_groups.get('body')
 for v in full.data.vertices:
  if any(g.group==vg.index for g in v.groups):
   world=full.matrix_world@v.co
   # Godot z corresponds - Blender y; blend only shoulder zone.
   if abs(world.x)<.32:
    vg.add([v.index],.72,'REPLACE');body.add([v.index],.28,'REPLACE')
def skin(mesh):
 mesh.parent=rig;mod=mesh.modifiers.new('TrueSkin','ARMATURE');mod.object=rig
skin(full)
# First person mesh retains arms, bill and pedaling legs, excludes head/torso to prevent camera clipping.
fp=full.copy();fp.data=full.data.copy();bpy.context.collection.objects.link(fp);fp.name='FirstPersonSkin'
import bmesh
bm=bmesh.new();bm.from_mesh(fp.data);layer=bm.verts.layers.deform.verify();keep=[fp.vertex_groups[n].index for n in bones if n.startswith(('wing_','hand_','thigh_','shin_','foot_')) ]
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not any(i in v[layer] for i in keep)],context='VERTS');bm.to_mesh(fp.data);bm.free()
# The first-person viewmodel keeps only a short lowered bill tip; the full model remains anatomically intact.
fp_tip=ell('FPBillTip',(0,1.28,-.39),(.075,.035,.30),'beak','beak')
fp=join('FirstPersonSkin',[fp,fp_tip]);objects=[]
# Animation clips use deform bones (not root/node bob tricks).
rig.animation_data_create()
for clip,duration in [('idle',60),('pedal',30),('steer_left',30),('steer_right',30),('brake',24)]:
 act=bpy.data.actions.new(clip);rig.animation_data.action=act
 for frame in range(0,duration+1,1):
  phase=frame/duration*math.tau
  for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
  rig.pose.bones['body'].rotation_euler[0]=.012*math.sin(phase)
  rig.pose.bones['neck'].rotation_euler[0]=.018*math.sin(phase)
  if clip=='pedal':
   # Two-segment analytic leg solve: foot stays on the rotating pedal rather than waving near it.
   for side,off,sign in [('L',0,-1),('R',math.pi,1)]:
    hip=rig.data.bones['thigh_'+side].head_local.copy()
    ankle=P((sign*.22,.39+.12*math.sin(phase+off),.08-.12*math.cos(phase+off)))
    l1=rig.data.bones['thigh_'+side].length; l2=rig.data.bones['shin_'+side].length
    axis=ankle-hip; distance=axis.length; axis.normalize()
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    front=P((0,0,-1)); sidevec=(front-axis*front.dot(axis)).normalized()
    knee=hip+axis*along+sidevec*math.sqrt(max(0,l1*l1-along*along))
    for name,head,tail in [('thigh_'+side,hip,knee),('shin_'+side,knee,ankle)]:
     rest=rig.data.bones[name]; q=(rest.tail_local-rest.head_local).rotation_difference(tail-head)
     rig.pose.bones[name].matrix=Matrix.Translation(head)@(q@rest.matrix_local.to_quaternion()).to_matrix().to_4x4();bpy.context.view_layer.update()
    rest=rig.data.bones['foot_'+side]
    rig.pose.bones['foot_'+side].matrix=Matrix.Translation(ankle)@rest.matrix_local.to_quaternion().to_matrix().to_4x4()
  if clip.startswith('steer'):
   turn=(-1 if clip.endswith('left') else 1)*.18*math.sin(math.pi*frame/duration)
   for s in ['L','R']:rig.pose.bones['wing_'+s].rotation_euler[2]=turn;rig.pose.bones['hand_'+s].rotation_euler[1]=turn*.6
   rig.pose.bones['head'].rotation_euler[1]=turn*.4
  if clip=='brake':
   amount=math.sin(math.pi*frame/duration)
   rig.pose.bones['body'].rotation_euler[0]=-.08*amount
   for s in ['L','R']:rig.pose.bones['hand_'+s].rotation_euler[0]=-.14*amount
  for pb in rig.pose.bones:pb.keyframe_insert('rotation_euler',frame=frame,group=pb.name);pb.keyframe_insert('location',frame=frame,group=pb.name)
 for fc in act.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
 track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,0,act)
rig.animation_data.action=None
bpy.context.scene.render.fps=30
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
# Bicycle with bold toy silhouette, real wheels and thin low-cost spokes.
wheels=[]
for z in [-.64,.62]:
 start=len(objects)
 tor('CreamTire',(0,.34,z),.29,.045,'cream');tor('MintRim',(0,.34,z),.245,.018,'mint')
 rod('Axle',(-.09,.34,z),(.09,.34,z),.038,'metal')
 for k in range(8):
  ang=k*math.tau/8;rod('Spoke',(0,.34,z),(0,.34+.23*math.sin(ang),z+.23*math.cos(ang)),.008,'metal',verts=6)
 wheel=join('WheelFront' if z<0 else 'WheelRear',objects[start:]); bpy.ops.object.transform_apply(location=False,rotation=True,scale=True); wheels.append(wheel); objects=objects[:start]
A=(0,.37,.12);B=(0,.82,.13);C=(0,.84,-.43);D=(0,.34,.62);E=(0,.34,-.64)
for a,b in [(A,B),(B,C),(C,A),(A,D),(B,D),(C,E)]:rod('Frame',a,b,.032,'mint')
rod('SeatPost',B,(0,.94,.13),.023,'metal');ell('Saddle',(0,.94,.14),(.15,.045,.14),'leather')
rod('HandleStem',C,(0,1.04,-.58),.025,'metal');rod('Handlebar',(-.43,1.04,-.59),(.43,1.04,-.59),.024,'metal')
for x in [-.4,.4]:rod('Grip',(x-.065,1.04,-.59),(x+.065,1.04,-.59),.032,'coral')
rod('CrankAxle',(-.22,.37,.12),(.22,.37,.12),.026,'metal')
pedals=[]
for side,x in [('L',-.22),('R',.22)]:
 pedal=ell('Pedal'+side,(x,.335,-.14 if side=='L' else .10),(.10,.025,.06),'navy');pedals.append(pedal);objects.remove(pedal)
# Open slatted basket in front, see-through geometry, no alpha material.
for x in [-.20,.20]:
 for z in [-.70,-.96]:rod('BasketCorner',(x,.77,z),(x,1.0,z),.014,'leather')
for y in [.78,.89,1.0]:
 for z in [-.70,-.96]:rod('BasketRail',(-.20,y,z),(.20,y,z),.012,'beak')
 for x in [-.20,.20]:rod('BasketSide',(x,y,-.70),(x,y,-.96),.012,'beak')
for x in [-.15,-.075,0,.075,.15]:rod('BasketSlat',(x,.78,-.70),(x,.78,-.96),.014,'beak')
bike=join('Bicycle',objects)
# Save reproducible Blender source and selected GLBs.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'source','pelican_rider.blend'))
def export(name,objs):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0]
 bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'models',name+'.glb'),use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True)
export('pelican_rider',[rig,full]);export('first_person_rig',[rig,fp]);export('bicycle',[bike]+wheels+pedals)
stats={o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'materials':len(o.data.materials)} for o in [full,fp,bike]};stats['bones']=len(bones);stats['clips']=['idle','pedal','steer_left','steer_right','brake'];stats['blended_vertices']=sum(len(v.groups)>1 for v in full.data.vertices)
open(os.path.join(ROOT,'source','stats.json'),'w').write(json.dumps(stats,indent=2));print(stats)
