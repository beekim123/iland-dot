"""Original Beach Cleanup miniature models. Run: blender -b --python generate_models.py
Coordinates in functions use game convention (+Y up, -Z forward).
No external assets, textures or add-ons required.
"""
import bpy, bmesh, math, json
from mathutils import Vector
from pathlib import Path
bpy.context.preferences.filepaths.save_version=0
HERE=Path(__file__).resolve().parent
TRASH=HERE.parent/'trash'
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def v(p):return Vector((p[0],-p[2],p[1]))
def mat(n,c):
 m=bpy.data.materials.get(n) or bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.86
 return m
sand=mat('warm porcelain sand',(.79,.69,.48));cream=mat('chalk ivory',(.92,.88,.73));teal=mat('sea glass teal',(.16,.43,.42));dark=mat('deep kelp rubber',(.065,.15,.16));terra=mat('fired terracotta',(.67,.27,.16));blue=mat('weathered blue',(.27,.48,.57));rope=mat('ochre rope',(.52,.39,.22))
def finish(o,n,m,parent=None):
 o.name=n;o.data.materials.append(m);bpy.context.view_layer.update()
 if parent:
  world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
 return o
def empty(n,p=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.location=v(p);bpy.context.view_layer.update()
 if parent:
  world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
 return o
def box(n,p,s,m,bevel=.03,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('soft molded corners','BEVEL');mod.width=bevel;mod.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=False
 return finish(o,n,m,parent)
def cyl(n,p,r,d,m,axis=(0,1,0),parent=None,vertices=20):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d,location=v(p));o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(v(axis));
 if n=='rounded rubber tire':
  mod=o.modifiers.new('rounded tire shoulders','BEVEL');mod.width=.018;mod.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,n,m,parent)
def beam(n,a,b,r,m,parent=None,vertices=12):
 a,b=Vector(a),Vector(b);return cyl(n,(a+b)*.5,r,(b-a).length,m,b-a,parent,vertices)
def merge_rigid_parts():
 # Keep every articulated pivot, batch all geometry on each rigid part.
 # Original matte palette is baked as linear vertex colors, not textures.
 material=mat('matte sand sculpture vertex palette',(1,1,1))
 nodes=material.node_tree.nodes
 vc=nodes.get('Vertex palette') or nodes.new('ShaderNodeVertexColor');vc.name='Vertex palette';vc.layer_name='Color'
 material.node_tree.links.new(vc.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
 groups={}
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  color=obj.data.color_attributes.get('Color') or obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
  for polygon in obj.data.polygons:
   rgba=obj.data.materials[polygon.material_index].diffuse_color
   for loop in polygon.loop_indices:color.data[loop].color=rgba
  obj.data.materials.clear();obj.data.materials.append(material)
  for polygon in obj.data.polygons:polygon.material_index=0
  groups.setdefault(obj.parent,[]).append(obj)
 for parent,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
  objects[0].name=(parent.name if parent else 'Trash')+'_surface'
  mesh=objects[0].data;bm=bmesh.new();bm.from_mesh(mesh)
  bmesh.ops.triangulate(bm,faces=list(bm.faces))
  degenerate=[face for face in bm.faces if face.calc_area()<=1e-8]
  if degenerate:bmesh.ops.delete(bm,geom=degenerate,context='FACES_ONLY')
  bm.to_mesh(mesh);bm.free();mesh.update()

def export(name,folder):
 folder.mkdir(parents=True,exist_ok=True)
 merge_rigid_parts()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=0
 for o in meshes:
  o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
  assert all(len(f.vertices)>=3 for f in o.data.polygons)
  assert all(all(math.isfinite(x) for x in vert.co) for vert in o.data.vertices)
 (folder/'source').mkdir(exist_ok=True)
 (folder/'source'/'.gdignore').touch()
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source'/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(folder/(name+'.glb')),export_format='GLB',export_yup=True)
 (folder/(name+'.audit.json')).write_text(json.dumps({'original':True,'triangles':tri,'mesh_count':len(meshes),'materials':sorted(set(m.name for o in meshes for m in o.data.materials)),'finite_vertices':True},indent=2))
reset()
root=empty('CartModel')
box('single molded hull',(0,.43,0),(1.0,.34,1.22),teal,.14,root)
box('ivory top deck',(0,.605,0),(1.01,.08,1.13),cream,.05,root)
box('front bumper',(0,.32,-.64),(.85,.1,.11),terra,.035,root)
# A clear front fascia, not a humanoid face.
box('sensor dark inset',(0,.51,-.61),(.48,.1,.026),dark,.022,root)
for x in [-.29,.29]:cyl('amber reflector',(x,.51,-.625),.045,.025,terra,(0,0,1),root,12)
for x in [-.48,.48]:
 for z in [-.38,.4]:
  wheel=empty(('WheelL' if x<0 else 'WheelR')+('Front' if z<0 else 'Rear'),(x,.24,z),root)
  cyl('rounded rubber tire',(x,.24,z),.235,.16,dark,(1,0,0),wheel,24)
  cyl('sand wheel hub',(x+(-.085 if x<0 else .085),.24,z),.145,.025,sand,(1,0,0),wheel,20)
  cyl('teal axle cap',(x+(-.104 if x<0 else .104),.24,z),.062,.03,teal,(1,0,0),wheel,12)
  for i in range(6):
   t=i*math.tau/6
   cyl('hub bolt',(x+(-.104 if x<0 else .104),.24+math.sin(t)*.1,z+math.cos(t)*.1),.012,.018,cream,(1,0,0),wheel,6)
# Basket is open, rimmed and slatted; not an opaque cube.
box('basket floor',(0,.68,.28),(.78,.055,.55),sand,.025,root)
for x in [-.39,.39]:
 for z in [.015,.555]:beam('basket corner',(x,.7,z),(x,.99,z),.025,terra,root)
 for y in [.78,.88,.99]:beam('basket side rail',(x,y,.015),(x,y,.555),.022,terra,root)
for z in [.015,.555]:
 for y in [.78,.88,.99]:beam('basket cross rail',(-.39,y,z),(.39,y,z),.022,terra,root)
 for x in [-.24,-.08,.08,.24]:beam('basket slender stave',(x,.7,z),(x,.99,z),.012,rope,root)
# Shoulder, elbow, wrist hierarchy. Meshes authored straight -Z and posed by runtime.
cyl('turntable',(0,.69,-.29),.16,.1,terra,parent=root)
shoulder=empty('Shoulder',(0,.77,-.29),root)
cyl('shoulder pin',(0,.77,-.29),.12,.25,sand,(1,0,0),shoulder)
box('upper arm casting',(0,.77,-.53),(.16,.13,.48),teal,.045,shoulder)
beam('upper arm ivory stripe',(.086,.79,-.34),(.086,.79,-.7),.018,cream,shoulder)
elbow=empty('Elbow',(0,.77,-.77),shoulder)
cyl('elbow pivot',(0,.77,-.77),.1,.22,terra,(1,0,0),elbow)
box('forearm casting',(0,.77,-.995),(.13,.11,.45),sand,.04,elbow)
beam('forearm hydraulic rod',(.085,.8,-.83),(.085,.8,-1.16),.022,dark,elbow)
slide=empty('TelescopicSlide',(0,.77,-1.095),elbow)
box('sliding kelp alloy rail',(0,.77,-1.095),(.075,.065,.25),teal,.012,slide)
wrist=empty('Wrist',(0,.77,-1.22),elbow)
cyl('wrist rotary',(0,.77,-1.22),.072,.13,teal,(0,0,1),wrist)
box('claw bridge',(0,.77,-1.3),(.29,.09,.11),terra,.025,wrist)
for sign,label in [(-1,'LeftJaw'),(1,'RightJaw')]:
 jaw=empty(label,(sign*.12,.77,-1.32),wrist)
 box('curved finger',(sign*.12,.77,-1.43),(.055,.075,.22),cream,.025,jaw)
 box('inward grip pad',(sign*.075,.77,-1.54),(.13,.075,.06),dark,.02,jaw)
export('cart_model',HERE)
# Six independently reusable pieces; origins are at ground contact.
reset();cyl('bottle body',(0,.1,0),.075,.26,blue,(0,0,1),vertices=16);cyl('bottle shoulder',(0,.1,-.15),.053,.06,blue,(0,0,1),vertices=16);cyl('bottle cap',(0,.1,-.202),.031,.04,terra,(0,0,1),vertices=12);box('paper label',(0,.166,.025),(.103,.012,.11),cream,.008);export('bottle',TRASH)
reset();cyl('squashed can',(0,.085,0),.085,.19,terra,(0,0,1),vertices=16)
for z in [-.098,.098]:cyl('rolled rim',(0,.085,z),.087,.014,cream,(0,0,1),vertices=16)
box('can stripe',(0,.167,0),(.09,.013,.1),cream,.008);box('opening',(0,.11,-.108),(.05,.025,.008),dark,.004);export('can',TRASH)
reset();o=box('creased wrapper',(0,.023,0),(.27,.026,.2),cream,.015);o.rotation_euler[1]=.1
for x in [-.13,.13]:
 for z in [-.075,-.025,.025,.075]:box('crimped packet edge',(x,.024,z),(.025,.022,.036),terra,.005)
box('wrapper colored panel',(0,.043,0),(.15,.008,.14),terra,.008);beam('wrapper fold',(-.11,.055,-.07),(.1,.055,.07),.008,sand);export('wrapper',TRASH)
reset();box('rounded sandal sole',(0,.03,0),(.15,.045,.32),terra,.065)
beam('left sandal strap',(-.061,.053,.05),(0,.11,-.08),.022,cream);beam('right sandal strap',(.061,.053,.05),(0,.11,-.08),.022,cream);beam('toe post',(0,.04,-.08),(0,.11,-.08),.015,dark);export('sandal',TRASH)
reset();box('crate base',(0,.045,0),(.53,.08,.43),rope,.025)
for x in [-.245,.245]:
 for z in [-.195,.195]:box('crate post',(x,.19,z),(.045,.3,.045),sand,.01)
for y in [.12,.22,.32]:
 for z in [-.2,.2]:box('crate plank',(0,y,z),(.53,.065,.028),sand,.008)
 for x in [-.25,.25]:box('crate plank',(x,y,0),(.028,.065,.43),sand,.008)
export('crate',TRASH)
reset()
for layer in range(2):
 for row in range(7):
  pts=[]
  for i in range(9):
   x=-.25+i*.0625;z=-.18+row*.06;y=.045+layer*.04+.06*math.sin(i*math.pi/8)+.018*math.sin(row*2+i)
   pts.append((x,y,z))
  for a,b in zip(pts,pts[1:]):beam('knotted net cord',a,b,.011,teal,vertices=6)
 for col in range(7):beam('cross weave',(-.21+col*.07,.09+layer*.04,-.19),(-.21+col*.07,.09+layer*.04,.19),.009,teal,vertices=6)
for z in [-.13,.13]:
 for x in [-.23,.23]:cyl('net cork float',(x,.15,z),.03,.065,terra,(1,0,0),vertices=8)
beam('bundle tie',(-.27,.2,0),(.27,.2,0),.016,rope)
export('net',TRASH)
