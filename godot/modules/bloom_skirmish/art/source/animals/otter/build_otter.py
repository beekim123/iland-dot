"""Original chibi otter athlete. Blender 4.3.2. No external assets or textures.
Run: blender -b --python art/source/animals/otter/build_otter.py
Godot coordinates: X right, Y up, -Z forward. Editable authored surfaces are
merged per articulated pivot for an eleven-mesh independent embedded GLB.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ART=HERE.parents[2]
OUT=ART/'models'/'animals'/'otter'
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

def tail(p,m):
    # Wide muscular root flowing into a flattened, tapering swimmer's tail.
    sections=[(0,-.24,.12,.115,.090),(-.015,-.32,.25,.133,.095),(-.055,-.40,.42,.122,.076),(-.12,-.46,.60,.098,.058),(-.22,-.49,.77,.065,.038),(-.31,-.50,.87,.026,.020),(-.34,-.50,.90,.004,.004)]
    vs=[];fs=[];n=20
    for x,y,z,w,h in sections:
        for j in range(n):
            a=math.tau*j/n;vs.append((x+w*math.cos(a),y+h*math.sin(a),z))
    for i in range(len(sections)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    fs += [tuple(reversed(range(n))),tuple((len(sections)-1)*n+j for j in range(n))]
    mesh('Broad tapered river otter tail',vs,fs,m,p,sub=1)

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

def build(team):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):bpy.data.materials.remove(m)
    accent='2864F0' if team=='blue' else 'F78B30'
    M={
      'fur':mat('Natural chestnut otter fur','78533D',.82),
      'fur_light':mat('Warm crown and brow fur','956C4E',.84),
      'cream':mat('Natural pale muzzle and belly','E8CDA4',.83),
      'ear':mat('Warm inner rounded ears','B28669',.86),
      'nose':mat('Nose mouth and paw detail','332B28',.40),
      'eye':mat('Bright deep cocoa eyes','201A17',.17),
      'iris':mat('Warm iris glint','865934',.27),
      'white':mat('Mineral white equipment','E1E8E8',.55),
      'glint':mat('Eye catchlights','FFFCF1',.18),
      'graphite':mat('Graphite sport harness','28343D',.78),
      'metal':mat('Satin precision fittings','788C98',.32,.55),
      'team':mat('Cobalt or orange team accent',accent,.30,.12),
      'fluid':mat('Visible team liquid',accent,.18,0,.86),
      'glass':mat('Translucent reservoir shell','D0EAF0',.16,0,.17),
    }
    root=empty('AthleteRoot');root['species']='original_chibi_river_otter';root['team']=team
    body=empty('Body',(0,.69,.025),root)
    loft('Long rounded otter torso',[
      (-.375,.10,.10,.015,0),(-.34,.18,.155,.01,0),(-.25,.235,.183,.005,0),(-.10,.260,.203,0,0),(.07,.252,.19,0,0),(.22,.220,.16,0,0),(.30,.175,.13,0,0),(.345,.10,.09,0,0)],M['fur'],body,n=28,sub=1)
    ell('Pale long belly bib',(0,-.02,-.161),(.199,.286,.065),M['cream'],body,n=28,k=18)
    tail(body,M['fur'])
    # Minimal technical vest leaves the otter's long belly and pear body visible.
    for s in [-1,1]:
        ell('Short fitted side vest',(s*.216,.095,-.006),(.055,.190,.168),M['graphite'],body,n=20,k=12)
        tube('White shoulder harness',[(s*.13,.31,.03),(s*.17,.255,-.11),(s*.154,.12,-.19),(s*.147,.00,-.20)],.021,M['white'],body)
        tube('Team harness inset',[(s*.13,.30,.025),(s*.17,.25,-.12),(s*.154,.11,-.211)],.009,M['team'],body)
        box('Harness quick release',(s*.15,.018,-.217),(.05,.049,.024),M['graphite'],body,.008)
        box('Team buckle face',(s*.15,.02,-.233),(.026,.020,.010),M['team'],body,.004)
    tube('Short chest strap',[(-.146,.10,-.207),(0,.086,-.230),(.146,.10,-.207)],.016,M['graphite'],body)
    box('Mineral white team badge',(0,.088,-.248),(.072,.056,.014),M['white'],body,.009)
    box('Team badge inset',(0,.089,-.258),(.041,.025,.008),M['team'],body,.005)
    # Tank on back, real colored fill volume and open transparent walls.
    box('Backplate',(0,.105,.195),(.25,.32,.057),M['graphite'],body,.028)
    cyl('Liquid fill',(0,.073,.284),.111,.253,M['fluid'],body)
    cyl('Flat liquid surface',(0,.201,.284),.112,.008,M['team'],body)
    cyl('Transparent compact tank',(0,.125,.284),.133,.36,M['glass'],body,caps=False)
    for y in [-.061,.311]:
        cyl('Mineral tank end cap',(0,y,.284),.139,.045,M['white'],body)
        cyl('Graphite cap gasket',(0,y-.022,.284),.135,.013,M['graphite'],body)
    cyl('Tank top fill port',(0,.350,.284),.047,.035,M['team'],body,n=20)
    for s in [-1,1]:tube('Reservoir guard rail',[(s*.115,-.055,.319),(s*.137,.12,.323),(s*.115,.311,.319)],.011,M['graphite'],body)
    for i in range(4):box('Tank level tick',(.056,-.005+i*.045,.410),(.029,.006,.006),M['white'],body,.001)
    tube('Translucent shell highlight',[(-.055,-.01,.404),(-.067,.13,.406),(-.055,.255,.404)],.004,M['white'],body)
    tube('Liquid supply hose',[(.10,-.045,.29),(.28,-.14,.27),(.31,-.17,.05),(.31,-.10,-.24)],.018,M['graphite'],body)
    # A broad round animal head; no human chin, nose, hair or neck.
    head=empty('Head',(0,1.184,-.014),root)
    ell('Round otter head',(0,0,0),(.297,.279,.239),M['fur'],head,n=32,k=20)
    for s in [-1,1]:
        ell('Small round otter ear',(s*.266,.158,.015),(.082,.085,.045),M['fur'],head,n=20,k=12)
        ell('Recessed warm ear cup',(s*.275,.160,-.023),(.048,.052,.014),M['ear'],head,n=16,k=10)
        # Slight warm brow volumes reinforce the rounded, non-human animal face.
        ell('Soft expressive brow',(s*.128,.073,-.196),(.094,.096,.038),M['fur_light'],head,n=20,k=12)
    ell('Broad pale otter cheek bib',(0,-.094,-.186),(.252,.141,.071),M['cream'],head,n=28,k=16)
    for s in [-1,1]:
        ell('Plump whisker muzzle pad',(s*.095,-.073,-.244),(.137,.091,.074),M['cream'],head,n=24,k=14)
        x=s*.126
        ell('Large bright cocoa eye',(x,.041,-.220),(.060,.075,.029),M['eye'],head,n=24,k=16)
        ell('Amber lower iris',(x+s*.004,.018,-.247),(.031,.030,.006),M['iris'],head,n=18,k=10)
        ell('Deep eye center',(x,.036,-.251),(.028,.043,.005),M['eye'],head,n=18,k=12)
        ell('Main expressive catchlight',(x-.015,.065,-.253),(.018,.021,.006),M['glint'],head,n=16,k=10)
        ell('Small eye sparkle',(x+.016,.021,-.253),(.008,.009,.005),M['glint'],head,n=12,k=8)
        tube('Curved expressive brow',[(x-.042,.128,-.191),(x,.142,-.205),(x+.040,.130,-.192)],.009,M['fur_light'],head)
        # Three curved ivory whiskers, clearly visible rather than painted dots.
        for j in range(3):
            y=-.065-j*.023
            tube('Fine muzzle whisker',[(s*.166,y,-.296),(s*.235,y+.009-j*.008,-.285),(s*(.317+.012*(j%2)),y+.028-j*.024,-.267)],.0032,M['cream'],head)
        for dx,dy in [(0,0),(.025,-.015),(.005,-.031)]:
            ell('Whisker follicle',(s*(.140+dx),-.055+dy,-.312),(.005,.005,.003),M['fur_light'],head,n=8,k=6)
    # Rounded triangular nose instead of a human projecting nose.
    mesh('Rounded beadlike otter nose',[(-.054,-.021,-.312),(.054,-.021,-.312),(0,-.074,-.329),(-.044,-.024,-.347),(.044,-.024,-.347),(0,-.064,-.355)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],M['nose'],head,sub=2)
    ell('Nose soft glint',(-.014,-.030,-.346),(.012,.005,.004),M['fur_light'],head,n=12,k=8)
    tube('Short muzzle cleft',[(0,-.066,-.327),(0,-.100,-.314)],.0045,M['nose'],head)
    tube('Happy animal smile',[(-.065,-.104,-.304),(-.035,-.123,-.308),(0,-.109,-.315),(.035,-.123,-.308),(.065,-.104,-.304)],.0045,M['nose'],head)
    # Short animal forepaws. No human upper arm/elbow silhouette or gloves.
    for s in [-1,1]:
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.257,.862,-.005),root)
        ell('Round short upper forelimb',(s*.027,-.059,-.005),(.093,.135,.097),M['fur'],arm,n=24,k=14)
        ell('Small shoulder sport patch',(s*.075,.005,-.017),(.034,.064,.068),M['white'],arm,n=16,k=10)
        ell('Shoulder team spot',(s*.103,.014,-.028),(.010,.034,.035),M['team'],arm,n=12,k=10)
        fore=empty('Forearm',(s*.028,-.132,-.028),arm)
        ell('Short broad forepaw',(0,-.069,-.015),(.088,.105,.093),M['fur'],fore,n=24,k=14)
        if s>0:empty('Grip',(0,-.069,-.015),fore)
        ell('Soft palm underside',(0,-.105,-.084),(.059,.046,.022),M['fur_light'],fore,n=16,k=10)
        # Discreet cuff, then visible natural-fur paw digits.
        loft('Small graphite wrist wrap',[(.002,.085,.081,-.006,0),(-.031,.087,.083,-.010,0)],M['graphite'],fore,n=20,sub=1)
        tube('Cuff team dash',[(-.048,-.017,-.079),(0,-.018,-.092),(.048,-.017,-.079)],.006,M['team'],fore)
        for x in [-.027,.027]:tube('Paw toe groove',[(x,-.123,-.087),(x,-.143,-.075)],.003,M['nose'],fore)
        # Short hind paws seated under the long torso; no shorts or human legs.
        leg=empty('LegL' if s<0 else 'LegR',(s*.133,.345,.01),root)
        ell('Short thick hind haunch',(s*.014,-.052,.005),(.117,.137,.120),M['fur'],leg,n=24,k=14)
        shin=empty('Shin',(s*.014,-.139,-.019),leg)
        ell('Rounded ankle',(0,-.040,.015),(.084,.088,.084),M['fur'],shin,n=20,k=12)
        ell('Wide otter hind paw',(0,-.139,-.064),(.111,.067,.175),M['fur'],shin,n=24,k=14)
        # Fine graphite sole guards, not shoes: the brown webbed paw remains dominant.
        ell('Low paw sole guard',(0,-.186,-.067),(.108,.020,.168),M['graphite'],shin,n=24,k=10)
        for x in [-.037,.037]:tube('Hind paw toe crease',[(x,-.119,-.214),(x,-.106,-.174)],.0035,M['nose'],shin)
        tube('Small heel team inset',[(-.046,-.171,.063),(0,-.169,.084),(.046,-.171,.063)],.006,M['team'],shin)
    weapon=empty('Weapon',(.31,.60923076923,-.29),root)
    box('Graphite sprayer receiver',(0,.035,-.10),(.183,.150,.265),M['graphite'],weapon,.032)
    box('Mineral white sprayer fairing',(0,.096,-.12),(.196,.065,.242),M['white'],weapon,.023)
    # Animal-specific rear/top U grip: preserves natural high short forepaws.
    # In common idle (+.50 arm X / +.70 forearm X), the right paw wraps
    # the transverse grip, not an unreachable human pistol handle below.
    grip_center=(-.025,.139330148912,-.162602546078+.29)
    for x in [-.080,.030]:
        tube('Short rear U grip mounting strut',[(x,.090,.012),(x,.132,.070),(x,.139330148912,.127397453922)],.013,M['graphite'],weapon)
        ell('U grip end collar',(x,.139330148912,.127397453922),(.021,.024,.024),M['white'],weapon,n=12,k=8)
    tube('Transverse short paw grip',[(-.080,.139330148912,.127397453922),(.030,.139330148912,.127397453922)],.018,M['graphite'],weapon)
    empty('Grip',grip_center,weapon)
    cyl('Sprayer barrel',(0,.04,-.326),.063,.230,M['metal'],weapon,axis='z')
    ring('Graphite nozzle',(0,.04,-.462),.085,.057,.085,M['graphite'],weapon)
    ring('Team nozzle lip',(0,.04,-.506),.062,.040,.007,M['team'],weapon)
    cyl('Recessed nozzle bore',(0,.04,-.502),.040,.004,M['graphite'],weapon,axis='z',n=20)
    for s in [-1,1]:tube('Team pressure conduit',[(s*.071,.045,-.208),(s*.075,.054,-.31),(s*.067,.045,-.397)],.009,M['team'],weapon)
    box('Team receiver stripe',(.094,.025,-.092),(.009,.034,.135),M['team'],weapon,.004)
    box('Compact sight',(0,.137,-.165),(.026,.022,.091),M['graphite'],weapon,.006)
    empty('Muzzle',(0,.04,-.51),weapon)
    merge_per_joint(root)
    # Deterministic geometric QA, before adding any preview studio objects.
    deps=bpy.context.evaluated_depsgraph_get();tri=0;bounds=[];meshes=[]
    for o in root.children_recursive:
        if o.type!='MESH':continue
        me=o.evaluated_get(deps).to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles);meshes.append(o.name)
        bounds += [o.matrix_world@Vector(c) for c in o.bound_box]
    dims=[(min(v[k] for v in bounds),max(v[k] for v in bounds)) for k in range(3)]
    report={'species':'otter','team':team,'mesh_count':len(meshes),'triangle_count':tri,'blender_bounds':dims,'godot_height':dims[2][1]-dims[2][0],'direct_nodes':[o.name for o in root.children],'muzzle_godot':[.31,.64923076923,-.80],'physical_muzzle_godot':[.403,.884,-1.04],'materials':[m.name for m in M.values()],'no_external_assets':True}
    assert len(meshes)<=25 and tri<40000, report
    for name in ['Body','Head','ArmL','ArmR','LegL','LegR','Weapon']:assert name in {o.name for o in root.children}
    bpy.context.scene.render.engine='BLENDER_EEVEE_NEXT';bpy.context.scene.render.film_transparent=True
    for o in [root]+list(root.children_recursive):o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'otter_{team}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT')
    # A source-only studio for inspecting original geometry, excluded from GLB.
    bpy.ops.object.select_all(action='DESELECT')
    camera_data=bpy.data.cameras.new('Otter inspection camera');camera=bpy.data.objects.new('Otter inspection camera',camera_data);bpy.context.collection.objects.link(camera)
    camera.location=xyz((2.55,1.80,-3.60));target=Vector(xyz((0,.75,.10)));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=2.15
    scene=bpy.context.scene;scene.camera=camera;scene.render.resolution_x=850;scene.render.resolution_y=950;scene.render.resolution_percentage=100
    scene.world.color=(.20,.20,.20);scene.view_settings.view_transform='AgX'
    for name,location,power,size in [('Key',(-3,4,-4),500,4),('Fill',(3,2,-2),350,3),('Rim',(1,3,4),650,3)]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size;ob=bpy.data.objects.new(name,ld);bpy.context.collection.objects.link(ob);ob.location=xyz(location);ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(HERE/f'otter_{team}_held_closeup.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/f'otter_{team}.blend'),compress=True)
    if '--skip-render' not in sys.argv:
        for arm_name,a,fa in [('ArmR',.50,.70),('ArmL',.20,.35)]:
            arm=bpy.data.objects[arm_name];arm.rotation_euler.x=a
            next(o for o in arm.children if o.name.startswith('Forearm')).rotation_euler.x=fa
        bpy.data.objects['ArmL'].rotation_euler.y=-.09
        bpy.ops.render.render(write_still=True)
    (HERE/f'otter_{team}_qa.json').write_text(json.dumps(report,indent=2))
    print('OTTER_QA',json.dumps(report))

if __name__=='__main__':
    (HERE/'.gdignore').touch()
    build('blue');build('orange')
