"""Original raccoon athlete. Blender 4.3.2; no downloaded assets or textures.

Run from any cwd:
  blender -b --python path/to/build_raccoon.py
Optional studio proof: append -- --render

Godot coordinates are authored as X right / Y up / -Z forward, converted by
the shared geometry helpers. Importing those helpers never calls human build().
This is a compact animal with paws, short muzzle, eye mask and a ringed tail,
not an anthropomorphic human body with a replacement head.
"""
import bpy, math, importlib.util, json, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ART = HERE.parents[2]
OUT = ART / 'models' / 'animals' / 'raccoon'
spec = importlib.util.spec_from_file_location('bloom_geometry_helpers', ART / 'source' / 'build_athlete.py')
G = importlib.util.module_from_spec(spec)
spec.loader.exec_module(G)
empty, mesh, material, box, cylinder, annulus_z = G.empty, G.mesh, G.material, G.box, G.cylinder, G.annulus_z

def ell(name, center, scale, mat, parent, seg=24, rings=14):
    return G.ellipsoid(name, center, scale, mat, parent, max(8,int(seg*.90)), max(6,int(rings*.90)))

def tube(name, points, radius, mat, parent):
    o = G.curve(name, points, radius, mat, parent)
    o.data.resolution_u = 5
    o.data.bevel_resolution = 2
    return o

def ear(name, side, mat, parent, inner=False):
    # Rounded small triangular pinnae, deliberately unlike a fox's tall points.
    center = (side * .224, .231, -.006)
    s = .66 if inner else 1.0
    outline = [(-.070,-.054),(-.086,.002),(-.060,.080),(-.023,.113),
               (.013,.112),(.056,.080),(.079,.025),(.065,-.040),(.006,-.068)]
    verts=[]
    for z, fac in [( .041, .63),(.004,1.0),(-.041, .77)]:
        for x,y in outline:
            verts.append((center[0]+side*x*s*fac,center[1]+y*s*fac,
                          center[2]+z*s+(-.044 if inner else 0)))
    n=len(outline); faces=[]
    for r in range(2):
        for i in range(n):faces.append((r*n+i,r*n+(i+1)%n,(r+1)*n+(i+1)%n,(r+1)*n+i))
    faces += [tuple(reversed(range(n))),tuple(2*n+i for i in range(n))]
    return mesh(name,verts,faces,mat,parent,sub=1)

def face_patch(name,cx,cy,rx,ry,angle,mat,parent,offset=.005):
    # Smooth material patch conforming to raccoon's cranial surface.
    verts=[]; faces=[]; sectors=40; rings=6
    for k in range(rings+1):
        rr=max(.0001,k/rings)
        for i in range(sectors):
            a=math.tau*i/sectors
            u=rx*math.cos(a)*rr; w=ry*math.sin(a)*rr
            x=cx+u*math.cos(angle)-w*math.sin(angle)
            y=cy+u*math.sin(angle)+w*math.cos(angle)
            z=-.235*math.sqrt(max(.018,1-(x/.305)**2-(y/.258)**2))-offset
            verts.append((x,y,z))
    for k in range(rings):
        for i in range(sectors):faces.append((k*sectors+i,k*sectors+(i+1)%sectors,(k+1)*sectors+(i+1)%sectors,(k+1)*sectors+i))
    return mesh(name,verts,faces,mat,parent)

def ringtail(parent, mats):
    # Broad fluffy swept tail; material ring boundaries are actual surface rings.
    p0=Vector((0,-.19,.17));p1=Vector((-.20,-.21,.59))
    p2=Vector((-.64,.03,.65));p3=Vector((-.55,.29,.43))
    verts=[];faces=[];mat_indices=[];steps=56;sides=24
    for i in range(steps+1):
        t=i/steps;u=1-t
        p=u*u*u*p0+3*u*u*t*p1+3*u*t*t*p2+t*t*t*p3
        tangent=(3*u*u*(p1-p0)+6*u*t*(p2-p1)+3*t*t*(p3-p2)).normalized()
        axis=tangent.cross(Vector((0,1,0))).normalized()
        across=axis.cross(tangent).normalized()
        radius=(.105+.046*math.sin(math.pi*t)) * (1-.68*t**7)
        if i==steps:radius=.014
        for j in range(sides):
            a=math.tau*j/sides
            # Subtle fur scalloping without painted texture or hard spikes.
            r=radius*(1+.025*math.cos(6*a+.7*t))
            v=p+axis*math.cos(a)*r+across*math.sin(a)*r
            verts.append(tuple(v))
    for i in range(steps):
        stripe = 1 if int(i/steps*9)%2 == 1 or i>steps-4 else 0
        for j in range(sides):
            faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j));mat_indices.append(stripe)
    faces += [tuple(reversed(range(sides))),tuple(steps*sides+i for i in range(sides))]
    mat_indices += [0,1]
    o=mesh('Fluffy swept raccoon ringtail',verts,faces,mats['fur'],parent)
    o.data.materials.append(mats['mask'])
    for p,idx in zip(o.data.polygons,mat_indices):p.material_index=idx
    return o

def consolidate_joint_meshes():
    # One multi-material mesh per articulated joint: no per-toe draw nodes.
    joints=[o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name not in ('AthleteRoot','Muzzle')]
    for parent in joints:
        parts=[o for o in list(parent.children) if o.type in ('MESH','CURVE')]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        o=bpy.context.object;o.name=parent.name+'_Surface'
        for p in o.data.polygons:p.use_smooth=True

def build(team):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):bpy.data.materials.remove(m)
    accent='326BEB' if team=='blue' else 'F47D25'
    mats={
        'fur':material('Raccoon natural silver grey fur','858C91',.91),
        'fur_light':material('Raccoon silver guard hairs','A9B0B1',.91),
        'cream':material('Raccoon warm cream muzzle belly and inner ears','E7E5D8',.91),
        'mask':material('Raccoon charcoal eye mask and tail rings','2A3037',.92),
        'paw':material('Raccoon dark soft paws','3A4048',.88),
        'white':material('Mineral white molded sports equipment','DCE3E5',.52),
        'graphite':material('Graphite flexible harness','26313B',.88),
        'metal':material('Satin graphite alloy','677985',.34,.42),
        'team':material('Team '+team+' enamel accent',accent,.31,.12),
        'liquid':material('Visible '+team+' liquid fill',accent,.17),
        'glass':material('Translucent mineral reservoir shell','CADDE2',.14,0,.18),
        'sclera':material('Playful bright eye ivory','FFFDF1',.29),
        'iris':material('Warm lively amber iris','B99143',.24),
        'black':material('Nose pupils and smile','101820',.36),
    }
    root=empty('AthleteRoot');root['species']='Raccoon';root['team']=team
    root['authorship']='Original procedural Blender mesh; no external assets'
    body=empty('Body',(0,.70,.035),root)
    ell('Compact pear shaped animal body',(0,-.015,0),(.245,.305,.194),mats['fur'],body,32,20)
    ell('Cream rounded belly',(0,-.040,-.143),(.184,.222,.074),mats['cream'],body,28,18)
    # Exposed belly and haunches preserve the animal silhouette; no human shirt.
    G.loft('Short open sporting back vest',[(.035,.226,.177,.018),(.07,.235,.181,.018),(.17,.230,.169,.018),(.22,.190,.141,.018)],mats['graphite'],body,24,1)
    # These front straps read as a compact harness rather than a full human jacket.
    for side in [-1,1]:
        tube('Mineral padded shoulder strap',[(side*.14,.25,.025),(side*.173,.19,-.10),(side*.148,.07,-.181)],.028,mats['white'],body)
        tube('Team shoulder seam',[(side*.144,.24,-.002),(side*.172,.17,-.124),(side*.149,.065,-.198)],.009,mats['team'],body)
        box('Harness chest clip',(side*.145,.059,-.193),(.065,.052,.028),mats['graphite'],body,.012)
    tube('Harness chest connector',[(-.14,.068,-.196),(0,.067,-.219),(.14,.068,-.196)],.015,mats['graphite'],body)
    box('Small team chest buckle',(0,.067,-.229),(.069,.048,.022),mats['team'],body,.011)
    # Lightweight compact backpack with transparent shell, visible liquid and air.
    box('Tank mounting pad',(0,.115,.196),(.205,.264,.045),mats['graphite'],body,.025)
    cylinder('Compact actual liquid fill',(0,.069,.274),.097,.18,mats['liquid'],body,sides=24)
    cylinder('Liquid meniscus',(0,.161,.274),.099,.008,mats['team'],body,sides=24)
    cylinder('Transparent cylindrical tank',(0,.109,.274),.113,.277,mats['glass'],body,sides=28,cap=False)
    for y in [-.039,.258]:
        cylinder('Mineral tank cap',(0,y,.274),.123,.041,mats['white'],body,sides=28)
        cylinder('Graphite tank seal',(0,y+(.023 if y<0 else -.023),.274),.115,.015,mats['graphite'],body,sides=24)
    cylinder('Reservoir latch',(0,.287,.274),.049,.028,mats['team'],body,sides=24)
    for i in range(3):box('Liquid level gauge',(.042,.045+i*.046,.385),(.033,.007,.006),mats['white'],body,.002)
    tube('Visible flexible liquid hose',[(.09,-.03,.28),(.24,-.09,.22),(.315,-.105,.04),(.315,-.10,-.17)],.015,mats['graphite'],body)
    ringtail(body,mats)

    head=empty('Head',(0,1.18,-.030),root)
    ell('Broad raccoon cranium',(0,0,0),(.305,.258,.235),mats['fur'],head,40,24)
    # Face patches are conformed, not flat floating eye-mask boards.
    face_patch('Cream lower face',0,-.095,.265,.129,0,mats['cream'],head,.003)
    for side in [-1,1]:
        ear('Small rounded outer pinna',side,mats['mask'],head)
        ear('Cream inner pinna',side,mats['cream'],head,True)
        face_patch('Distinct dark eye mask',side*.142,.005,.139,.083,-side*.20,mats['mask'],head,.010)
        x=side*.116
        ell('Big playful eye ivory',(x,.018,-.226),(.060,.068,.030),mats['sclera'],head,24,16)
        ell('Lively warm iris',(x+side*.002,.014,-.251),(.033,.044,.014),mats['iris'],head,20,14)
        ell('Rounded eye pupil',(x+side*.002,.014,-.263),(.021,.032,.008),mats['black'],head,20,14)
        ell('Large catchlight',(x-.009,.035,-.272),(.011,.014,.004),mats['sclera'],head,12,8)
        ell('Tiny secondary catchlight',(x+.012,.002,-.273),(.005,.006,.003),mats['sclera'],head,12,8)
        tube('Friendly raised brow',[(side*.064,.111,-.206),(side*.116,.125,-.208),(side*.173,.102,-.193)],.010,mats['cream'],head)
        # Small tapering cheek locks reinforce raccoon fluff rather than hair.
        ell('Low fluffy cream cheek',(side*.183,-.121,-.158),(.104,.077,.068),mats['cream'],head,20,12)
        G.lock('Short side cheek fur',[(side*.235,-.037,-.047),(side*.302,-.076,-.053),(side*.318,-.112,-.042)],.043,.028,mats['fur_light'],head)
    ell('Short animal muzzle',(0,-.091,-.239),(.141,.087,.087),mats['cream'],head,28,16)
    ell('Soft chin',(0,-.156,-.213),(.100,.047,.059),mats['cream'],head,20,12)
    ell('Small charcoal raccoon nose',(0,-.064,-.322),(.047,.030,.025),mats['black'],head,24,14)
    ell('Nose tiny soft highlight',(-.012,-.054,-.344),(.014,.006,.002),mats['fur_light'],head,12,8)
    tube('Muzzle philtrum',[(0,-.081,-.326),(0,-.110,-.322)],.005,mats['black'],head)
    for side in [-1,1]:
        tube('Cheeky raccoon smile',[(0,-.111,-.321),(side*.035,-.128,-.314),(side*.066,-.111,-.301)],.005,mats['black'],head)
        for x,y in [( .047,-.079),(.067,-.087)]:
            ell('Whisker follicle',(side*x,y,-.319),(.003,.003,.002),mats['mask'],head,8,6)
    # Tiny broad crown fur ridge, not a haircut, horns or hat.
    G.lock('Silver crown fur sweep',[(-.048,.239,.015),(-.014,.284,-.012),(.050,.256,-.050)],.047,.021,mats['fur_light'],head)

    for side in [-1,1]:
        holding=side>0
        arm=empty('ArmL' if side<0 else 'ArmR',(side*.258,.892,-.050 if holding else -.015),root)
        ell('Chubby upper foreleg',(side*.008,-.062,-.018 if holding else .003),(.083,.136,.095 if holding else .084),mats['fur'],arm,24,14)
        tube('Small team upper arm cuff',[(-.065,-.073,-.058),(0,-.085,-.087),(.065,-.073,-.058)],.013,mats['team'],arm)
        fore=empty('Forearm',(side*.006,-.151,-.065 if holding else -.008),arm)
        ell('Short lower animal foreleg',(.020,-.075,-.072) if holding else (side*.007,-.046,-.014),(.070,.120,.110) if holding else (.070,.093,.073),mats['fur_light'],fore,20,12)
        paw=(.046,-.164,-.173) if holding else (side*.009,-.123,-.031)
        ell('Round dark raccoon forepaw',paw,(.076,.078,.076),mats['paw'],fore,24,14)
        for j in [-1,0,1]:
            ell('Blunt paw digits',(paw[0]+j*.035,paw[1]-.016,paw[2]-.053),(.023,.040,.033),mats['paw'],fore,16,10)
        if holding:
            ell('Small grip supporting thumb',(paw[0]-.054,paw[1]+.002,paw[2]-.010),(.029,.047,.033),mats['paw'],fore,16,10)
        # Animal hock, broad paw and toes replace shorts, human calves and shoes.
        leg=empty('LegL' if side<0 else 'LegR',(side*.139,.420,.024),root)
        ell('Round furry hind haunch',(side*.013,-.032,.019),(.119,.154,.114),mats['fur'],leg,24,14)
        shin=empty('Shin',(0,-.171,0),leg)
        ell('Short sturdy furry ankle',(side*.011,-.059,.015),(.089,.108,.087),mats['fur_light'],shin,20,12)
        ell('Broad dark hind paw',(side*.010,-.168,-.044),(.111,.081,.140),mats['paw'],shin,28,16)
        for j in [-1,0,1]:
            ell('Rounded hind paw toes',(side*.010+j*.053,-.183,-.145),(.038,.054,.060),mats['paw'],shin,16,10)
        tube('Minimal mineral ankle sports band',[(-.076,-.092,-.038),(0,-.103,-.081),(.076,-.092,-.038)],.014,mats['white'],shin)
        box('Tiny team ankle marker',(side*.063,-.102,-.060),(.034,.028,.018),mats['team'],shin,.006)

    weapon=empty('Weapon',(.31,.60923076923,-.29),root)
    box('Compact sprayer lower receiver',(0,.030,-.082),(.168,.133,.228),mats['graphite'],weapon,.027)
    box('Mineral sculpted sprayer shell',(0,.086,-.095),(.178,.068,.235),mats['white'],weapon,.022)
    box('Short soft sprayer grip',(0,-.079,-.002),(.071,.152,.085),mats['graphite'],weapon,.021)
    cylinder('Pressure delivery tube',(0,.040,-.302),.052,.253,mats['metal'],weapon,axis='z',sides=28)
    annulus_z('Mineral nozzle shroud',(0,.040,-.461),.080,.055,.081,mats['white'],weapon,sides=32)
    annulus_z('Team nozzle lip',(0,.040,-.507),.057,.039,.006,mats['team'],weapon,sides=32)
    cylinder('Open nozzle dark recess',(0,.040,-.501),.038,.004,mats['black'],weapon,axis='z',sides=24)
    for side in [-1,1]:
        tube('Team pressure rail',[(side*.064,.044,-.183),(side*.061,.070,-.280),(side*.053,.052,-.389)],.009,mats['team'],weapon)
    box('Top aim rib',(0,.132,-.137),(.025,.024,.119),mats['graphite'],weapon,.006)
    empty('Muzzle',(0,.04,-.51),weapon)

    consolidate_joint_meshes()
    # Material slots are retained inside one surface mesh per articulated joint.
    bpy.context.view_layer.update()
    verts=[];triangles=0;mesh_count=0
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        mesh_count+=1;o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
        verts.extend(o.matrix_world@v.co for v in o.data.vertices)
    low=[min(v[k] for v in verts) for k in range(3)]
    high=[max(v[k] for v in verts) for k in range(3)]
    muzzle=bpy.data.objects['Muzzle'].matrix_world.translation
    gm=(muzzle.x,muzzle.z,-muzzle.y)
    summary={'species':'raccoon','team':team,'blender':bpy.app.version_string,
             'mesh_nodes':mesh_count,'triangles':triangles,
             'godot_bounds_min':[low[0],low[2],-high[1]],
             'godot_bounds_max':[high[0],high[2],-low[1]],
             'model_muzzle':list(gm),'runtime_muzzle':[gm[0]*1.3,gm[1]*1.3+.04,gm[2]*1.3],
             'root_children':sorted(o.name for o in root.children),
             'external_assets':[]}
    assert mesh_count<=25,(mesh_count,'mesh nodes')
    assert triangles<40000,(triangles,'triangles')
    assert abs(summary['godot_bounds_min'][1])<.008,summary
    assert 1.4<summary['godot_bounds_max'][1]<1.55,summary
    assert all(abs(a-b)<1e-5 for a,b in zip(summary['runtime_muzzle'],(.403,.884,-1.04))),summary
    HERE.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    (HERE/'.gdignore').touch()
    (HERE/f'raccoon_{team}_validation.json').write_text(json.dumps(summary,indent=2)+'\n')
    bpy.context.scene.render.engine='BLENDER_EEVEE_NEXT'
    bpy.context.scene.world.color=(.16,.16,.16)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/f'raccoon_{team}.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'raccoon_{team}.glb'),export_format='GLB',use_selection=False,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT')
    print('RACCOON_VALIDATION '+json.dumps(summary))

def studio_render(team):
    scene=bpy.context.scene
    # Local per-animal proof only; shared preview scene and runtime are untouched.
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64
    scene.cycles.use_denoising=False
    for name,pos,power,size in [('Key',(-3,4,6),450,4),('Fill',(3,2,3),250,3),('Rim',(1,-3,4),650,3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=pos
        o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new('Proof camera');camera=bpy.data.objects.new('Proof camera',data)
    scene.collection.objects.link(camera);scene.camera=camera
    camera.location=(-2.6,4.2,2.1);target=Vector((-.06,0,.78))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=2.05
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.095,.115,.14,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
    scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    scene.render.filepath=str(HERE/f'raccoon_{team}_proof.png')
    bpy.ops.render.render(write_still=True)

if __name__=='__main__':
    build('blue');build('orange')
    if '--render' in sys.argv:
        for team in ['blue','orange']:
            bpy.ops.wm.open_mainfile(filepath=str(HERE/f'raccoon_{team}.blend'))
            studio_render(team)
