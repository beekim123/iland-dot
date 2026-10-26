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

# TURTLE: broad continuous carapace, genuinely tapered ocean flippers and shaped neck.
rt=root('TurtleRoot')
loft('Turtle_Plastron',[(-.61,.06,.18,.03),(-.53,.28,.18,.09),(-.30,.46,.18,.13),(0,.49,.18,.13),(.35,.40,.18,.12),(.57,.20,.18,.07),(.62,.03,.18,.02)],'ivory')
loft('Turtle_SoftBody',[(-.60,.09,.26,.05),(-.48,.30,.25,.13),(-.22,.44,.25,.17),(.1,.46,.25,.17),(.39,.36,.24,.13),(.57,.12,.23,.05)],'seafoam')
# Elliptic continuous shell with low domed section. Rim and underside included in one shell mesh.
vs=[];fs=[];N=64
shellrings=[(q,.32+.43*sqrt(max(0,1-q*q))) for q in [.025,.12,.24,.36,.48,.60,.72,.82,.90,.95,.98,1.0]]+[(.985,.285),(.92,.27),(.05,.27)]
for q,z in shellrings:
 for j in range(N):a=2*pi*j/N;vs.append((.52*q*cos(a),.045+.655*q*sin(a),z))
for i in range(len(shellrings)-1):
 for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
fs.extend([tuple(reversed(range(N))),tuple((len(shellrings)-1)*N+j for j in range(N))])
mi=[0 if i//N<11 else 1 for i in range((len(shellrings)-1)*N)]+[0,1]
mesh('Turtle_ContinuousCarapace',vs,fs,['shell','shell_rim'],face_mats=mi)
def shellz(x,y):
 q=sqrt((x/.52)**2+((y-.045)/.655)**2);return .32+.43*sqrt(max(0,1-q*q))+.006
# Hex scute seam network; engraved-like low relief on one continuous shell rather than separate tiles.
for row,(cy,wx,hy) in enumerate([(-.33,.17,.17),(.02,.20,.175),(.37,.16,.17)]):
 pts=[(-wx,cy-hy*.45),(0,cy-hy),(wx,cy-hy*.45),(wx,cy+hy*.45),(0,cy+hy),(-wx,cy+hy*.45),(-wx,cy-hy*.45)]
 dense=[]
 for a,b in zip(pts,pts[1:]):
  for j in range(5):
   t=j/5;x=a[0]*(1-t)+b[0]*t;y=a[1]*(1-t)+b[1]*t;dense.append((x,y,shellz(x,y)-.003))
 dense.append(dense[0]);line('Turtle_CentralScute_%02d'%row,dense,'shell_seam',.0032)
 for s in [-1,1]:
  for yy in [cy-hy*.45,cy+hy*.45]:
   xx=s*wx;ox=s*.49*sqrt(max(.05,1-((yy-.045)/.65)**2));line('Turtle_ScutesRadial',[(xx,yy,shellz(xx,yy)),((xx+ox)*.5,yy+.018,shellz((xx+ox)*.5,yy+.018)),(ox,yy+.025,shellz(ox,yy+.025))],'shell_seam',.0032)
headp=empty('HeadPivot',(0,-.49,.29),rt)
head=loft('Turtle_HeadNeck',[(-.61,.018,.025,.025),(-.585,.105,.03,.085),(-.53,.20,.07,.145),(-.42,.245,.11,.18),(-.27,.235,.12,.19),(-.12,.18,.06,.14),(.03,.155,-.005,.11),(.20,.18,-.03,.10)],'mint',headp)
for s in [-1,1]:
 eye('Turtle_Eye_'+str(s),(s*.193,-.465,.17),(s*.62,-.79,.06),.062,headp)
 oval('Turtle_Nostril',(s*.069,-.592,.058),(.011,.006,.007),'shell',headp,normal=(s*.1,-1,0))
 line('Turtle_MouthCorner',[(s*.11,-.563,-.010),(s*.157,-.535,-.019),(s*.178,-.50,-.005)],'shell',.005,headp)
 # Whole limb grows from the shoulder and curves into a broad, thin tapered flipper.
 for front in [True,False]:
  yy=-.31 if front else .36;piv=empty(('Front' if front else 'Rear')+'FlipperPivot'+('L' if s<0 else 'R'),(s*.34,yy,.23),rt)
  if front:stations=[((0,0,0),.10,.065),((s*.11,-.06,-.045),.16,.07),((s*.27,-.16,-.10),.185,.05),((s*.43,-.29,-.16),.13,.028),((s*.53,-.40,-.17),.04,.012),((s*.55,-.43,-.16),.003,.003)]
  else:stations=[((0,0,0),.07,.05),((s*.13,.07,-.06),.115,.05),((s*.25,.17,-.13),.105,.035),((s*.30,.28,-.17),.045,.013),((s*.30,.32,-.17),.002,.002)]
  sweep('Turtle_'+('Foreflipper' if front else 'Hindflipper')+str(s),stations,'seafoam',piv,N=16)
  if front:line('Turtle_FlipperCrease',[(s*.09,-.03,.011),(s*.21,-.11,-.036),(s*.34,-.21,-.086)],'mint_lid',.004,piv)
tp=empty('TurtleTailPivot',(0,.54,.21),rt);sweep('Turtle_TaperedTail',[((0,0,0),.07,.05),((0,.12,-.025),.045,.035),((0,.23,-.035),.002,.002)],'seafoam',tp)

# CRAB: low sculpted carapace, tapering articulated legs and separated hooked pincers.
rt=root('CrabRoot')
loft('Crab_Carapace',[(-.235,.04,.24,.025),(-.21,.20,.25,.09),(-.13,.29,.26,.135),(0,.33,.245,.145),(.13,.29,.23,.12),(.21,.17,.21,.065),(.24,.025,.20,.012)],'coral')
loft('Crab_Underside',[(-.225,.035,.185,.018),(-.20,.20,.175,.05),(-.1,.29,.17,.06),(.1,.29,.17,.065),(.2,.13,.18,.025)],'coral_belly')
line('Crab_BrowRidge',[(-.23,-.18,.32),(-.12,-.205,.35),(0,-.21,.355),(.12,-.205,.35),(.23,-.18,.32)],'coral_light',.009)
for s in [-1,1]:
 eye_p=empty('EyeStalkPivot'+('L' if s<0 else 'R'),(s*.14,-.115,.32),rt)
 sweep('Crab_OrganicEyeStalk'+str(s),[((0,0,0),.055,.045),((s*.015,-.015,.065),.043,.037),((s*.025,-.02,.145),.036,.036),((s*.027,-.021,.17),.042,.035)],'coral_light',eye_p,N=16)
 eye('Crab_Eye_'+str(s),(s*.027,-.04,.185),(s*.18,-1,.04),.056,eye_p,lid='coral_light')
 for i,y in enumerate([-.09,-.015,.065,.135]):
  reach=[.49,.55,.56,.51][i];dy=[-.14,-.04,.08,.18][i];piv=empty('LegPivot'+('L' if s<0 else 'R')+str(i+1),(s*.26,y,.205),rt)
  sweep('Crab_WalkingLeg'+str(s)+'_'+str(i),[((0,0,0),.033,.035),((s*.07,dy*.3,.01),.035,.034),((s*(reach-.26)*.68,dy*.7,-.025),.032,.029),((s*(reach-.26)*.85,dy*.87,-.045),.024,.025),((s*(reach-.26),dy,-.16),.012,.015),((s*(reach-.26+.015),dy+.01,-.195),.0015,.0015)],'coral_light',piv,N=10)
 cp=empty('ClawPivot'+('L' if s<0 else 'R'),(s*.26,-.12,.24),rt)
 sweep('Crab_ClawArm'+str(s),[((0,0,0),.045,.045),((s*.06,-.085,.02),.05,.045),((s*.105,-.11,.075),.05,.045),((s*.13,-.18,.095),.045,.04)],'coral',cp,N=14)
 # Palm and stationary finger are continuous, then a smaller opposed moving finger leaves a real gap.
 sweep('Crab_ClawPalm'+str(s),[((s*.13,-.14,.095),.018,.025),((s*.15,-.21,.105),.095,.075),((s*.16,-.285,.105),.10,.078),((s*.195,-.345,.115),.055,.055),((s*.205,-.405,.13),.027,.032),((s*.17,-.445,.14),.001,.002)],'coral_light',cp,N=18)
 fp=empty('PincerPivot'+('L' if s<0 else 'R'),(s*.11,-.28,.11),cp)
 sweep('Crab_OpposedPincer'+str(s),[((0,0,0),.048,.05),((s*-.018,-.06,.015),.04,.04),((s*.005,-.12,.025),.025,.027),((s*.037,-.145,.031),.001,.001)],'claw_tip',fp,N=14)
line('Crab_Smile',[(-.065,-.222,.225),(0,-.242,.203),(.065,-.222,.225)],'mouth',.007)

# GULL: one continuous pear-shaped head / neck / horizontal body, folded layered flight wings.
rt=root('SeagullRoot')
loft('Gull_HeadNeckBody',[(-.49,.025,.69,.055),(-.465,.12,.70,.13),(-.405,.20,.70,.20),(-.30,.235,.65,.25),(-.19,.25,.53,.32),(-.04,.28,.43,.30),(.15,.26,.39,.255),(.33,.195,.395,.18),(.48,.11,.42,.085),(.61,.02,.45,.018)],'pearl',N=32)
for s in [-1,1]:
 eye('Gull_Eye_'+str(s),(s*.17,-.426,.735),(s*.70,-.73,.025),.047,lid='pearl')
 wp=empty('WingPivot'+('L' if s<0 else 'R'),(s*.22,-.18,.49),rt)
 sweep('Gull_SculptedFoldedWing'+str(s),[((0,0,0),.035,.055),((s*.032,.10,-.005),.055,.145),((s*.047,.26,-.028),.049,.15),((s*.025,.43,-.045),.032,.095),((s*-.025,.65,-.055),.005,.008)],'wing_light',wp,N=20)
 # Overlapping longitudinal primaries form a deliberate layered feather edge.
 for j in range(3):
  xx=s*(.038+j*.006);zz=-.015-j*.047;yy=.13+j*.035
  sweep('Gull_PrimaryFeather'+str(s)+'_'+str(j),[((xx,yy,zz),.013,.02),((xx+s*.019,yy+.14,zz),.021,.055),((xx+s*.015,yy+.30,zz-.005),.018,.043),((xx-s*.035,yy+.51-j*.035,zz+.012),.001,.002)],'wing' if j<2 else 'wing_dark',wp,N=12)
 lp=empty('LegPivot'+('L' if s<0 else 'R'),(s*.115,-.045,.21),rt)
 sweep('Gull_Leg'+str(s),[((0,0,0),.022,.022),((0,.008,-.065),.02,.02),((0,-.018,-.14),.018,.018)],'gold',lp,N=10)
 # A softly beveled real web-foot outline, not three sphere toes.
 foot=blade('Gull_WebbedFoot'+str(s),[(-.035,.055),(-.05,-.015),(-.085,-.11),(-.045,-.095),(-.005,-.14),(.025,-.10),(.07,-.115),(.055,-.02),(.03,.055)],.032,'gold_light',rt,sub=2);foot.location=(s*.115,-.06,.024)
 for ox in [-.028,.023]:line('Gull_ToeSeam',[(s*.115,-.055,.046),(s*.115+ox,-.115,.045),(s*.115+ox*1.4,-.155,.035)],'gold',.0035)
# Beak: long rounded wedge, with narrowing duck-like contour explicitly avoided.
loft('Gull_UpperBeak',[(-.745,.006,.637,.007),(-.70,.03,.656,.021),(-.60,.071,.67,.036),(-.51,.08,.672,.046),(-.47,.06,.67,.032)],'gold_light',N=16)
loft('Gull_LowerBeak',[(-.725,.004,.626,.004),(-.66,.033,.623,.014),(-.55,.068,.63,.025),(-.48,.058,.64,.023)],'gold',N=16)
for s in [-1,1]:line('Gull_BeakSmile'+str(s),[(s*.064,-.51,.649),(s*.058,-.60,.64),(s*.025,-.69,.637)],'mouth',.0035)
tp=empty('SeagullTailPivot',(0,.39,.42),rt)
for j in [-1,0,1]:sweep('Gull_TailFeather'+str(j),[((j*.044,0,0),.04,.025),((j*.062,.15,.025),.045,.026),((j*.073,.32,.035),.028,.018),((j*.075,.37,.04),.002,.002)],'wing' if j else 'wing_light',tp,N=12)

# REEF FISH: anatomical spindle with integrated body bands, shaped fin membranes and split fan tail.
rt=root('FishRoot')
fr=[(-.49,.014,0,.025),(-.465,.065,0,.09),(-.42,.12,.005,.16),(-.35,.158,.008,.215),(-.31,.17,.008,.23),(-.275,.18,.009,.244),(-.23,.185,.01,.25),(-.19,.184,.01,.25),(-.12,.18,.007,.24),(-.025,.16,0,.215),(.025,.145,0,.196),(.06,.13,0,.18),(.105,.113,0,.16),(.14,.095,0,.14),(.22,.065,0,.10),(.29,.04,0,.065),(.36,.025,0,.045),(.4,.022,0,.038)]
fm=[]
for i in range(len(fr)-1):
 y=(fr[i][0]+fr[i+1][0])/2
 band=(-.30<y<-.21 or .035<y<.12)
 for j in range(32):
  fm.append(1 if band else (2 if sin((j+.5)*2*pi/32)<-.45 else 0))
fm += [0,0]
loft('Fish_IntegratedSpindleBands',fr,['coral','ivory','coral_light'],N=32,face_mats=fm)
for s in [-1,1]:
 eye('Fish_Eye_'+str(s),(s*.127,-.382,.062),(s*.88,-.48,.03),.050,lid='coral_light')
 fp=empty('FinPivot'+('L' if s<0 else 'R'),(s*.17,-.15,-.045),rt)
 sweep('Fish_PectoralFin'+str(s),[((0,0,0),.02,.015),((s*.06,.05,-.02),.065,.012),((s*.15,.13,-.04),.085,.009),((s*.18,.20,-.025),.02,.004),((s*.15,.22,-.02),.001,.001)],'gold',fp,N=12)
line('Fish_Mouth',[(-.03,-.485,-.035),(0,-.495,-.05),(.03,-.485,-.035)],'mouth',.0045)
tp=empty('TailPivot',(0,.345,0),rt)
tail=blade('Fish_SplitFanTail',[(0,-.035),(.07,-.07),(.28,-.245),(.33,-.245),(.29,-.10),(.23,-.025),(.24,.025),(.32,.22),(.29,.24),(.065,.07),(0,.035)],.030,'gold',tp,axis='X',sub=2)
# Low relief radial ribs follow the fin geometry, not sticks beyond the silhouette.
for z in [-.16,-.08,.08,.16]:line('Fish_TailRay',[(.019,.045,0),(.021,.145,z*.48),(.016,.255,z)],'gold_light',.003,tp)
dp=empty('DorsalFinPivot',(0,-.22,.21),rt)
blade('Fish_DorsalRibbon',[(0,0),(.08,.10),(.20,.16),(.27,.14),(.43,-.05),(.35,-.09),(.18,-.035)],.016,'gold',dp,axis='X',sub=2)
ap=empty('AnalFinPivot',(0,-.01,-.19),rt)
blade('Fish_AnalRibbon',[(0,0),(.06,-.10),(.19,-.12),(.26,.09),(.13,.065)],.014,'gold',ap,axis='X',sub=2)

# Convert tiny curves to meshes for deterministic exports while preserving all action pivots.
bpy.context.view_layer.update()
for o in list(bpy.context.scene.objects):
 if o.type=='CURVE':
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
# Recalculate outward normals on every closed mesh, including all custom lofts.
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
# Normalize each land creature's feet to Z=0. All exported roots remain at identity.
report={}
for species,r in roots.items():
 obs=[r]+list(r.children_recursive);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 coords=[o.evaluated_get(dg).matrix_world@Vector(v) for o in obs if o.type=='MESH' for v in o.evaluated_get(dg).bound_box]
 if species!='FishRoot':
  floor=min(v.z for v in coords)
  for o in r.children:o.location.z-=floor
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();coords=[o.evaluated_get(dg).matrix_world@Vector(v) for o in obs if o.type=='MESH' for v in o.evaluated_get(dg).bound_box]
 dims=[max(v[k] for v in coords)-min(v[k] for v in coords) for k in range(3)]
 report[species]={'dimensions_m':dims,'root_identity':True,'mesh_objects':len([o for o in obs if o.type=='MESH']),'evaluated_vertices':sum(len(o.evaluated_get(dg).data.vertices) for o in obs if o.type=='MESH'),'pivots':[o.name for o in obs if o.type=='EMPTY'],'front':'-Y','up':'+Z'}
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=r
 bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,species.replace('Root','').lower()+'.glb'),use_selection=True,export_format='GLB',export_apply=True,export_yup=True)
with open(os.path.join(OUT,'animals_metrics.json'),'w') as f:json.dump(report,f,indent=2)
# Stage is kept in a clearly named separate collection; never included in species GLBs.
stage=bpy.data.collections.new('STUDIO_ONLY');bpy.context.scene.collection.children.link(stage)
def stageobj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
roots['TurtleRoot'].location=(-1.00,.62,0);roots['TurtleRoot'].rotation_euler.z=.17
roots['SeagullRoot'].location=(1.02,.62,0);roots['SeagullRoot'].rotation_euler.z=-.24
roots['CrabRoot'].location=(-.90,-.94,0);roots['CrabRoot'].rotation_euler.z=.10
roots['FishRoot'].location=(.93,-.88,.46);roots['FishRoot'].rotation_euler.z=-.85
mat('StudioSand',(.72,.79,.75),.83)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.018));o=bpy.context.object;o.name='StudioFloor';o.data.materials.append(M['StudioSand']);stageobj(o)
def area(n,loc,power,color,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=n;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.3))-o.location).to_track_quat('-Z','Y').to_euler();stageobj(o)
area('LargeSoftbox',(-3,-4,6),700,(1,.88,.72),5)
area('CoolFill',(4,-1,4),450,(.70,.86,1),5)
area('SoftRim',(0,4,5),850,(1,.91,.77),4)
bpy.ops.object.camera_add(location=(3.6,-6.7,4.9));cam=bpy.context.object;cam.name='Animals_StudioCamera';cam.rotation_euler=(Vector((0,-.05,.35))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.60;bpy.context.scene.camera=cam;stageobj(cam)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=48;sc.cycles.use_denoising=False;sc.cycles.max_bounces=6;sc.world.color=(.23,.23,.23)
sc.render.resolution_x=1280;sc.render.resolution_y=960;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.filepath=os.path.join(OUT,'animals_preview.png');sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast';sc.render.film_transparent=False;sc.view_settings.exposure=-.25
bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'animals.blend'))
if '--skip-render' not in sys.argv:bpy.ops.render.render(write_still=True)
print('V3_ANIMALS_COMPLETE',json.dumps(report))
