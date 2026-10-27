"""Original ivory chibi rabbit athlete, authored in Blender 4.3.2.
Reproduce: blender -b --python art/source/animals/rabbit/build_rabbit.py -- --skip-render
Coordinates: Godot X-right, Y-up, -Z-forward, mapped to Blender (x,-z,y).
Self-contained procedural geometry; no external assets, textures, or human anatomy.
Team colors affect technical equipment only; rabbit fur remains identical.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ART=HERE.parents[2]
OUT=ART/'models'/'animals'/'rabbit'
OUT.mkdir(parents=True,exist_ok=True)

def xyz(p): return (p[0],-p[2],p[1])
def srgb(c): return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4

def mat(name,color,rough=.65,metal=0,alpha=1):
    m=bpy.data.materials.new(name);m.use_nodes=True
    c=tuple(srgb(int(color[i:i+2],16)/255) for i in (0,2,4))+(alpha,)
    m.diffuse_color=c;b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=c;b.inputs['Roughness'].default_value=rough
    b.inputs['Metallic'].default_value=metal;b.inputs['Alpha'].default_value=alpha
    if alpha<1:m.surface_render_method='DITHERED';m.use_transparency_overlap=False
    return m

def empty(name,p=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.location=xyz(p);o.parent=parent;return o

def mesh(name,verts,faces,m,parent,sub=0,bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(v) for v in verts],[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(m)
    for p in me.polygons:p.use_smooth=True
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    if sub:
        mod=o.modifiers.new('Soft sculpted surface','SUBSURF');mod.levels=sub;mod.render_levels=sub
    if bevel:
        mod=o.modifiers.new('Manufactured softened edges','BEVEL');mod.width=bevel;mod.segments=3
        mod=o.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    return o

def ell(name,c,s,m,p,n=24,k=14):
    vs=[];fs=[]
    for i in range(k+1):
        a=math.pi*i/k
        for j in range(n):
            b=math.tau*j/n
            vs.append((c[0]+s[0]*math.sin(a)*math.cos(b),c[1]+s[1]*math.cos(a),c[2]+s[2]*math.sin(a)*math.sin(b)))
    for i in range(k):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    return mesh(name,vs,fs,m,p)

def loft(name,sections,m,p,n=24,sub=1):
    vs=[];fs=[]
    for y,w,d,z,x in sections:
        for j in range(n):
            a=math.tau*j/n;vs.append((x+w*math.cos(a),y,z+d*math.sin(a)))
    for i in range(len(sections)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    fs += [tuple(reversed(range(n))),tuple((len(sections)-1)*n+j for j in range(n))]
    return mesh(name,vs,fs,m,p,sub=sub)

def box(name,c,s,m,p,bev=.012):
    vs=[(c[0]+a*s[0]/2,c[1]+b*s[1]/2,c[2]+d*s[2]/2) for a,b,d in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],m,p,bevel=bev)

def tube(name,points,r,m,p):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=5;cu.bevel_depth=r;cu.bevel_resolution=2;cu.use_fill_caps=True
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for bp,v in zip(sp.bezier_points,points):bp.co=xyz(v);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.parent=p;cu.materials.append(m);return o

def cyl(name,c,r,d,m,p,axis='y',n=24,caps=True):
    vs=[];fs=[]
    for s in [-1,1]:
        for j in range(n):
            a=math.tau*j/n;v=(r*math.cos(a),s*d/2,r*math.sin(a))
            if axis=='z':v=(v[0],v[2],v[1])
            vs.append(tuple(c[k]+v[k] for k in range(3)))
    for j in range(n):fs.append((j,(j+1)%n,(j+1)%n+n,j+n))
    if caps:fs += [tuple(reversed(range(n))),tuple(n+j for j in range(n))]
    return mesh(name,vs,fs,m,p,bevel=.004 if caps else 0)

def ring(name,c,ro,ri,d,m,p,n=24):
    vs=[];fs=[]
    for r,z in [(ro,-d/2),(ro,d/2),(ri,d/2),(ri,-d/2)]:
        for j in range(n):
            a=math.tau*j/n;vs.append((c[0]+r*math.cos(a),c[1]+r*math.sin(a),c[2]+z))
    for k in range(4):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j))
    return mesh(name,vs,fs,m,p)

def merge_per_joint(root):
    # Preserve anatomical joints and material slots; no animation skeleton needed.
    joints=[o for o in root.children_recursive if o.type=='EMPTY' and o.name!='Muzzle']
    for p in joints:
        parts=[o for o in list(p.children) if o.type in {'MESH','CURVE'}]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join();o=bpy.context.object;o.name=p.name+'_Surface';o.data.name=p.name+'_AuthoredGeometry'
        # Coalesce repeated material slots after same-material merging.
        slots=list(o.data.materials);unique=[];mapping={}
        for i,m in enumerate(slots):
            if m not in unique:unique.append(m)
            mapping[i]=unique.index(m)
        ids=[mapping[f.material_index] for f in o.data.polygons]
        o.data.materials.clear()
        for m in unique:o.data.materials.append(m)
        for f,i in zip(o.data.polygons,ids):f.material_index=i
    bpy.ops.object.select_all(action='DESELECT')

def ear(name,sections,m,p,n=20,sub=1):
    vs=[];fs=[]
    for x,y,z,w,d in sections:
        for j in range(n):
            a=math.tau*j/n;vs.append((x+w*math.cos(a),y,z+d*math.sin(a)))
    for i in range(len(sections)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    fs += [tuple(reversed(range(n))),tuple((len(sections)-1)*n+j for j in range(n))]
    return mesh(name,vs,fs,m,p,sub=sub)

def rx(p,a):return Vector((p[0],p[1]*math.cos(a)-p[2]*math.sin(a),p[1]*math.sin(a)+p[2]*math.cos(a)))

def build(team):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):bpy.data.materials.remove(m)
    accent='2864F0' if team=='blue' else 'F78B30'
    M={
      'fur':mat('Natural ivory rabbit fur','E8E4DA',.83),
      'cream':mat('Soft cream muzzle and belly fur','FFF7E8',.84),
      'warm':mat('Warm paw and brow fur','C9BEB1',.85),
      'ear':mat('Peach inner ear','ECA994',.84),
      'nose':mat('Soft warm pink rabbit nose','B97065',.55),
      'line':mat('Warm cocoa facial lines','58423C',.60),
      'eye':mat('Bright warm brown rabbit eyes','30221B',.16),
      'iris':mat('Amber iris','A66C38',.26),
      'glint':mat('Cream eye catchlights','FFFEF7',.17),
      'white':mat('Mineral white equipment','DFE6E7',.52),
      'graphite':mat('Graphite sport harness','28343D',.74),
      'metal':mat('Satin precision fittings','788C98',.30,.55),
      'team':mat('Cobalt or orange team accent',accent,.30,.12),
      'fluid':mat('Visible team liquid',accent,.18,0,.86),
      'glass':mat('Translucent reservoir shell','D0EAF0',.16,0,.17),
    }
    root=empty('AthleteRoot');root['species']='original_chibi_ivory_rabbit';root['team']=team
    body=empty('Body',(0,.675,.025),root)
    loft('Compact pear shaped rabbit torso',[(-.39,.09,.09,.01,0),(-.35,.20,.15,.015,0),(-.24,.273,.19,.009,0),(-.08,.286,.201,0,0),(.10,.251,.181,0,0),(.245,.211,.148,0,0),(.325,.14,.10,0,0),(.35,.07,.07,0,0)],M['fur'],body,n=24,sub=1)
    ell('Round cream rabbit belly',(0,-.035,-.160),(.220,.255,.067),M['cream'],body,n=24,k=16)
    ell('Round cotton rabbit tail',(0,-.14,.242),(.127,.123,.125),M['cream'],body,n=24,k=16)
    # Short side-vest and narrow straps leave natural pear torso and belly visible.
    for s in [-1,1]:
        ell('Short graphite side vest',(s*.218,.10,.005),(.050,.160,.153),M['graphite'],body,n=18,k=12)
        tube('Mineral shoulder harness',[(s*.135,.31,.025),(s*.168,.26,-.10),(s*.162,.12,-.18),(s*.150,.025,-.209)],.020,M['white'],body)
        tube('Team harness inset',[(s*.135,.30,.025),(s*.168,.25,-.116),(s*.162,.115,-.20)],.007,M['team'],body)
        box('Harness quick release',(s*.153,.025,-.221),(.048,.044,.024),M['graphite'],body,.007)
        box('Team buckle inset',(s*.153,.027,-.235),(.024,.016,.009),M['team'],body,.003)
    tube('Light chest strap',[(-.155,.13,-.201),(0,.108,-.225),(.155,.13,-.201)],.014,M['graphite'],body)
    box('Mineral white team badge',(0,.111,-.244),(.069,.052,.014),M['white'],body,.008)
    box('Team badge inset',(0,.112,-.254),(.039,.022,.008),M['team'],body,.004)
    box('Graphite backpack plate',(0,.125,.178),(.245,.29,.055),M['graphite'],body,.024)
    cyl('Liquid fill',(0,.104,.266),.105,.228,M['fluid'],body,n=20)
    cyl('Flat visible liquid surface',(0,.220,.266),.106,.008,M['team'],body,n=20)
    cyl('Transparent compact tank',(0,.145,.266),.125,.33,M['glass'],body,n=20,caps=False)
    for y in [-.025,.315]:
        cyl('Mineral tank end cap',(0,y,.266),.131,.040,M['white'],body,n=20)
        cyl('Graphite tank gasket',(0,y-.019,.266),.126,.010,M['graphite'],body,n=20)
    cyl('Tank fill port',(0,.351,.266),.043,.035,M['team'],body,n=16)
    for s in [-1,1]:tube('Reservoir protective rail',[(s*.109,-.02,.300),(s*.129,.145,.308),(s*.109,.315,.300)],.010,M['graphite'],body)
    for i in range(4):box('Tank level tick',(.053,.025+i*.044,.385),(.025,.005,.006),M['white'],body,.001)
    tube('Reservoir highlight',[(-.051,.03,.380),(-.063,.15,.385),(-.051,.267,.380)],.0035,M['white'],body)
    tube('Liquid supply hose',[(.09,-.015,.27),(.285,-.11,.255),(.31,-.14,.055),(.31,-.09,-.23)],.016,M['graphite'],body)
    head=empty('Head',(0,1.204,-.02),root)
    ell('Broad round rabbit head',(0,0,0),(.309,.289,.246),M['fur'],head,n=32,k=20)
    # Long flattened ears follow expressive centerlines, not accessory capsules.
    for s in [-1,1]:
        seq=[(s*.131,.185,.017,.060,.051),(s*.145,.247,.020,.076,.050),(s*.160,.375,.024,.080,.045),(s*(.188 if s<0 else .173),.525,.026,.071,.037),(s*(.233 if s<0 else .184),.657,.017,.050,.026),(s*(.250 if s<0 else .184),(.705 if s<0 else .738),.004,.009,.008)]
        ear('Long tapered expressive rabbit ear',seq,M['fur'],head,n=20,sub=1)
        inner=[(s*.143,.266,-.028,.033,.008),(s*.158,.355,-.021,.051,.012),(s*(.180 if s<0 else .170),.495,-.015,.046,.010),(s*(.222 if s<0 else .181),.628,-.011,.031,.008),(s*(.240 if s<0 else .183),(.681 if s<0 else .706),-.005,.004,.003)]
        ear('Inset peach ear velvet',inner,M['ear'],head,n=16,sub=1)
        ell('Round cream rabbit cheek',(s*.178,-.091,-.181),(.126,.118,.068),M['cream'],head,n=24,k=14)
        x=s*.127
        ell('Large warm rabbit eye',(x,.038,-.224),(.062,.082,.031),M['eye'],head,n=24,k=16)
        ell('Warm amber lower iris',(x+s*.002,.013,-.253),(.036,.035,.007),M['iris'],head,n=18,k=12)
        ell('Deep eye pupil',(x,.035,-.258),(.031,.048,.005),M['eye'],head,n=18,k=12)
        ell('Large eye catchlight',(x-.017,.065,-.261),(.020,.023,.006),M['glint'],head,n=16,k=10)
        ell('Small eye catchlight',(x+.019,.012,-.261),(.008,.010,.004),M['glint'],head,n=12,k=8)
        tube('Soft expressive brow',[(x-.045,.145,-.192),(x,.159,-.202),(x+.039,.150,-.194)],.0075,M['warm'],head)
    ell('Small rabbit muzzle base',(0,-.104,-.230),(.139,.086,.060),M['cream'],head,n=24,k=14)
    for s in [-1,1]:
        ell('Small rabbit muzzle pad',(s*.049,-.087,-.276),(.067,.051,.036),M['cream'],head,n=20,k=12)
        for j in range(2):
            y=-.083-j*.024
            tube('Fine rabbit whisker',[(s*.122,y,-.283),(s*.198,y+.004-j*.008,-.275),(s*.256,y+.015-j*.025,-.255)],.0023,M['warm'],head)
    mesh('Small rounded rabbit nose',[(-.029,-.058,-.294),(.029,-.058,-.294),(0,-.088,-.310),(-.026,-.060,-.316),(.026,-.060,-.316),(0,-.083,-.326)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],M['nose'],head,sub=2)
    tube('Rabbit muzzle cleft',[(0,-.085,-.311),(0,-.108,-.307)],.0038,M['line'],head)
    tube('Gentle rabbit smile',[(-.044,-.113,-.299),(-.024,-.127,-.302),(0,-.112,-.310),(.024,-.127,-.302),(.044,-.113,-.299)],.0038,M['line'],head)
    # Natural upper torso shoulders and compact fur forepaws (not long human arms).
    for s in [-1,1]:
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.257,.875,-.005),root)
        ell('Short rounded rabbit upper forepaw',(s*.025,-.057,-.005),(.093,.128,.095),M['fur'],arm,n=20,k=14)
        ell('Small shoulder sport patch',(s*.075,.007,-.018),(.031,.057,.061),M['white'],arm,n=16,k=10)
        ell('Shoulder team mark',(s*.102,.016,-.030),(.009,.029,.032),M['team'],arm,n=12,k=8)
        fore=empty('Forearm',(s*.028,-.132,-.028),arm)
        ell('Compact soft rabbit forepaw',(0,-.069,-.015),(.083,.101,.088),M['fur'],fore,n=20,k=14)
        if s>0:empty('Grip',(0,-.069,-.015),fore)
        loft('Small graphite wrist cuff',[(.000,.080,.077,-.006,0),(-.027,.082,.079,-.009,0)],M['graphite'],fore,n=18,sub=1)
        tube('Cuff team dash',[(-.043,-.016,-.074),(0,-.017,-.087),(.043,-.016,-.074)],.0055,M['team'],fore)
        for x in [-.025,.025]:tube('Forepaw toe crease',[(x,-.119,-.085),(x,-.139,-.071)],.0025,M['warm'],fore)
        leg=empty('LegL' if s<0 else 'LegR',(s*.149,.342,.03),root)
        ell('Large rounded rabbit hind haunch',(s*.025,-.035,.015),(.144,.153,.137),M['fur'],leg,n=24,k=14)
        shin=empty('Shin',(s*.015,-.139,-.018),leg)
        ell('Short rabbit ankle',(0,-.040,.005),(.096,.088,.088),M['fur'],shin,n=20,k=12)
        ell('Long broad rabbit hind foot',(s*.010,-.130,-.105),(.125,.073,.214),M['fur'],shin,n=24,k=14)
        ell('Fine graphite sole guard',(s*.010,-.181,-.108),(.119,.022,.202),M['graphite'],shin,n=24,k=10)
        for x in [-.040,0,.040]:tube('Rabbit hindtoe crease',[(x,-.110,-.293),(x,-.083,-.258)],.003,M['warm'],shin)
        tube('Tiny heel team inset',[(-.042,-.168,.064),(0,-.164,.085),(.042,-.168,.064)],.0055,M['team'],shin)
    weapon=empty('Weapon',(.31,.60923076923,-.29),root)
    box('Graphite compact sprayer receiver',(0,.035,-.10),(.174,.140,.253),M['graphite'],weapon,.028)
    box('Mineral sprayer fairing',(0,.091,-.12),(.186,.062,.234),M['white'],weapon,.020)
    # Exact analytical right-paw contact under shared +.50 upper / +.70 forearm idle.
    paw=Vector((.257,.875,-.005))+rx(Vector((.028,-.132,-.028))+rx((0,-.069,-.015),.70),.50)
    grip_center=paw-Vector((.31,.60923076923,-.29));gx,gy,gz=grip_center
    for x in [gx-.053,gx+.053]:
        tube('Compact rear top U grip support',[(x,.087,.006),(x,gy-.012,.067),(x,gy,gz)],.013,M['graphite'],weapon)
        ell('U grip end collar',(x,gy,gz),(.020,.022,.022),M['white'],weapon,n=12,k=8)
    tube('Transverse rabbit paw grip',[(gx-.053,gy,gz),(gx+.053,gy,gz)],.017,M['graphite'],weapon)
    empty('Grip',grip_center,weapon)
    cyl('Short precision sprayer barrel',(0,.04,-.326),.061,.230,M['metal'],weapon,axis='z',n=20)
    ring('Graphite nozzle shroud',(0,.04,-.462),.083,.055,.085,M['graphite'],weapon,n=24)
    ring('Team nozzle lip',(0,.04,-.506),.060,.038,.007,M['team'],weapon,n=24)
    cyl('Recessed nozzle bore',(0,.04,-.502),.038,.004,M['graphite'],weapon,axis='z',n=20)
    for s in [-1,1]:tube('Team pressure conduit',[(s*.068,.045,-.207),(s*.072,.054,-.31),(s*.065,.045,-.397)],.008,M['team'],weapon)
    box('Team receiver stripe',(.089,.025,-.092),(.008,.032,.133),M['team'],weapon,.003)
    box('Small precision sight',(0,.129,-.165),(.025,.020,.084),M['graphite'],weapon,.005)
    empty('Muzzle',(0,.04,-.51),weapon)
    merge_per_joint(root)
    deps=bpy.context.evaluated_depsgraph_get();tri=0;bounds=[];meshes=[]
    for o in root.children_recursive:
        if o.type!='MESH':continue
        me=o.evaluated_get(deps).to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles);meshes.append(o.name)
        bounds += [o.matrix_world@Vector(c) for c in o.bound_box]
    dims=[(min(v[k] for v in bounds),max(v[k] for v in bounds)) for k in range(3)]
    report={'species':'rabbit','team':team,'blender_version':bpy.app.version_string,'mesh_count':len(meshes),'triangle_count':tri,'blender_bounds':dims,'godot_height':dims[2][1]-dims[2][0],'head_top_without_ears':1.493,'direct_nodes':[o.name for o in root.children],'muzzle_godot':[.31,.64923076923,-.80],'physical_muzzle_godot':[.403,.884,-1.04],'right_paw_idle_godot':list(paw),'right_grip_local_godot':list(grip_center),'materials':[m.name for m in M.values()],'no_external_assets':True}
    assert len(meshes)<=25 and tri<40000, report
    assert abs(dims[2][0])<1e-5, report
    for name in ['Body','Head','ArmL','ArmR','LegL','LegR','Weapon']:assert name in {o.name for o in root.children}
    for o in [root]+list(root.children_recursive):o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'rabbit_{team}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT')
    bpy.ops.object.select_all(action='DESELECT')
    cd=bpy.data.cameras.new('Rabbit inspection camera');camera=bpy.data.objects.new('Rabbit inspection camera',cd);bpy.context.collection.objects.link(camera)
    camera.location=xyz((2.55,1.98,-3.60));target=Vector(xyz((0,.97,-.02)));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2.30
    scene=bpy.context.scene;scene.camera=camera;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.film_transparent=True
    scene.render.resolution_x=850;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.world.color=(.20,.20,.20);scene.view_settings.view_transform='AgX'
    for name,location,power,size in [('Key',(-3,4,-4),500,4),('Fill',(3,2,-2),350,3),('Rim',(1,3,4),650,3)]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size;ob=bpy.data.objects.new(name,ld);bpy.context.collection.objects.link(ob);ob.location=xyz(location);ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(HERE/f'rabbit_{team}_closeup.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/f'rabbit_{team}.blend'),compress=True)
    if '--skip-render' not in sys.argv:bpy.ops.render.render(write_still=True)
    (HERE/f'rabbit_{team}_qa.json').write_text(json.dumps(report,indent=2));print('RABBIT_QA',json.dumps(report))

if __name__=='__main__':
    (HERE/'.gdignore').touch();bpy.context.preferences.filepaths.save_version=0
    build('blue');build('orange')
