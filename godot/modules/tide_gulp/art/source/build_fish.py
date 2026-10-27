"""Original Tide Gulp watercolor fish meshes; rebuild with Blender 4.3+.
No downloaded geometry/textures. Parametric lofts are actual closed, weighted 3D
Blender meshes (not raster art). Body length is one unit; fins excluded.
"""
import bpy, math, os, sys, json
from mathutils import Vector
from math import sin, cos, pi
BASE=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(BASE,'fish'); os.makedirs(OUT,exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
SPECS={
 'moonfish':dict(height=.235,depth=.14,head=.88,tail=.29,color=(.91,.66,.36,1),belly=(.98,.91,.75,1),fin=(.61,.39,.56,1),back=(.85,.48,.35,1),eye=.07),
 'silver':dict(height=.115,depth=.085,head=.65,tail=.17,color=(.47,.70,.72,1),belly=(.88,.91,.82,1),fin=(.40,.55,.67,1),back=(.35,.56,.61,1),eye=.047),
 'fan':dict(height=.20,depth=.10,head=.85,tail=.35,color=(.83,.55,.50,1),belly=(.98,.85,.68,1),fin=(.77,.39,.46,1),back=(.78,.44,.42,1),eye=.058),
 'leaf':dict(height=.34,depth=.08,head=.78,tail=.20,color=(.75,.76,.41,1),belly=(.94,.90,.66,1),fin=(.49,.64,.50,1),back=(.50,.63,.45,1),eye=.064),
 'ribbon':dict(height=.105,depth=.070,head=.66,tail=.22,color=(.61,.52,.73,1),belly=(.86,.83,.88,1),fin=(.59,.45,.70,1),back=(.43,.43,.62,1),eye=.048),
 'lantern':dict(height=.28,depth=.19,head=1.07,tail=.20,color=(.64,.70,.70,1),belly=(.94,.85,.59,1),fin=(.60,.57,.70,1),back=(.46,.60,.63,1),eye=.072),
 'parrot':dict(height=.245,depth=.16,head=1.10,tail=.26,color=(.42,.69,.66,1),belly=(.91,.82,.60,1),fin=(.54,.61,.74,1),back=(.31,.56,.58,1),eye=.065),
 'sailjaw':dict(height=.155,depth=.10,head=.70,tail=.24,color=(.41,.54,.65,1),belly=(.74,.82,.80,1),fin=(.47,.39,.58,1),back=(.28,.40,.52,1),eye=.048),
 'whalejaw':dict(height=.32,depth=.22,head=1.22,tail=.21,color=(.49,.44,.58,1),belly=(.80,.74,.72,1),fin=(.42,.39,.54,1),back=(.35,.33,.48,1),eye=.055),
}

def mix(a,b,t): return tuple(a[k]*(1-t)+b[k]*t for k in range(4))

def make_one(name,stage=0):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 cfg=SPECS[name]; h=cfg['height']; d=cfg['depth']; V=[];F=[];C=[];W=[]
 def vertex(x,y,z,col,w):
  V.append((x,-z,y));C.append(col);W.append(w); return len(V)-1
 def tri(a,b,c):F.append((a,b,c))
 def weights(x):
  # Smoothly blend two contiguous body bones. Actual tail chain, not rigid parts.
  anchors=[(.30,'head'),(.03,'spine_a'),(-.20,'spine_b'),(-.40,'spine_c'),(-.56,'tail')]
  if x>=anchors[0][0]:return {'head':1.0}
  if x<=anchors[-1][0]:return {'tail':1.0}
  for i in range(len(anchors)-1):
   xa,ba=anchors[i];xb,bb=anchors[i+1]
   if xb<=x<=xa:
    t=(xa-x)/(xa-xb);return {ba:1-t,bb:t}
 def uvball(center,scale,col,group='head',seg=12,rings=8):
  start=len(V)
  for j in range(rings+1):
   ph=pi*j/rings
   for k in range(seg):
    a=2*pi*k/seg; vertex(center[0]+scale[0]*sin(ph)*cos(a),center[1]+scale[1]*cos(ph),center[2]+scale[2]*sin(ph)*sin(a),col,{group:1})
  for j in range(rings):
   for k in range(seg):
    a=start+j*seg+k;b=start+j*seg+(k+1)%seg;c=b+seg;dd=a+seg
    tri(a,b,c);tri(a,c,dd)
 def fin(points,col,group=None):
  # A tapered fin ribbon with a physical folded membrane, both sides.
  # points: centerline x,y,z, halfwidth measured on x axis.
  rows=[]
  for i,(x,y,z,width) in enumerate(points):
   row=[]
   for j in range(5):
    t=j/4; xx=x+(t-.5)*width*2
    zz=z+sin(t*pi)*.025*sin(i*.9)
    pigment=mix(col,cfg['belly'],.10+.12*sin(j*1.8+i))
    row.append(vertex(xx,y,zz,pigment,weights(xx) if group is None else {group:1}))
   rows.append(row)
  for i in range(len(rows)-1):
   for j in range(4):
    a=rows[i][j];b=rows[i][j+1];c=rows[i+1][j+1];dd=rows[i+1][j]
    tri(a,b,c);tri(a,c,dd)
 def stroke(points,radius,col,group='head'):
  # Thin closed brush-like tubes for smile/gill marks.
  starts=[]
  for n,p in enumerate(points):
   tangent=Vector(points[min(n+1,len(points)-1)])-Vector(points[max(0,n-1)])
   tangent.normalize(); b=tangent.cross(Vector((0,0,1)))
   if b.length<.1:b=Vector((0,1,0))
   b.normalize();cc=tangent.cross(b).normalized();rr=radius*(.75+.25*sin(pi*n/(len(points)-1)))
   ids=[]
   for k in range(6):
    q=Vector(p)+rr*(cos(2*pi*k/6)*b+sin(2*pi*k/6)*cc);ids.append(vertex(*q,col,{group:1}))
   starts.append(ids)
  for i in range(len(starts)-1):
   for k in range(6):
    a=starts[i][k];b=starts[i][(k+1)%6];c=starts[i+1][(k+1)%6];dd=starts[i+1][k];tri(a,b,c);tri(a,c,dd)
 # Original asymmetrical longitudinal silhouette. Snout ends exactly x .5.
 profile=[(-.5,.14),(-.44,.25),(-.37,.48),(-.29,.70),(-.19,.87),(-.08,.98),(.04,1),(.15,.97),(.25,.86),(.34,.69),(.41,.48),(.47,.25),(.5,.025)]
 seg=24
 for j,(x,r) in enumerate(profile):
  headfactor=1+(cfg['head']-1)*max(0,(x+.1)/.6)
  for k in range(seg):
   a=2*pi*k/seg; y=h*r*sin(a)*headfactor;z=d*r*cos(a)*headfactor
   if name=='leaf':y*=1+.1*abs(sin(a))
   if name=='whalejaw':y-=.025*max(0,x+.2)
   underside=max(0,min(1,(.40-sin(a))/.90))
   col=mix(cfg['color'],cfg['belly'],underside*.83)
   col=mix(col,cfg['back'],max(0,sin(a)-.05)*.55)
   # Soft, deliberately irregular pigment patches, no image texture.
   pigment=.028*(sin(j*1.72+k*.51)+sin(j*.65-k*.71))
   col=tuple(max(.02,min(1,c+pigment)) for c in col[:3])+(1,)
   if name=='leaf':col=mix(col,cfg['back'],.28*(.5+.5*sin(x*28)))
   if name=='parrot':col=mix(col,(.73,.53,.59,1),max(0,1-abs(x-.18)*12)*.45)
   if name=='ribbon':col=mix(col,(.95,.73,.58,1),max(0,1-abs(sin(a))/.30)*.65)
   vertex(x,y,z,col,weights(x))
 for j in range(len(profile)-1):
  for k in range(seg):
   a=j*seg+k;b=j*seg+(k+1)%seg;c=b+seg;dd=a+seg;tri(a,c,b);tri(a,dd,c)
 for row in [0,len(profile)-1]:
  center=vertex(profile[row][0],0,0,cfg['color'],weights(profile[row][0]))
  for k in range(seg):tri(center,row*seg+(k+1)%seg,row*seg+k)
 # Broad forked caudal membrane, weighted to the final two bones.
 tail_h=cfg['tail']*(1+.14*stage if name=='moonfish' else 1)
 caudal=[(-.49,.0,0,.035),(-.62,.0,0,.075),(-.76,.0,0,.12)]
 # Tail fan formed with curved radial outline and a true center surface.
 start=len(V); tail_n=14
 for j in range(4):
  t=j/3
  for k in range(tail_n+1):
   a=-pi*.49+pi*.98*k/tail_n
   x=-.49-t*(.22+.085*abs(sin(a)))
   y=tail_h*sin(a)*t
   z=.018*cos(a*2)*t
   col=mix(cfg['fin'],cfg['belly'],.30*(1-t)+.12*sin(k*1.8)**2)
   vertex(x,y,z,col,weights(x))
 for j in range(3):
  for k in range(tail_n):
   a=start+j*(tail_n+1)+k;b=a+1;c=b+tail_n+1;dd=a+tail_n+1;tri(a,b,c);tri(a,c,dd)
 # Dorsal and ventral fins; player growth reveals progressively longer fins.
 dorsal=.12
 if name=='leaf':dorsal=.15
 if name=='sailjaw':dorsal=.27
 if name=='ribbon':dorsal=.16
 if name=='moonfish':dorsal=.10+.055*stage
 # Dorsal membrane is genuinely welded to the body's existing top-row
 # vertices. Each longitudinal station shares the exact body weights. It
 # cannot float away when the head/spine/tail are posed differently.
 def attached_fin(body_rows, upper, extension, amplitudes, color):
  theta=seg//4 if upper else seg*3//4
  root=[row*seg+theta for row in body_rows]
  strips=[root]
  for level in [0.45,1.0]:
   row=[]
   for i,j in enumerate(body_rows):
    x=profile[j][0]; base=V[root[i]]
    yy=base[2]+(1 if upper else -1)*extension*amplitudes[i]*level
    zz=.012*sin(i*.8)*level
    row.append(vertex(x,yy,zz,mix(color,cfg['belly'],.12*(1-level)),weights(x)))
   strips.append(row)
  for r in range(2):
   for i in range(len(root)-1):
    a=strips[r][i];b=strips[r][i+1];c=strips[r+1][i+1];dd=strips[r+1][i]
    tri(a,b,c);tri(a,c,dd)
 attached_fin([2,3,4,5,6,7,8],True,dorsal,[.0,.45,1.0,.90,.58,.25,.0],cfg['fin'])
 attached_fin([3,4,5,6,7],False,.105+(.025*stage if name=='moonfish' else 0),[.0,.85,1.0,.55,.0],mix(cfg['fin'],cfg['belly'],.2))
 # Paired pectoral fins, each its own articulated bone.
 for side in [-1,1]:
  grp='pectoral_l' if side>0 else 'pectoral_r'
  fin([(.16,-h*.08,side*d*.81,.055),(.02,-h*.35,side*(d+.09),.10),(-.09,-h*.56,side*(d+.11),.025)],mix(cfg['fin'],cfg['belly'],.30),grp)
 # Mature moonfish's distinctive long crescent tail streamers.
 if name=='moonfish' and stage>=1:
  for side in [-1,1]:
   fin([(-.66,side*tail_h*.70,0,.06),(-.82,side*tail_h*1.07,0,.055),(-.99,side*tail_h*1.18,.01,.012)],cfg['fin'],'tail')
 if name=='moonfish' and stage>=2:
  for side in [-1,1]:
   uvball((.04,side*h*.53,side*d*.62),(.018,.018,.013),(.98,.89,.60,1),'spine_a',8,5)
 # Warm cream eyes on BOTH visible sides, not billboards and not one-sided.
 eye=cfg['eye'];ex=.30 if name!='whalejaw' else .27;ey=h*.34;ez=d*.79
 for side in [-1,1]:
  uvball((ex,ey,side*ez),(eye*.92,eye,eye*.33),(.98,.94,.83,1))
  uvball((ex+eye*.18,ey+eye*.025,side*(ez+eye*.285)),(eye*.53,eye*.65,eye*.20),(.18,.20,.28,1))
  uvball((ex+eye*.30,ey+eye*.32,side*(ez+eye*.445)),(eye*.16,eye*.20,eye*.09),(.99,.97,.88,1),seg=8,rings=6)
  # Watercolor cheek and single curved gill crease.
  uvball((ex-.045,ey-eye*1.0,side*d*.90),(eye*.44,eye*.22,.007),mix(cfg['back'],cfg['belly'],.28),seg=10,rings=6)
  stroke([(.16,h*.43,side*d*.83),(.12,h*.20,side*d*.96),(.115,-h*.1,side*d*.98),(.15,-h*.35,side*d*.90)],.0055,mix(cfg['back'],(.25,.23,.32,1),.25))
 # Visible lower jaw, pivoted below eye; mouth cavity is dark, no teeth/gore.
 jawscale=.105 if name not in ['whalejaw','sailjaw'] else (.185 if name=='whalejaw' else .13)
 uvball((.39,-h*.15,0),(.116,jawscale*.22,d*.52),(.30,.25,.33,1),'head',12,6)
 uvball((.393,-h*.24,0),(.111,jawscale*.26,d*.54),cfg['belly'],'jaw',12,6)
 # Rounded little nose for parrot, safer expression than teeth.
 if name=='parrot':uvball((.47,.005,0),(.049,.045,.066),(.92,.76,.54,1),'head',12,6)
 # Build one mesh, one pigment material, with shared armature deformation.
 mesh=bpy.data.meshes.new(name+'_mesh');mesh.from_pydata(V,[],F);mesh.validate(verbose=True);mesh.update()
 obj=bpy.data.objects.new(name+'_painted_skin',mesh);bpy.context.collection.objects.link(obj)
 colattr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
 for i,c in enumerate(C):colattr.data[i].color=c
 mat=bpy.data.materials.new('watercolor_vertex_pigment');mat.use_nodes=True
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=1.0
 bsdf.inputs['Specular IOR Level'].default_value=0.0
 vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
 obj.data.materials.append(mat)
 for p in mesh.polygons:p.use_smooth=True
 arm=bpy.data.armatures.new(name+'_skeleton');rig=bpy.data.objects.new('FishRig',arm);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);obj.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
 bones=[('head',(.30,0,0),(.08,0,0),None),('spine_a',(.08,0,0),(-.16,0,0),'head'),('spine_b',(-.16,0,0),(-.35,0,0),'spine_a'),('spine_c',(-.35,0,0),(-.50,0,0),'spine_b'),('tail',(-.50,0,0),(-.78,0,0),'spine_c'),('jaw',(.30,0,-h*.12),(.48,0,-h*.12),'head'),('pectoral_l',(.15,-d*.7,0),(-.08,-d*1.6,-.09),'head'),('pectoral_r',(.15,d*.7,0),(-.08,d*1.6,-.09),'head')]
 for n,a,b,p in bones:
  bone=arm.edit_bones.new(n);bone.head=a;bone.tail=b
  if p:bone.parent=arm.edit_bones[p]
 bpy.ops.object.mode_set(mode='OBJECT')
 groups={n:obj.vertex_groups.new(name=n) for n,_,_,_ in bones}
 for i,ws in enumerate(W):
  for n,w in ws.items():
   if w>1e-5:groups[n].add([i],w,'REPLACE')
 modifier=obj.modifiers.new('Continuous_body_skin','ARMATURE');modifier.object=rig;obj.parent=rig
 bpy.context.view_layer.objects.active=obj;obj.select_set(True);rig.select_set(True)
 file_id=name+('_'+str(stage) if name=='moonfish' else '')
 bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,file_id+'.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_animations=False,export_skins=True,export_attributes=False)
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE,'source',file_id+'.blend'))
 return dict(id=file_id,vertices=len(V),triangles=len(F),bones=8,materials=1,body_length=1.0)

ids=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if not ids:ids=['moonfish_0','moonfish_1','moonfish_2']+[n for n in SPECS if n!='moonfish']
report=[]
for sid in ids:
 name,stage=(sid.rsplit('_',1)[0],int(sid.rsplit('_',1)[1])) if sid.startswith('moonfish_') else (sid,0)
 report.append(make_one(name,stage))
with open(os.path.join(BASE,'source','build_report.json'),'w') as f:json.dump(report,f,indent=2)
print('TIDE_FISH_BUILD_OK',json.dumps(report))
