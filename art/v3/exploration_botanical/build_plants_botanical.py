"""Cunera island v3 botanical collection. Blender 4.3+, editable geometry only.

Run: blender -b -t 8 --python art/v3/build_plants.py
Use -- --quick for a small preview; -- --no-render exports only.
Palm roots and foliage roots sit at ground Z=0, with Blender -Y front.
No imported art, textures, alpha cards, metaballs or procedural redraws.
"""
import bpy, math, random, os, json, sys
from mathutils import Vector
from math import sin, cos, pi, tau
random.seed(3619)
OUT=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.dirname(os.path.dirname(OUT))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.materials): bpy.data.materials.remove(block)
M={}
def material(name,color,rough=.68):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 p.inputs['Specular IOR Level'].default_value=.26
 M[name]=m;return m
for name,col in {
 'Palm Emerald':(.018,.19,.052),'Palm Jade':(.035,.30,.075),'Palm Sunlit':(.13,.41,.075),
 'Leaf Deep':(.015,.14,.059),'Leaf Emerald':(.025,.25,.085),'Leaf Jade':(.06,.36,.12),
 'Leaf Lime':(.20,.44,.065),'Leaf Vein':(.09,.25,.035),'Petiole':(.10,.25,.05),
 'Trunk Honey':(.47,.275,.12),'Trunk Light':(.58,.36,.17),'Trunk Growth':(.33,.19,.085),
 'Coconut Green':(.31,.37,.09),'Coconut Gold':(.46,.36,.10),'Coconut Husk':(.32,.20,.085),
 'Coral Petal':(.93,.19,.18),'Peach Petal':(1,.40,.22),'Cream Petal':(1,.88,.56),
 'Flower Gold':(1,.58,.08),'Flower Eye':(.65,.19,.025),'Studio Sand':(.72,.66,.52)
}.items():material(name,col)
assets=[];curr=None
def root(name):
 global curr
 curr=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(curr);curr.empty_display_type='PLAIN_AXES';curr.empty_display_size=.4
 curr['asset_version']='3.0 botanical rebuild';curr['forward']='-Y';curr['ground_origin_z']=0.0;assets.append(curr);return curr

def mesh(name,verts,faces,mat_names,smooth=True,mats=None):
 me=bpy.data.meshes.new(name+'_mesh');me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
 if curr:ob.parent=curr
 if isinstance(mat_names,str):mat_names=[mat_names]
 for n in mat_names:me.materials.append(M[n])
 for p in me.polygons:
  p.use_smooth=smooth
  if mats:p.material_index=mats[p.index%len(mats)]
 return ob

def tube(name,pts,radii,material,sides=8):
 pts=[Vector(p) for p in pts];vs=[];fs=[]
 for i,p in enumerate(pts):
  axis=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
  ref=Vector((0,1,0)) if abs(axis.y)<.96 else Vector((1,0,0));u=axis.cross(ref).normalized();v=axis.cross(u).normalized()
  for j in range(sides):vs.append(tuple(p+radii[i]*(u*cos(tau*j/sides)+v*sin(tau*j/sides))))
 for i in range(len(pts)-1):
  for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;fs.append((a,b,b+sides,a+sides))
 fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(pts)-1)*sides+j for j in range(sides))])
 return mesh(name,vs,fs,material)

def ellipsoid(name,point,scale,material,segments=12,rings=8,rot=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=point)
 ob=bpy.context.object;ob.name=name;ob.scale=scale;ob.data.materials.append(M[material]);ob.parent=curr
 if rot:ob.rotation_euler=rot
 for p in ob.data.polygons:p.use_smooth=True
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return ob

def join_objects(obs,name,pivot=(0,0,0)):
 if not obs:return None
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=obs[0];o.name=name
 # Recenter only the mesh without altering its visible location; animation pivot is meaningful.
 pv=Vector(pivot); inv=o.matrix_world.inverted();local=inv@pv
 for v in o.data.vertices:v.co-=local
 o.location+=local
 return o

def leaf_geometry(start,direction,length,width,lift=0,droop=.15,segments=7,fold=.16,notch=False,asym=0):
 """A folded, bowed blade, full geometry. Five transverse points preserve a midrib crease."""
 o=Vector(start);d=Vector(direction).normalized();side=Vector((-d.y,d.x,0)).normalized()
 vs=[];fs=[]
 for j in range(segments+1):
  t=j/segments;profile=max(.008,sin(pi*t)**.73)
  c=o+d*length*t+Vector((0,0,lift*sin(t*pi*.85)-droop*t*t))
  for k,s in enumerate((-1,-.38,0,.38,1)):
   edge=1
   if notch and k in (0,4) and j in (3,6,9,12):edge=.40 if (j+k)%2 else .25
   w=width*profile*(1+asym*s)*edge
   # Raised central fold, subtle asymmetric twist; drooping leaf edges make readable volume.
   z=-abs(s)**1.45*w*fold + s*.07*sin(t*pi*1.4)*length
   vs.append(tuple(c+side*s*w+Vector((0,0,z))))
 for j in range(segments):
  for k in range(4):a=j*5+k;fs.append((a,a+5,a+6,a+1))
 return vs,fs

def blade(name,start,direction,length,width,material,lift=.2,droop=.1,segments=9,fold=.23,notch=False,vein=False,asym=0):
 vs,fs=leaf_geometry(start,direction,length,width,lift,droop,segments,fold,notch,asym)
 ob=mesh(name,vs,fs,material)
 if vein:
  d=Vector(direction).normalized();o=Vector(start)
  pts=[o+d*length*t+Vector((0,0,lift*sin(t*pi*.85)-droop*t*t+.013)) for t in [0,.2,.4,.6,.8,.96]]
  v=tube(name+'_midrib',pts,[.017,.015,.013,.010,.006,.001],'Leaf Vein',5)
  return [ob,v]
 return [ob]

def palm(name,height,lean,seed,size=1):
 rng=random.Random(seed);rt=root(name);rt['species']='Stylized coconut palm, true pinnate fronds';rt['canopy_fronds']=6
 # A bent living trunk, lightly fluted at the base and irregularly tapered.
 ln=Vector((lean[0],lean[1],0))
 def center(t):return Vector((ln.x*(.16*t+.84*t*t),ln.y*(.22*t+.78*t*t),height*t))
 N=84;S=12;vs=[];fs=[];mi=[]
 for j in range(N+1):
  t=j/N;c=center(t);axis=(center(min(1,t+.01))-center(max(0,t-.01))).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
  radius=(.27*(1-t)+.12*t)*size
  radius*=1+.18*math.exp(-t*13)+.028*sin(t*tau*22)
  for k in range(S):
   a=tau*k/S;rr=radius*(1+.035*sin(a*5+t*4)+.035*sin(a*3)*(1-t)**3)
   vs.append(tuple(c+rr*(u*cos(a)+v*sin(a))))
 for j in range(N):
  for k in range(S):
   a=j*S+k;b=j*S+(k+1)%S;fs.append((a,b,b+S,a+S))
   # Thin growth scars are surface color, not stacked cylinders.
   mi.append(2 if j%5==1 else (1 if (k+int(j/9))%5 in [0,1] else 0))
 fs.extend([tuple(range(S-1,-1,-1)),tuple(N*S+k for k in range(S))]);mi.extend([0,0])
 trunk=mesh(name+'_BowedTrunk',vs,fs,['Trunk Honey','Trunk Light','Trunk Growth'],mats=mi)
 # Fine light root toes are bent extensions of the trunk, not a flat cylinder bottom.
 toes=[]
 for k in range(5):
  a=tau*k/5+.13;end=Vector((cos(a)*.40*size,sin(a)*.40*size,.02))
  toes.append(tube(name+'_RootToe',[Vector((0,0,.26)),Vector((end.x*.5,end.y*.5,.09)),end],[.10*size,.07*size,.015*size],'Trunk Honey',7))
 join_objects([trunk]+toes,name+'_BowedTrunk')
 crown=center(1);ellipsoid(name+'_CrownSheath',crown+Vector((0,0,.06)),(.23*size,.24*size,.35*size),'Petiole')
 # Irregular directional layers, no radial flat star. Upper pair is shorter and more vertical.
 angles=[-116,-47,14,76,146,208]
 for fi,adeg in enumerate(angles):
  a=math.radians(adeg+rng.uniform(-8,8));d=Vector((cos(a),sin(a),0));side=Vector((-d.y,d.x,0))
  upper=fi in (2,4);L=(2.35 if upper else 2.75)*size*rng.uniform(.92,1.08)
  lift=(1.22 if upper else .72)*size;drop=(.45 if upper else 1.0)*size
  start=crown+Vector((0,0,.10+(fi%3)*.075))
  def frond(t):return start+d*(L*t)+side*(.12*sin(t*pi)*sin(fi))+Vector((0,0,lift*sin(pi*t*.88)-drop*t*t))
  obs=[];pts=[frond(j/14) for j in range(15)]
  obs.append(tube(name+f'_Frond{fi+1:02d}_Rachis',pts,[.038*size*(1-j/16)+.002 for j in range(15)],'Leaf Vein',6))
  # Paired leaflets originate individually along the curved rachis.
  for j in range(13):
   u=.13+j*.064;base=frond(u)
   LL=(.45+.57*sin(pi*u)**.8)*(1-.25*u)*size
   for side_sign in (-1,1):
    offset=side_sign*.014+rng.uniform(-.008,.008);b=frond(u+offset)
    dd=(side*side_sign+d*(.19+.28*u)+Vector((0,0,-.15-.24*u))).normalized()
    length=LL*rng.uniform(.93,1.05);width=(.10+.030*sin(pi*u))*size
    mats=['Palm Emerald','Palm Jade','Palm Sunlit']
    material_name=mats[(j+fi+(1 if side_sign>0 else 0))%3] if upper else mats[(j+fi)%2]
    obs+=blade(name+f'_Frond{fi+1:02d}_Leaflet{j:02d}_{side_sign}',b,dd,length,width,material_name,lift=.10*size,droop=(.12+.15*u)*size,segments=6,fold=.45,asym=.12*side_sign)
  # One slender terminal leaflet completes the taper, rather than a flat cut end.
  obs+=blade(name+f'_Frond{fi+1:02d}_Tip',frond(.89),d+Vector((0,0,-.55)),.46*size,.055*size,'Palm Jade',lift=.02,droop=.07,segments=5)
  ob=join_objects(obs,name+f'_Frond_{fi+1:02d}',start)
  ob['animation_role']='flexible canopy; rotate small angles at rachis base';ob['leaflets']=27
 coc=[]
 for j in range(5):
  a=j*tau/5+.4;p=crown+Vector((cos(a)*.255*size,sin(a)*.255*size,-.22*size-(j%2)*.12*size))
  coc.append(ellipsoid(name+'_Coconut',p,(.17*size,.19*size,.23*size),'Coconut Green' if j%3 else 'Coconut Gold',10,7,(.2*sin(a),.25*cos(a),a)))
  coc.append(tube(name+'_FruitStem',[crown,p+Vector((0,0,.14*size))],[.025,.015],'Petiole',5))
 join_objects(coc,name+'_Coconuts')
 return rt

palm('Palm_A',5.65,(1.0,.12),41,1.05)
palm('Palm_B',5.00,(-1.10,.45),53,.97)
palm('Palm_C',4.08,(.43,-.27),74,.85)

def broadleaf(name,kind,seed):
 rng=random.Random(seed);rt=root(name);rt['species']='Monstera split leaves' if kind=='monstera' else 'Banana broadleaf'
 count=7 if kind=='monstera' else 6;parts=[]
 for j in range(count):
  a=j*2.399+.35;d=Vector((cos(a),sin(a),0));h=rng.uniform(.55,1.35) if kind=='monstera' else rng.uniform(.75,1.75)
  end=d*rng.uniform(.25,.55)+Vector((0,0,h));mid=d*.12+Vector((0,0,h*.48))
  parts.append(tube(name+'_CurvedPetiole',[(0,0,.03),mid,end],[.035,.027,.018],'Petiole',6))
  if kind=='monstera':
   leaflen=rng.uniform(.8,1.15);dd=(d+Vector((0,0,.22))).normalized()
   parts+=blade(name+'_SplitBlade',end,dd,leaflen,leaflen*.34,['Leaf Deep','Leaf Emerald','Leaf Jade'][j%3],lift=.18,droop=.35,segments=14,fold=.38,notch=True,vein=True,asym=.09*sin(j))
   # Secondary diagonal veins terminate before leaf edges, revealing the folded leaf volume.
   side=Vector((-dd.y,dd.x,0))
   for t in [.25,.46,.67]:
    center=end+dd*leaflen*t+Vector((0,0,.18*sin(t*pi*.85)-.35*t*t+.016))
    for sign in (-1,1):
     ep=center+side*sign*leaflen*.25*sin(pi*t)+dd*.09+Vector((0,0,-.02))
     parts.append(tube(name+'_SideVein',[center,(center+ep)*.5+Vector((0,0,.01)),ep],[.009,.006,.001],'Leaf Vein',4))
  else:
   leaflen=rng.uniform(1.25,1.65);dd=(d+Vector((0,0,.50 if j%3==0 else .05))).normalized()
   parts+=blade(name+'_LongFoldedBlade',end,dd,leaflen,leaflen*.22,['Leaf Emerald','Leaf Jade','Leaf Lime'][j%3],lift=.27,droop=.50,segments=14,fold=.45,notch=(j in [1,4]),vein=True,asym=.13)
 if kind=='monstera':
  # Two large upward-facing folded leaves make the clump lush at island scale.
  for j,a in enumerate([.40,3.75]):
   d=Vector((cos(a),sin(a),0));base=d*.18+Vector((0,0,1.00+j*.08))
   parts.append(tube(name+'_UprightPetiole',[(0,0,.03),d*.08+Vector((0,0,.55)),base],[.038,.028,.018],'Petiole',6))
   parts+=blade(name+'_UprightSplitBlade',base,d+Vector((0,0,.95)),1.20,.43,'Leaf Jade' if j else 'Leaf Emerald',lift=.18,droop=.18,segments=14,fold=.43,notch=True,vein=True,asym=.08)
 join_objects(parts,name+'_LeavesAndStems');return rt
broadleaf('Foliage_Monstera','monstera',23)
broadleaf('Foliage_Banana','banana',67)

def flowering_bush(name,coral,seed):
 rng=random.Random(seed);rt=root(name);rt['species']='Low tropical flowering shrub: authored foliage sprays'
 stems=[]
 # Five spreading stems each carry three differentiated paired leaf tiers.
 tips=[]
 for bi in range(6):
  a=tau*bi/6+.25;d=Vector((cos(a),sin(a),0));h=rng.uniform(.55,.95);spread=rng.uniform(.38,.69)
  tip=d*spread+Vector((0,0,h));tips.append(tip)
  stems.append(tube(name+'_Branch',[(0,0,.02),d*spread*.5+Vector((0,0,h*.45)),tip],[.035,.025,.009],'Petiole',6))
  for q in range(3):
   t=.40+q*.22;b=d*spread*t+Vector((0,0,h*t));side=Vector((-d.y,d.x,0))
   for sign in [-1,1]:
    direction=(d*.40+side*sign+Vector((0,0,.35))).normalized()
    stems+=blade(name+'_EllipticLeaf',b,direction,rng.uniform(.43,.58),.135,['Leaf Deep','Leaf Emerald','Leaf Jade'][q],lift=.06,droop=.055,segments=7,fold=.32,vein=(q==2))
  # Top branching leaflet a little lighter.
  stems+=blade(name+'_TipLeaf',tip,d+Vector((0,0,.3)),.37,.11,'Leaf Jade',lift=.1,droop=.08,segments=6)
 join_objects(stems,name+'_AuthoredLeafSprays')
 flowers=[]
 for fi in range(7):
  a=fi*2.399;pos=Vector((.61*cos(a),.53*sin(a),.68+.16*sin(a*1.7)))
  flowers.append(tube(name+'_FlowerStem',[(pos.x*.6,pos.y*.6,.35),pos],[.018,.009],'Petiole',5))
  # Gently cupped swept petals, with a warm inner throat; not spheres.
  for k in range(5):
   angle=tau*k/5+.20*fi;d=Vector((cos(angle),sin(angle),0));side=Vector((-d.y,d.x,0));vs=[];fs=[]
   for j in range(6):
    t=j/5;c=pos+d*(.04+.22*t)+side*.045*sin(pi*t)
    width=.10*sin(pi*t)**.60+.008
    for s in [-1,0,1]:vs.append(tuple(c+side*s*width+Vector((0,0,.045+.06*t*t-.025*abs(s)))))
   for j in range(5):
    for k2 in range(2):aa=j*3+k2;fs.append((aa,aa+3,aa+4,aa+1))
   flowers.append(mesh(name+'_CuppedPetal',vs,fs,'Coral Petal' if coral and fi%2 else ('Peach Petal' if coral else 'Cream Petal')))
  flowers.append(ellipsoid(name+'_FlowerThroat',pos+Vector((0,0,.055)),(.055,.055,.032),'Flower Gold',10,5))
  # One tiny center gives small flowers a focal point.
  flowers.append(ellipsoid(name+'_FlowerEye',pos+Vector((0,0,.082)),(.017,.017,.012),'Flower Eye',8,4))
 join_objects(flowers,name+'_Flowers');return rt
flowering_bush('Shrub_Coral',True,41)
flowering_bush('Shrub_Cream',False,82)

def fern(name):
 rt=root(name);parts=[]
 for fi in range(7):
  a=fi*2.399;d=Vector((cos(a),sin(a),0));side=Vector((-d.y,d.x,0));L=.55+.18*sin(fi+1)
  def curve(t):return d*L*t+Vector((0,0,.10+.49*sin(pi*t*.72)-.12*t*t))
  parts.append(tube(name+'_Rachis',[curve(j/8) for j in range(9)],[.016*(1-j/10) for j in range(9)],'Leaf Vein',5))
  for j in range(7):
   t=.18+j*.104
   for sign in [-1,1]:parts+=blade(name+'_Pinna',curve(t),side*sign+d*.4,.22*(1-.5*t),.035,'Leaf Lime' if fi%3==0 else 'Leaf Jade',lift=.025,droop=.025,segments=4)
 join_objects(parts,name+'_PinnateLeaves');return rt
fern('Fern_A')

def grass(name):
 rt=root(name);parts=[];rng=random.Random(62)
 for j in range(11):
  a=j*2.399;L=rng.uniform(.30,.55);d=Vector((cos(a),sin(a),.32)).normalized();p=Vector((cos(a)*.08,sin(a)*.08,.01))
  parts+=blade(name+'_CurvedBlade',p,d,L,.025,'Leaf Lime' if j%3 else 'Leaf Emerald',lift=.27,droop=.05,segments=6,fold=.75)
 join_objects(parts,name+'_Blades');return rt
grass('Grass_A')

# Asset master is a clearly spaced studio collection. All export pivots are ground zero.
positions={'Palm_A':(-5.5,1.2,0),'Palm_B':(0,1.5,0),'Palm_C':(5.4,1.7,0),
 'Foliage_Monstera':(-5.1,-2.5,0),'Foliage_Banana':(-1.75,-2.4,0),
 'Shrub_Coral':(1.45,-2.6,0),'Shrub_Cream':(4.20,-2.4,0),'Fern_A':(6.0,-2.0,0),'Grass_A':(6.8,-2.3,0)}
filemap={'Palm_A':'palm_a.glb','Palm_B':'palm_b.glb','Palm_C':'palm_c.glb','Foliage_Monstera':'foliage_monstera.glb','Foliage_Banana':'foliage_banana.glb','Shrub_Coral':'shrub_coral.glb','Shrub_Cream':'shrub_cream.glb','Fern_A':'fern_a.glb','Grass_A':'grass_a.glb'}
stats={}
for rt in assets:
 bpy.ops.object.select_all(action='DESELECT');rt.select_set(True)
 for ob in rt.children_recursive:ob.select_set(True)
 bpy.context.view_layer.objects.active=rt
 bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,filemap[rt.name]),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
 tris=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in rt.children_recursive if ob.type=='MESH')
 vs=sum(len(ob.data.vertices) for ob in rt.children_recursive if ob.type=='MESH')
 coords=[ob.matrix_world @ v.co for ob in rt.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
 bounds={'min':[round(min(v[i] for v in coords),4) for i in range(3)],'max':[round(max(v[i] for v in coords),4) for i in range(3)]}
 stats[rt.name]={'file':filemap[rt.name],'vertices':vs,'triangles':tris,'mesh_objects':len([ob for ob in rt.children_recursive if ob.type=='MESH']),'origin':'ground center (0,0,0)','bounds_local':bounds,'studio_position':positions[rt.name]}
 rt.location=positions[rt.name]
# All assets together; no studio geometry in GLB.
bpy.ops.object.select_all(action='DESELECT')
for rt in assets:
 rt.select_set(True)
 for ob in rt.children_recursive:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'plants.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
with open(os.path.join(OUT,'plants_manifest.json'),'w') as f:json.dump({'version':3,'assets':stats,'triangle_total':sum(s['triangles'] for s in stats.values())},f,indent=2)

# Non-exported botanical studio.
curr=None
studio=bpy.data.collections.new('STUDIO_NotForExport');bpy.context.scene.collection.children.link(studio)
def to_studio(ob):
 for c in list(ob.users_collection):c.objects.unlink(ob)
 studio.objects.link(ob)
mesh('Studio floor',[(-200,-200,-.035),(200,-200,-.035),(200,200,-.035),(-200,200,-.035)],[(0,1,2,3)],'Studio Sand',False);to_studio(bpy.data.objects['Studio floor'])
bpy.ops.object.camera_add(location=(12,-24,14));cam=bpy.context.object;cam.name='BotanicalStudioCamera';target=Vector((0,0,3.1));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=20.0;bpy.context.scene.camera=cam;to_studio(cam)
for name,loc,energy,size,col in [('Key',(-6,-10,15),2500,9,(1,.88,.72)),('Fill',(7,-1,11),1100,8,(.76,.90,1)),('Rim',(-3,9,12),1900,7,(1,.96,.77))]:
 bpy.ops.object.light_add(type='AREA',location=loc);ob=bpy.context.object;ob.name='Studio '+name;ob.data.energy=energy;ob.data.shape='DISK';ob.data.size=size;ob.data.color=col;ob.rotation_euler=(Vector((0,0,2))-ob.location).to_track_quat('-Z','Y').to_euler();to_studio(ob)
sc=bpy.context.scene;sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.70,.76,.78,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.35
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=96;sc.cycles.use_denoising=False;sc.cycles.max_bounces=6;sc.cycles.diffuse_bounces=3;sc.cycles.glossy_bounces=3
sc.render.resolution_x=1280;sc.render.resolution_y=960;sc.render.resolution_percentage=100
sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.view_settings.exposure=0
sc.render.image_settings.file_format='PNG';sc.render.filepath=os.path.join(OUT,'plants_preview.png');sc.render.film_transparent=False
sc['rebuild']='v3, true pinnate palms, individually folded broadleaves, authored leaf sprays';sc['asset_manifest']='plants_manifest.json'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'plants.blend'))
print('PLANTS_STATS',json.dumps(stats),flush=True)
if '--no-render' not in sys.argv:
 if '--quick' in sys.argv:sc.render.resolution_percentage=60;sc.cycles.samples=24;sc.render.filepath=os.path.join(OUT,'plants_preview_quick.png')
 bpy.ops.render.render(write_still=True)
