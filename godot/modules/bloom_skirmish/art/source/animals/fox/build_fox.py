"""Original chibi fox athlete, authored in Blender 4.3.2. No external assets.
Rebuild: blender -b --python art/source/animals/fox/build_fox.py
Reusable math/mesh helpers only imported from build_athlete; its human build is never called.
Game-space coordinates below are Y-up, forward -Z; Blender conversion happens in helpers.
"""
from pathlib import Path
import sys, math, json, argparse
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ART=HERE.parents[2]
sys.path.insert(0,str(ART/'source'))
from build_athlete import material, empty, mesh, ellipsoid, loft, box, cylinder, annulus_z, xyz
OUT=ART/'models'/'animals'/'fox'
OUT.mkdir(parents=True,exist_ok=True)

def ball(n,c,s,m,p,segments=20,rings=12):
    return ellipsoid(n,c,s,m,p,segments,rings)

def tube(n,points,r,m,p):
    cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.resolution_u=5;cu.bevel_depth=r;cu.bevel_resolution=2
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for bp,pt in zip(sp.bezier_points,points):bp.co=xyz(pt);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(n,cu);bpy.context.collection.objects.link(o);o.parent=p;cu.materials.append(m);return o

def wedge(n,outline,zback,zfront,m,p,sub=1,bevel=0):
    # Purpose-sculpted convex ear / fur wedge, rounded by a single subdivision.
    cx=sum(x for x,y in outline)/len(outline);cy=sum(y for x,y in outline)/len(outline)
    vs=[(x,y,zback) for x,y in outline]+[(x,y,zfront) for x,y in outline]
    k=len(outline);vs+=[(cx,cy,zfront-.035),(cx,cy,zback+.014)]
    fs=[]
    for i in range(k):j=(i+1)%k;fs.extend([(i,j,k+j,k+i),(k+i,k+j,2*k),(j,i,2*k+1)])
    return mesh(n,vs,fs,m,p,sub=sub,bevel=bevel)

def snout(n,sections,m,p,sides=24):
    # Closed gently faceted tapered snout; sections=(z,y,rx,ry).
    vs=[];fs=[]
    for z,y,rx,ry in sections:
        for j in range(sides):
            a=math.tau*j/sides;vs.append((rx*math.cos(a),y+ry*math.sin(a),z))
    for i in range(len(sections)-1):
        for j in range(sides):fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    fs+=[tuple(reversed(range(sides))),tuple((len(sections)-1)*sides+j for j in range(sides))]
    return mesh(n,vs,fs,m,p,sub=1)

def tail_mesh(parent,orange,cream):
    # Continuous, asymmetrically swept brush silhouette, not a stack of balls.
    secs=[((0,-.20,.15),.075),((-.13,-.14,.30),.13),((-.30,-.04,.43),.22),((-.47,.10,.46),.25),((-.58,.25,.43),.21),((-.63,.38,.38),.15),((-.63,.50,.29),.075),((-.61,.57,.21),.008)]
    vs=[];fs=[];sides=20
    for i,(pos,r) in enumerate(secs):
        cur=Vector(pos);prev=Vector(secs[max(0,i-1)][0]);nxt=Vector(secs[min(len(secs)-1,i+1)][0]);tan=(nxt-prev).normalized();across=tan.cross(Vector((0,0,1))).normalized();normal=tan.cross(across).normalized()
        for j in range(sides):
            a=math.tau*j/sides;pt=cur+across*(math.cos(a)*r)+normal*(math.sin(a)*r*.76)
            # Sawtooth color transition, modeled into material assignment rather than an overlay.
            vs.append(tuple(pt))
    for i in range(len(secs)-1):
        for j in range(sides):fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    fs+=[tuple(reversed(range(sides))),tuple((len(secs)-1)*sides+j for j in range(sides))]
    ob=mesh('Continuous swept fox brush',vs,fs,orange,parent,sub=1);ob.data.materials.append(cream)
    for f in ob.data.polygons:
        if f.index//sides>=4:f.material_index=1
    return ob

def vertex_material():
    m=bpy.data.materials.new('Fox opaque vertex palette');m.use_nodes=True
    nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.66
    vc=nt.nodes.new('ShaderNodeVertexColor');vc.layer_name='Col';nt.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def merge_parts(root):
    """Apply authored surfaces then consolidate per rigid joint. All opaque colors
    become CORNER colors; only reservoir transparency retains a second material.
    Consequently rigid joints retain their pivots and no tiny-mesh draw clutter remains.
    """
    vm=vertex_material()
    parents=[o for o in root.children_recursive if o.type=='EMPTY']
    for parent in parents:
        obs=[o for o in parent.children if o.type in {'MESH','CURVE'}]
        if not obs:continue
        opaque=[]
        for o in obs:
            if any(m and m.diffuse_color[3]<.99 for m in o.data.materials):continue
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
            bpy.ops.object.convert(target='MESH');o=bpy.context.view_layer.objects.active
            ca=o.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
            colors=[tuple(m.diffuse_color) if m else (1,1,1,1) for m in o.data.materials]
            for poly in o.data.polygons:
                color=colors[poly.material_index]
                for li in poly.loop_indices:ca.data[li].color=color
                poly.material_index=0
            o.data.materials.clear();o.data.materials.append(vm);opaque.append(o)
        if opaque:
            bpy.ops.object.select_all(action='DESELECT')
            for o in opaque:o.select_set(True)
            bpy.context.view_layer.objects.active=opaque[0];bpy.ops.object.join();o=bpy.context.view_layer.objects.active
            o.name=parent.name+'_Surface'
            # Join leaves same shared material slot, collapse duplicates just in case.
            for p in o.data.polygons:p.material_index=0
            o.data.materials.clear();o.data.materials.append(vm)
    bpy.ops.object.select_all(action='DESELECT')

def build(team):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes,bpy.data.curves,bpy.data.materials):
        for datablock in list(datablocks):
            if datablock.users==0:datablocks.remove(datablock)
    tc='3269EF' if team=='blue' else 'FF8427'
    m={key:material(name,col,rough,metal,alpha) for key,name,col,rough,metal,alpha in [
        ('fur','Red fox warm orange fur','DC692B',.8,0,1),('fur_light','Sunlit fox fur','EE8A3A',.8,0,1),
        ('cream','Fox cream muzzle throat tail','FFF0D0',.82,0,1),('dark','Fox dark paws nose ear tips','392D2C',.67,0,1),
        ('crease','Paw fur creases','211C1B',.9,0,1),('inner','Warm ear interior','D88B73',.88,0,1),('ink','Graphite sporting harness','26364B',.76,0,1),
        ('team','Team equipment lacquer',tc,.32,.08,1),('white','Ivory equipment trim','E7EBDE',.67,0,1),
        ('metal','Brushed silver fittings','91A7AE',.38,.45,1),('glass','Clear compact reservoir','B8E5EA',.12,0,.22),
        ('liquid','Team nectar liquid',tc,.18,0,1),('sclera','Bright warm eye sclera','FFFAEC',.35,0,1),
        ('iris','Fox jade eyes','518D74',.32,0,1),('pupil','Expressive pupil','152C2C',.3,0,1)
    ]}
    root=empty('AthleteRoot');body=empty('Body',(0,.68,0),root)
    # Compact pear-shaped animal torso, explicitly full fur rather than human skin.
    loft('Compact fully furred fox torso',[(-.27,.115,.105,0),(-.23,.18,.14,0),(-.12,.215,.16,0),(.06,.225,.155,0),(.19,.20,.13,0),(.27,.12,.105,0),(.30,.075,.075,0)],m['fur'],body,sides=24,sub=1)
    ball('Cream furry belly',(0,-.105,-.145),(.148,.16,.035),m['cream'],body)
    # Cropped technical sport vest leaves belly, neck ruff and limbs visibly animal.
    loft('Sleeveless cropped technical vest',[(-.075,.222,.162,0),(-.045,.23,.166,0),(.10,.232,.16,0),(.20,.203,.138,0),(.235,.137,.106,0)],m['ink'],body,sides=24,sub=1)
    for s in [-1,1]:
        tube('Team vest side seam',[(s*.178,-.064,-.105),(s*.198,.06,-.114),(s*.165,.18,-.104)],.015,m['team'],body)
        tube('Harness shoulder strap',[(s*.125,.22,-.085),(s*.145,.17,.08),(s*.13,-.065,.166)],.022,m['team'],body)
    tube('Cropped vest hem',[(-.18,-.07,-.13),(0,-.075,-.17),(.18,-.07,-.13)],.013,m['white'],body)
    box('Vest zipper',(0,.065,-.168),(.012,.23,.012),m['metal'],body,.003)
    box('Compact vest pull',(.015,.15,-.18),(.022,.035,.012),m['team'],body,.005)
    # Cream neck bib sprouts organically above the sport vest.
    wedge('Pointed cream throat ruff',[(-.115,.27),(-.09,.15),(0,.09),(.09,.15),(.115,.27)],-.09,-.147,m['cream'],body,1)
    # Small sports team emblem, geometric fox chevrons rather than logos/text.
    wedge('Simple liquid drop badge',[(-.10,.13),(-.13,.075),(-.122,.05),(-.10,.043),(-.078,.05),(-.07,.075)],-.161,-.179,m['team'],body,1)
    # Liquid backpack: clearly translucent shell around level visible nectar.
    box('Backpack cradle',(0,.015,.18),(.25,.31,.055),m['ink'],body,.025)
    cylinder('Liquid in compact backpack',(0,.005,.255),.095,.23,m['liquid'],body,sides=24)
    cylinder('Visible liquid surface',(0,.122,.255),.096,.007,m['white'],body,sides=24)
    cylinder('Transparent backpack reservoir',(0,.042,.255),.118,.36,m['glass'],body,sides=24,cap=False)
    for y in [-.153,.237]:
        cylinder('Reservoir protective end',(0,y,.255),.128,.045,m['ink'],body,sides=24)
        cylinder('Team tank end ring',(0,y+.015,.255),.129,.014,m['team'],body,sides=24)
    for i in range(3):box('Tank volume gauge',(.063,-.06+i*.052,.355),(.035,.006,.008),m['white'],body,.001)
    tube('Reservoir glass glint',[(-.055,-.10,.36),(-.064,.025,.36),(-.055,.17,.36)],.005,m['white'],body)
    tube('Flexible sprayer feed',[(.11,-.13,.27),(.25,-.17,.22),(.31,-.12,.01),(.31,-.08,-.22)],.018,m['ink'],body)
    tail_mesh(body,m['fur'],m['cream'])
    head=empty('Head',(0,1.16,-.015),root)
    # Broad cranium, narrowing jaw and protruding fox muzzle: entirely animal anatomy.
    loft('Sculpted chibi fox cranium',[(-.27,.08,.095,.015),(-.23,.18,.15,.015),(-.14,.27,.20,.01),(-.02,.31,.232,.018),(.12,.30,.22,.02),(.23,.235,.18,.025),(.29,.125,.11,.02),(.31,.03,.025,.02)],m['fur'],head,sides=32,sub=1)
    # Triangular ears with dark outer tips; not added human ears or hair.
    for s in [-1,1]:
        out=[(s*.105,.205),(s*.16,.35),(s*.285,.49),(s*.345,.245)]
        wedge('Tall fox pointed ear',out,.04,-.075,m['dark'],head,0,.006)
        inner=[(s*.13,.225),(s*.19,.35),(s*.28,.455),(s*.315,.245)]
        wedge('Orange fox outer ear',inner,-.025,-.099,m['fur_light'],head,0,.004)
        core=[(s*.175,.25),(s*.225,.34),(s*.28,.415),(s*.29,.255)]
        wedge('Cream fox ear lining',core,-.095,-.113,m['cream'],head,0,.003)
        core2=[(s*.215,.255),(s*.245,.325),(s*.276,.385),(s*.28,.26)]
        wedge('Soft warm ear center',core2,-.114,-.122,m['inner'],head,0,.002)
        # Lower cheek fur is purpose-built wide pointed fan with pale muzzle coverage.
        cheek=[(s*.10,-.055),(s*.255,-.06),(s*.36,-.12),(s*.29,-.16),(s*.33,-.205),(s*.20,-.205),(s*.12,-.245),(s*.055,-.17)]
        wedge('White pointed fox cheek ruff',cheek,-.09,-.205,m['cream'],head,1)
        # Short orange cheek tuft integrates the head contour.
        wedge('Orange cheek contour',[(s*.255,.02),(s*.34,-.055),(s*.29,-.08),(s*.355,-.115),(s*.25,-.12)],-.015,-.12,m['fur_light'],head,1)
    snout('Continuous cream fox muzzle',[(-.155,-.13,.205,.105),(-.23,-.115,.17,.095),(-.31,-.095,.105,.067),(-.385,-.07,.045,.039),(-.40,-.066,.027,.024)],m['cream'],head)
    # Small rounded triangular charcoal fox nose.
    wedge('Soft triangular fox nose',[(-.055,-.043),(.055,-.043),(.043,-.077),(0,-.098),(-.043,-.077)],-.385,-.418,m['dark'],head,1)
    ball('Nose gloss',( -.012,-.046,-.43),(.013,.006,.0025),m['white'],head,12,6)
    # Large readable jade eyes, playful sly inner corners and two-point highlights.
    for s in [-1,1]:
        x=s*.145
        ball('Fox eye dark rim',(x,.035,-.203),(.082,.108,.037),m['dark'],head,24,16)
        ball('Fox bright eye white',(x,.04,-.22),(.075,.098,.032),m['sclera'],head,24,16)
        ball('Fox jade iris',(x-s*.008,.032,-.250),(.048,.069,.013),m['iris'],head,24,16)
        ball('Fox deep pupil',(x-s*.009,.03,-.261),(.026,.055,.009),m['pupil'],head,20,12)
        ball('Large eye glint',(x-.016,.062,-.272),(.016,.019,.003),m['sclera'],head,16,8)
        ball('Small eye glint',(x+.017,.003,-.271),(.007,.008,.0025),m['sclera'],head,12,6)
        # Outer lid rises, inner lid falls slightly: clever rather than angry.
        tube('Expressive upper eye lid',[(x-s*.072,.073,-.224),(x,.137,-.223),(x+s*.063,.102,-.218)],.010,m['dark'],head)
        tube('Warm expressive brow',[(x-s*.055,.168,-.184),(x,.18+(.01 if s<0 else 0),-.19),(x+s*.058,.16,-.176)],.017,m['fur_light'],head)
        # Smile corners visible to either side of the long muzzle.
        tube('Friendly fox smile corner',[(s*.022,-.14,-.326),(s*.072,-.171,-.289),(s*.132,-.151,-.254)],.0065,m['dark'],head)
    tube('Nose to smile',[(0,-.094,-.408),(0,-.124,-.368),(0,-.14,-.326)],.0055,m['dark'],head)
    # Orange forehead sweep is a fur silhouette, not human hair.
    wedge('Fox forehead fur point',[(-.075,.265),(-.045,.315),(.015,.345),(.06,.28),(.025,.255)],-.12,-.17,m['fur_light'],head,1)
    for s in [-1,1]:
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.285,.865,-.004),root)
        loft('Furred compact fox upper arm',[(.035,.057,.061,0),(.005,.079,.075,0),(-.09,.075,.07,0),(-.175,.058,.056,0)],m['fur'],arm,sides=20,sub=1)
        # Short athletic shoulder band, not human sleeves.
        loft('Compact shoulder team band',[(.015,.081,.077,0),(-.035,.082,.078,0)],m['team'],arm,sides=20,sub=1)
        fore=empty('Forearm',(0,-.15,0),arm)
        # The right forepaw is authored to wrap the fixed grip under the public
        # shoulder .50 / elbow .70 ready-pose, not merely float above the receiver.
        py,pz,px=(-.26,.08,.025) if s>0 else (-.195,-.026,0)
        lowerz=.045 if s>0 else -.012
        wristy=-.21 if s>0 else -.15
        loft('Fox orange foreleg',[(.045,.059,.057,0),(-.045,.061,.058,-.005),(wristy+.04,.051,.052,lowerz,px*.7),(wristy,.044,.047,lowerz+.012,px)],m['fur'],fore,sides=20,sub=1)
        loft('Dark fox wrist fur',[(wristy+.025,.053,.053,lowerz,px),(wristy-.015,.054,.052,pz-.015,px),(py+.02,.05,.05,pz,px)],m['dark'],fore,sides=20,sub=1)
        ball('Rounded fox paw',(px,py,pz),(.067,.068,.057),m['dark'],fore,20,12)
        ball('Paw side digit',(px-s*.047,py+.015,pz-.028),(.028,.037,.028),m['dark'],fore,16,10)
        for dx in [-.025,.022]:tube('Paw toe crease',[(px+dx,py-.003,pz-.056),(px+dx,py-.034,pz-.045)],.003,m['crease'],fore)
        tube('Wrist equipment stripe',[(px-.044,wristy+.025,lowerz-.035),(px,wristy+.022,lowerz-.048),(px+.044,wristy+.025,lowerz-.035)],.007,m['team'],fore)
        leg=empty('LegL' if s<0 else 'LegR',(s*.13,.455,.012),root)
        loft('Compact furry fox thigh',[(.045,.085,.09,0),(-.025,.098,.095,0),(-.12,.081,.076,.004),(-.205,.066,.066,0)],m['fur'],leg,sides=20,sub=1)
        shin=empty('Shin',(0,-.19,0),leg)
        loft('Short fox lower leg',[(.065,.065,.065,0),(.03,.065,.065,0),(-.06,.06,.059,0),(-.15,.051,.051,0)],m['fur'],shin,sides=20,sub=1)
        loft('Dark lower fox ankle fur',[(-.07,.063,.060,0),(-.15,.066,.068,-.015),(-.19,.075,.086,-.03)],m['dark'],shin,sides=20,sub=1)
        # Low broad animal paw feet have a true ground plane at y=0.
        loft('Grounded fox hind paw',[(-.265,.065,.105,-.05),(-.255,.084,.135,-.05),(-.225,.091,.146,-.055),(-.19,.086,.13,-.04),(-.14,.055,.07,-.006)],m['dark'],shin,sides=24,sub=1)
        for dx in [-.031,.031]:tube('Hind paw toe seam',[(dx,-.221,-.195),(dx,-.185,-.16)],.0035,m['crease'],shin)
        tube('Athletic ankle identity band',[(-.052,-.115,-.045),(0,-.12,-.064),(.052,-.115,-.045)],.009,m['team'],shin)
    # Fixed physical sprayer coordinates shared by all species.
    gun=empty('Weapon',(.31,.60923076923,-.29),root)
    box('Compact friendly sprayer receiver',(0,.035,-.09),(.195,.155,.245),m['ink'],gun,.03)
    box('Team sprayer upper shell',(0,.100,-.10),(.201,.063,.23),m['team'],gun,.022)
    box('Sprayer padded grip',(0,-.092,.012),(.074,.17,.09),m['ink'],gun,.022)
    cylinder('Sprayer barrel',(0,.04,-.322),.059,.22,m['white'],gun,axis='z',sides=24)
    annulus_z('Rounded nozzle housing',(0,.04,-.458),.081,.057,.084,m['ink'],gun,sides=24)
    annulus_z('Team spray nozzle lip',(0,.04,-.504),.057,.037,.012,m['team'],gun,sides=24)
    cylinder('Recessed sprayer opening',(0,.04,-.501),.036,.004,m['dark'],gun,axis='z',sides=20)
    for x in [-.069,.069]:tube('Pressure rails',[(x,.052,-.18),(x,.058,-.29),(x,.05,-.38)],.01,m['team'],gun)
    box('Flow indicator',(0,.145,-.105),(.035,.025,.105),m['white'],gun,.006)
    empty('Muzzle',(0,.04,-.51),gun)
    merge_parts(root)
    # Keep one packed data-only material palette and no hidden lights/cameras in export.
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT'
    bpy.context.view_layer.update()
    # Subdivision may lift a flat sole fractionally: normalize all vertices exactly to ground.
    bounds=[o.matrix_world@Vector(c) for o in root.children_recursive if o.type=='MESH' for c in o.bound_box]
    minz=min(v.z for v in bounds)
    # Don't shift pivots / muzzle; lower the hind-paw bottom vertex rings to Y=0.
    for o in root.children_recursive:
        if o.type=='MESH' and o.parent and o.parent.name.startswith('Shin'):
            for v in o.data.vertices:
                wp=o.matrix_world@v.co
                if wp.z<.016:v.co.z-=wp.z
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/f'fox_{team}.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'fox_{team}.glb'),export_format='GLB',use_selection=False,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
    meshes=[o for o in root.children_recursive if o.type=='MESH'];triangles=0
    for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    stat={'team':team,'mesh_objects':len(meshes),'triangles':triangles,'blender':bpy.app.version_string,'forward':'-Z','ground_y':0,'weapon_position':[.31,.60923076923,-.29],'muzzle_local':[0,.04,-.51],'external_assets':False}
    (HERE/f'fox_{team}_stats.json').write_text(json.dumps(stat,indent=2)+'\n')
    print('FOX_ASSET_READY '+json.dumps(stat))
    return root

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    teams=args or ['blue','orange']
    for team in teams:build(team)
