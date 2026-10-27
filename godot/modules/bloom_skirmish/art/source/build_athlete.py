"""Original Bloom athlete modeling source. Blender 4.3+, no external models/textures.
Run: blender -b --python art/source/build_athlete.py
Custom sculpted head, continuous layered hair, lofted tailored clothing and sneaker
surfaces. Rigid articulated hierarchy deliberately matches the Godot factory API.
"""
import bpy, math, os
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def xyz(p): return (p[0],-p[2],p[1])
def v(p): return Vector(p)
def srgb(x): return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4

def material(name,hexcolor,rough=.65,metal=0,alpha=1):
    m=bpy.data.materials.new(name);m.use_nodes=True
    rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    color=tuple(srgb(x) for x in rgb)+(alpha,)
    m.diffuse_color=color
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    bs.inputs['Alpha'].default_value=alpha
    if alpha<1: m.surface_render_method='DITHERED';m.use_transparency_overlap=False
    return m

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=xyz(pos)
    if parent:o.parent=parent
    return o

def mesh(name,verts,faces,mat,parent,smooth=True,sub=0,bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(p) for p in verts],[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
    for p in me.polygons:p.use_smooth=smooth
    if sub:
        mod=o.modifiers.new('Authored surface smoothing','SUBSURF');mod.levels=sub;mod.render_levels=sub
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=3
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    # Consistent outward mesh normals even for bespoke section winding.
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return o

def ellipsoid(name,center,scale,mat,parent,segments=28,rings=18):
    verts=[];faces=[]
    for i in range(rings+1):
        a=math.pi*i/rings
        for j in range(segments):
            b=2*math.pi*j/segments
            verts.append((center[0]+math.sin(a)*math.cos(b)*scale[0],center[1]+math.cos(a)*scale[1],center[2]+math.sin(a)*math.sin(b)*scale[2]))
    for i in range(rings):
        for j in range(segments):faces.append((i*segments+j,i*segments+(j+1)%segments,(i+1)*segments+(j+1)%segments,(i+1)*segments+j))
    return mesh(name,verts,faces,mat,parent)

def loft(name,sections,mat,parent,sides=24,sub=1,square=1.0):
    # y, halfwidth, halfdepth, fore/aft offset (optional xoffset)
    verts=[];faces=[]
    for ring in sections:
        y,rx,rz,z=ring[:4];x0=ring[4] if len(ring)>4 else 0
        for j in range(sides):
            a=math.tau*j/sides;c=math.cos(a);s=math.sin(a)
            verts.append((x0+math.copysign(abs(c)**square,c)*rx,y,z+math.copysign(abs(s)**square,s)*rz))
    for i in range(len(sections)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(sections)-1)*sides+j for j in range(sides)))
    return mesh(name,verts,faces,mat,parent,sub=sub)

def box(name,center,size,mat,parent,bevel=.015):
    x,y,z=center;w,h,d=[q/2 for q in size]
    verts=[(x+a*w,y+b*h,z+c*d) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat,parent,bevel=bevel)

def cylinder(name,center,radius,depth,mat,parent,axis='y',sides=32,cap=True):
    verts=[];faces=[]
    for sign in [-1,1]:
        for j in range(sides):
            a=math.tau*j/sides
            p=(radius*math.cos(a),sign*depth/2,radius*math.sin(a))
            if axis=='z':p=(p[0],p[2],p[1])
            verts.append(tuple(center[k]+p[k] for k in range(3)))
    for j in range(sides):faces.append((j,(j+1)%sides,(j+1)%sides+sides,j+sides))
    if cap:faces.extend([tuple(reversed(range(sides))),tuple(sides+j for j in range(sides))])
    return mesh(name,verts,faces,mat,parent,bevel=.006 if cap else 0)

def annulus_z(name,center,outer,inner,depth,mat,parent,sides=40):
    verts=[];faces=[]
    for radius,zoff in [(outer,-depth/2),(outer,depth/2),(inner,depth/2),(inner,-depth/2)]:
        for i in range(sides):
            a=math.tau*i/sides;verts.append((center[0]+radius*math.cos(a),center[1]+radius*math.sin(a),center[2]+zoff))
    for ring in range(4):
        nxt=(ring+1)%4
        for i in range(sides):faces.append((ring*sides+i,ring*sides+(i+1)%sides,nxt*sides+(i+1)%sides,nxt*sides+i))
    return mesh(name,verts,faces,mat,parent)


def curve(name,points,radius,mat,parent):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=16;cu.bevel_depth=radius;cu.bevel_resolution=3
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for bp,p in zip(sp.bezier_points,points):bp.co=xyz(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);ob.parent=parent;cu.materials.append(mat)
    return ob

def lock(name,points,width,thick,mat,parent):
    # Swept soft tapered hair tuft. Broad root, layered middle, small rounded tip.
    p0,p1,p2=[v(p) for p in points];verts=[];faces=[];steps=9;sides=10
    for i in range(steps+1):
        t=i/steps;p=(1-t)**2*p0+2*(1-t)*t*p1+t*t*p2
        tangent=(2*(1-t)*(p1-p0)+2*t*(p2-p1)).normalized()
        outward=Vector((p.x,p.y+.13,p.z)).normalized()
        across=tangent.cross(outward).normalized()
        if across.length<.1:across=Vector((1,0,0))
        normal=across.cross(tangent).normalized()
        taper=(.55+.55*math.sin(math.pi*t))*(1-t)**.50+.012
        for j in range(sides):
            a=math.tau*j/sides;q=p+across*math.cos(a)*width*taper+normal*math.sin(a)*thick*taper
            verts.append(tuple(q))
    for i in range(steps):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces += [tuple(reversed(range(sides))),tuple(steps*sides+j for j in range(sides))]
    return mesh(name,verts,faces,mat,parent,sub=1)

def head_surface(parent,skin,hair):
    verts=[];faces=[];lat=28;lon=48
    for i in range(lat+1):
        a=math.pi*i/lat;y=.245*math.cos(a)
        chin=1-.30*max(0,(-y-.035)/.21)
        for j in range(lon):
            b=math.tau*j/lon;x=.235*math.sin(a)*math.cos(b)*chin;z=.193*math.sin(a)*math.sin(b)
            if z<0:
                nose=.015*math.exp(-((x/.055)**2+((y+.04)/.075)**2))
                cheeks=.010*(math.exp(-(((x-.12)/.07)**2+((y+.065)/.065)**2))+math.exp(-(((x+.12)/.07)**2+((y+.065)/.065)**2)))
                z-=nose+cheeks
            verts.append((x,y,z))
    for i in range(lat):
        for j in range(lon):faces.append((i*lon+j,i*lon+(j+1)%lon,(i+1)*lon+(j+1)%lon,(i+1)*lon+j))
    mesh('Sculpted face and tapered jaw',verts,faces,skin,parent,sub=1)
    # Continuous scalp and nape cover: never exposed scalp between the layered locks.
    hv=[(x*1.065,y+.025,z*1.085+.008) for x,y,z in verts]
    hf=[]
    for face in faces:
        x=sum(hv[n][0] for n in face)/4;y=sum(hv[n][1] for n in face)/4;z=sum(hv[n][2] for n in face)/4
        if y>.105 or z>-.008 or (abs(x)>.196 and y>-.09):hf.append(face)
    mesh('Continuous silver hair cap and nape',hv,hf,hair,parent,sub=1)

def build(team):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    blue='2F62FF' if team==0 else 'FF8A1F'
    mats={
      'skin':material('Warm skin','F1C5A5',.66),'skin_shadow':material('Ear and nose warmth','E7B28E',.7),
      'hair':material('Silver white hair','E7ECEB',.46),'hair_low':material('Silver nape undertone','C9D4D8',.58),
      'white':material('Technical woven white','DCE2E3',.86),'cloth':material('Graphite technical fabric','293440',.9),
      'rubber':material('Dark soft gloves and soles','17232F',.86),'metal':material('Brushed fittings','71828E',.34,.55),
      'team':material('Team lacquer',blue,.30,.12),'fluid':material('Saturated nectar core',blue,.12,.05),
      'glass':material('Clear frosted polycarbonate','D5F1FA',.14,0,.18),
      'eye_white':material('Eye sclera','F7F7F1',.33),'iris':material('Iris grey blue','426577',.28),
      'pupil':material('Pupil and lashes','17232D',.3),'mouth':material('Soft mouth line','916153',.7)
    }
    r=empty('AthleteRoot')
    body=empty('Body',(0,.80,0),r)
    torso=loft('Tailored short jacket',[(-.23,.165,.103,0),(-.215,.178,.115,0),(-.15,.168,.108,0),(-.05,.18,.116,0),(.10,.218,.122,0),(.17,.235,.112,0),(.205,.17,.10,0),(.23,.10,.088,0)],mats['cloth'],body,sides=32,sub=2,square=.85)
    # A single continuous shoulder yoke rather than two board-like front panels.
    loft('Continuous white shoulder yoke',[(.09,.219,.125,0),(.115,.229,.128,0),(.17,.239,.117,0),(.205,.174,.105,0),(.22,.12,.095,0)],mats['white'],body,sides=32,sub=1,square=.86)
    for side in [-1,1]:
        curve('Angled fitted side piping',[(side*.19,.10,-.08),(side*.174,-.04,-.113),(side*.15,-.16,-.10)],.009,mats['team'],body)
        curve('Soft shoulder harness',[(side*.12,.21,.03),(side*.145,.14,.14),(side*.13,-.15,.15)],.022,mats['rubber'],body)
        curve('Jacket side seam',[(side*.215,.06,.015),(side*.18,-.08,.015),(side*.175,-.20,.01)],.006,mats['white'],body)
    curve('Front zipper',[(0,.19,-.115),(0,.03,-.126),(0,-.19,-.116)],.007,mats['metal'],body)
    box('Zipper pull',(.014,.11,-.135),(.025,.045,.014),mats['metal'],body,.005)
    loft('Soft lower jacket hem',[(-.235,.17,.109,0),(-.21,.181,.118,0)],mats['rubber'],body,sides=24,sub=1,square=.8)
    cylinder('Neck',(0,.239,0),.075,.10,mats['skin'],body)
    curve('Raised collar',[(-.086,.22,-.018),(-.08,.25,.06),(0,.265,.085),(.08,.25,.06),(.086,.22,-.018)],.022,mats['cloth'],body)
    # Compact transparent reservoir with a real air gap and distinct level surface.
    box('Tank support',(0,.035,.174),(.27,.37,.06),mats['rubber'],body,.024)
    cylinder('Nectar inner core',(0,-.006,.255),.122,.29,mats['fluid'],body)
    cylinder('Visible liquid meniscus',(0,.143,.255),.124,.010,mats['team'],body)
    cylinder('Transparent tank shell',(0,.046,.255),.145,.42,mats['glass'],body,cap=False)
    for y in [-.168,.26]:
        cylinder('Reservoir end cap',(0,y,.255),.158,.065,mats['rubber'],body)
        cylinder('Reservoir collar',(0,y+.025,.255),.159,.016,mats['metal'],body)
    for i in range(4):box('Liquid gauge mark',(.073,-.06+i*.045,.384),(.038,.006,.008),mats['white'],body,.002)
    curve('Tank glass highlight',[(-.075,-.09,.378),(-.086,.03,.38),(-.075,.16,.378)],.006,mats['white'],body)
    curve('Flexible liquid feed',[(.10,-.15,.27),(.24,-.20,.22),(.315,-.19,.05),(.31,-.18,-.20)],.021,mats['rubber'],body)
    head=empty('Head',(0,1.235,-.025),r)
    head_surface(head,mats['skin'],mats['hair_low'])
    for side in [-1,1]:
        ellipsoid('Ear',(side*.222,-.025,.012),(.038,.065,.030),mats['skin_shadow'],head,20,12)
        x=side*.090
        ellipsoid('Luminous eye white',(x,.012,-.181),(.059,.068,.022),mats['eye_white'],head)
        ellipsoid('Iris',(x+.004,.011,-.203),(.029,.046,.009),mats['iris'],head,24,14)
        ellipsoid('Pupil',(x+.004,.009,-.211),(.018,.034,.007),mats['pupil'],head,20,12)
        ellipsoid('Eye catchlight',(x-.006,.031,-.218),(.011,.013,.005),mats['eye_white'],head,16,10)
        curve('Upper expressive eyelid',[(x-.052,.034,-.199),(x,.074,-.194),(x+.049,.038,-.193)],.006,mats['pupil'],head)
        curve('Expressive eyebrow',[(x-.045,.097,-.174),(x,.11+(.007 if side>0 else 0),-.18),(x+.041,.095,-.174)],.008,mats['hair_low'],head)
    ellipsoid('Nose',(0,-.050,-.206),(.022,.025,.022),mats['skin_shadow'],head,20,14)
    curve('Quiet confident smile',[(-.040,-.128,-.174),(0,-.139,-.177),(.036,-.126,-.174)],.006,mats['mouth'],head)
    # An asymmetric side part and flattened overlapping locks, not a ring of
    # equal cylindrical noodles. The continuous cap underneath remains intact.
    for j in range(9):
        a=math.tau*j/9+.23
        start=(-.055+math.cos(a)*.045,.263,math.sin(a)*.05+.025)
        mid=(math.cos(a)*.19-.018,.225,math.sin(a)*.18+.022)
        end=(math.cos(a)*.230,.095 if math.sin(a)<0 else .005,math.sin(a)*.221+.020)
        lock('Directional crown layer',[start,mid,end],.064+.009*(j%3),.012,mats['hair'],head)
    tip_heights=[.020,.054,.086,.060,.039]
    for i in range(5):
        x=-.185+i*.080
        lock('Side swept asymmetric fringe',[(x*.72-.02,.235,-.105),(x+.032,.164,-.211),(x+.040,tip_heights[i],-.230)],.064-.004*i,.012,mats['hair'],head)
    for side in [-1,1]:
        for j in range(2):
            lock('Short layered temple lock',[(side*.17,.175,.023+j*.064),(side*.25,.035,.052+j*.045),(side*.231,-.070+j*.033,.053+j*.065)],.067-j*.012,.013,mats['hair'],head)
    for i in range(7):
        x=-.185+i*.061
        tip_y=[-.092,-.125,-.080,-.118,-.088,-.111,-.074][i]
        lock('Slanted short nape layer',[(x-.035,.185,.165),(x+.018,.075,.237),(x+.027,tip_y,.208-.016*(i%3))],.053+.009*(i%3),.011,mats['hair'] if i%3 else mats['hair_low'],head)
    # Close-fitting sporting temple guards; never horns, antlers or hat petals.
    curve('Forehead grip strap',[(-.211,.106,-.085),(-.15,.117,-.208),(0,.135,-.238),(.15,.117,-.208),(.211,.106,-.085)],.018,mats['rubber'],head)
    for side in [-1,1]:
        lock('Swept flush temple guard',[(side*.220,.10,-.085),(side*.242,.105,.025),(side*.221,.073,.115)],.040,.017,mats['team'],head)
        box('Temple fastener',(side*.215,.104,-.091),(.027,.032,.022),mats['metal'],head,.007)
    # Arm hierarchy, curved tapered sleeves and glove volumes.
    for side in [-1,1]:
        arm=empty('ArmL' if side<0 else 'ArmR',(side*.255,.91,-.015),r)
        loft('Shaped short sleeve',[(.045,.063,.060,0),(.015,.095,.082,0),(-.08,.089,.078,0),(-.155,.068,.067,0),(-.17,.068,.067,0)],mats['white'],arm,sides=24,sub=2)
        loft('Sleeve cuff',[(-.17,.070,.069,0),(-.145,.074,.071,0)],mats['cloth'],arm,sides=24,sub=1)
        curve('Sleeve team stripe',[(-.050,.01,-.079),(0,-.02,-.085),(.054,-.065,-.075)],.012,mats['team'],arm)
        elbow=empty('Forearm',(0,-.17,0),arm)
        loft('Natural tapered forearm',[(.018,.063,.060,0),(-.03,.064,.062,0),(-.12,.051,.051,-.007),(-.17,.045,.045,-.014)],mats['skin'],elbow,sides=24,sub=2)
        loft('Wrist guard',[(-.17,.057,.055,-.014),(-.125,.057,.055,-.011)],mats['rubber'],elbow,sides=24,sub=1)
        ellipsoid('Sculpted glove palm',(0,-.204,-.018),(.062,.068,.052),mats['rubber'],elbow)
        ellipsoid('Glove thumb',(-side*.046,-.192,-.047),(.026,.040,.025),mats['rubber'],elbow,20,12)
        curve('Glove knuckle seam',[(-.040,-.195,-.059),(0,-.203,-.070),(.040,-.195,-.059)],.006,mats['team'],elbow)
        # Independent shorts legs with a real stance, then exposed knee/calf and sneakers.
        leg=empty('LegL' if side<0 else 'LegR',(side*.145,.57,.015),r)
        loft('Athletic tailored shorts leg',[(.015,.103,.096,0),(-.025,.108,.100,0),(-.12,.096,.085,.005),(-.20,.083,.078,.006),(-.215,.084,.078,.006)],mats['cloth'],leg,sides=24,sub=2,square=.9)
        curve('Swept shorts side band',[(side*.094,-.035,-.025),(side*.094,-.10,-.039),(side*.077,-.19,-.043)],.016,mats['white'],leg)
        loft('Shorts hem',[(-.217,.086,.080,.006),(-.194,.087,.081,.006)],mats['rubber'],leg,sides=24,sub=1)
        ellipsoid('Rounded knee',(0,-.245,.004),(.068,.080,.066),mats['skin'],leg,24,16)
        shin=empty('Shin',(0,-.25,0),leg)
        loft('Sporting calf',[(.02,.064,.061,0),(-.05,.065,.063,.006),(-.14,.052,.049,.004),(-.205,.043,.044,0)],mats['skin'],shin,sides=24,sub=2)
        loft('Ankle sock',[(-.23,.052,.053,0),(-.21,.058,.055,0),(-.13,.056,.053,.004)],mats['cloth'],shin,sides=24,sub=1)
        # Authored sneaker section rings along Z, rounded toe and raised heel collar.
        verts=[];faces=[];sections=[(-.235,.025,.055),(-.21,.072,.075),(-.16,.102,.104),(-.07,.102,.145),(.035,.075,.195),(.082,.057,.173)]
        sides=24
        for z,w,h in sections:
            for j in range(sides):
                a=math.tau*j/sides;verts.append((math.cos(a)*w,-.32+.025+(math.sin(a)+1)*.5*(h-.025),z))
        for i in range(len(sections)-1):
            for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
        faces.extend([tuple(reversed(range(sides))),tuple((len(sections)-1)*sides+j for j in range(sides))])
        mesh('Sculpted aerodynamic sneaker upper',verts,faces,mats['rubber'],shin,sub=2)
        # Footprint-shaped sole, not a cuboid boot.
        outline=[(-.05,.08),(-.08,.035),(-.105,-.10),(-.09,-.185),(-.05,-.225),(0,-.239),(.05,-.225),(.09,-.185),(.105,-.10),(.08,.035),(.05,.08)]
        sv=[(x,y,z) for y in [-.320,-.295] for x,z in outline];sf=[];n=len(outline)
        sf.extend([tuple(reversed(range(n))),tuple(n+j for j in range(n))])
        for j in range(n):sf.append((j,(j+1)%n,(j+1)%n+n,j+n))
        mesh('Continuous shaped sneaker midsole',sv,sf,mats['white'],shin,bevel=.007)
        for j in range(3):curve('Cross lacing',[(-.043,-.163-j*.015,-.064-j*.029),(0,-.153-j*.015,-.068-j*.029),(.043,-.163-j*.015,-.064-j*.029)],.005,mats['white'],shin)
        curve('Shoe motion stripe',[(side*.078,-.20,.012),(side*.100,-.225,-.075),(side*.078,-.238,-.16)],.010,mats['team'],shin)
    gun=empty('Weapon',(.31,.60923076923,-.29),r)
    box('Compact contoured receiver',(0,.035,-.09),(.23,.19,.28),mats['rubber'],gun,.038)
    box('Projector upper fairing',(0,.105,-.105),(.238,.07,.245),mats['white'],gun,.025)
    box('Angled pistol grip',(0,-.105,.005),(.084,.20,.11),mats['rubber'],gun,.025)
    cylinder('Machined barrel',(0,.04,-.325),.072,.235,mats['metal'],gun,axis='z')
    annulus_z('Open machined nozzle housing',(0,.04,-.464),.101,.070,.092,mats['rubber'],gun)
    annulus_z('Nectar nozzle annular lip',(0,.04,-.507),.069,.046,.006,mats['team'],gun)
    cylinder('Recessed nozzle interior',(0,.04,-.503),.045,.004,mats['rubber'],gun,axis='z')
    for x in [-.084,.084]:curve('Receiver colored pressure rail',[(x,.05,-.20),(x,.061,-.31),(x,.05,-.39)],.012,mats['team'],gun)
    box('Low profile aiming rib',(0,.153,-.14),(.035,.028,.19),mats['rubber'],gun,.008)
    box('Front sight',(0,.176,-.22),(.027,.018,.022),mats['team'],gun,.005)
    empty('Muzzle',(0,.04,-.51),gun)
    # Save original editable source and export the same hierarchy for Godot.
    bpy.context.scene.render.engine='BLENDER_EEVEE_NEXT'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/f'athlete_{"blue" if team==0 else "orange"}.blend'),compress=True)
    legacy=ROOT/'source'/'legacy_human';legacy.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(legacy/f'athlete_{"blue" if team==0 else "orange"}.glb'),export_format='GLB',use_selection=False,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT')

if __name__=='__main__':
    build(0);build(1)
