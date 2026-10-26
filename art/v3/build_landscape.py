"""Sunny Shell v3 — sculpted crescent landscape. Blender 4.3+ / CPU Cycles.
Pure Python placement API: island_boundary(theta), terrain_height(x,y), grass_mask(x,y).
Rebuild: blender -b --python art/v3/build_landscape.py
No image textures, purchased assets or primitives used as the final terrain.
"""
import math, os, json, random, sys
from pathlib import Path
TAU=math.tau
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art'/'v3'
CENTER=(0.0,1.1)
SEA_Z=-0.10
# Soft actor resting clearings, blended into the same continuous terrain mesh.
BEACH_PADS=[(-4.3,-3.0,.46,1.55,2.2),(-1.6,-3.0,.36,.70,1.15),(4.8,-2.7,.40,.50,.85)]

def clamp(v,a=0.,b=1.): return max(a,min(b,v))
def smooth(a,b,t):
    q=clamp((t-a)/(b-a)); return q*q*(3-2*q)
def mix(a,b,t): return tuple(x+(y-x)*t for x,y in zip(a,b))
def adiff(a,b): return math.atan2(math.sin(a-b), math.cos(a-b))
def island_boundary(theta):
    r=1/math.sqrt((math.cos(theta)/10.9)**2+(math.sin(theta)/7.25)**2)
    # Deliberately asymmetrical open cove rather than a scaled ellipse.
    cove=.40*math.exp(-(adiff(theta,-1.43)/.40)**2)
    lobes=1+.065*math.sin(3*theta+.7)+.025*math.sin(7*theta-1.1)+.012*math.sin(13*theta)
    return r*lobes*(1-cove)
_OUTLINE=[(CENTER[0]+island_boundary(i*TAU/192)*math.cos(i*TAU/192), CENTER[1]+island_boundary(i*TAU/192)*math.sin(i*TAU/192)) for i in range(192)]
_SEGMENTS=[(a[0],a[1],b[0]-a[0],b[1]-a[1],(b[0]-a[0])**2+(b[1]-a[1])**2) for a,b in zip(_OUTLINE,_OUTLINE[1:]+_OUTLINE[:1])]
def edge_distance(x,y):
    # True signed polygon distance removes directional seams at the polar origin.
    best=1e9
    for ax,ay,dx,dy,ll in _SEGMENTS:
        u=clamp(((x-ax)*dx+(y-ay)*dy)/ll)
        ds=(x-ax-u*dx)**2+(y-ay-u*dy)**2
        if ds<best:best=ds
    t=math.atan2(y-CENTER[1],x-CENTER[0])
    sign=1 if math.hypot(x-CENTER[0],y-CENTER[1])<island_boundary(t) else -1
    return sign*math.sqrt(best)
def grass_boundary(x,y):
    # Wide southern crescent, narrower turf-covered rear rock shoulders.
    return 1.35+.95*(1-smooth(-3.6,1.2,y))+.20*math.sin(x*1.05+y*.31)+.10*math.sin(x*2.1-y*.65)
def grass_mask(x,y):
    g=smooth(-.10,.15,edge_distance(x,y)-grass_boundary(x,y))
    for px,py,z,inner,outer in BEACH_PADS:
        g*=smooth(inner,outer,math.hypot(x-px,y-py))
    return g
def terrain_height(x,y):
    d=edge_distance(x,y)
    beach=-.29+.73*smooth(-.08,2.30,d)
    inland=smooth(1.5+.65*(1-smooth(-3,1,y)),4.3,d)
    # Broad overlapping hills produce readable rolling volumes, not cake tiers.
    hills=.66 + 1.21*math.exp(-(((x+3.1)/4.6)**2+((y-3.5)/3.9)**2)) + 1.48*math.exp(-(((x-3.3)/3.8)**2+((y-3.9)/3.1)**2))
    roll=.09*math.sin(x*.63+y*.34)+.055*math.sin(y*1.05-x*.31)
    # Small wind-built dune variation on broad sand is much smaller than the hill.
    dune=.07*math.sin(x*.9+.4)*math.exp(-((d-1.25)/.8)**2)
    height=beach+inland*(hills+roll)+dune
    for px,py,z,inner,outer in BEACH_PADS:
        weight=(1-smooth(inner,outer,math.hypot(x-px,y-py)))*smooth(.2,.70,d)
        height=height+(z-height)*weight
    return height


def shoreline_radius(theta):
    """Exact calm-water coast radius; solves terrain_height == SEA_Z."""
    low,high=0.,island_boundary(theta)
    for _ in range(42):
        r=(low+high)/2
        z=terrain_height(CENTER[0]+r*math.cos(theta), CENTER[1]+r*math.sin(theta))
        if z>SEA_Z: low=r
        else: high=r
    return (low+high)/2

def write_contract():
    coast=[];mesh_boundary=[]
    for i in range(256):
        theta=i*TAU/256
        def xy(r):return [CENTER[0]+r*math.cos(theta),CENTER[1]+r*math.sin(theta)]
        coast.append(xy(shoreline_radius(theta)));mesh_boundary.append(xy(island_boundary(theta)))
    data={'coordinate_system':'Blender Z up, XY ground, front negative Y; Godot (x,z,-y)',
          'sea_z':SEA_Z,'center_xy':CENTER,'dry_shoreline_xy':coast,'land_boundary_xy':mesh_boundary,
          'boundary_note':'dry_shoreline_xy solves terrain_height=sea_z; land_boundary_xy is submerged solid mesh edge.',
          'height_source':'art/v3/build_landscape.py pure Python terrain_height, shoreline_radius, edge_distance, island_boundary, grass_mask',
          'placements':{n:[x,y,terrain_height(x,y)] for n,(x,y) in PLACEMENTS.items()},
          'export_collection':'V3 LANDSCAPE • sculpted cove','terrain_object':'Cove terrain • single continuous sculpted solid',
          'ocean_object':'Ocean • seamless depth graded lagoon','foam_prefix':'Cove foam • tapered arc',
          'source_blend':'art/v3/landscape.blend','glb':'art/v3/landscape.glb'}
    (OUT/'landscape_contract.json').write_text(json.dumps(data,indent=2))
    return data

PLACEMENTS={
 'palm_hero_left':[-5.1,2.3], 'palm_back_left':[-2.4,5.0], 'palm_back_right':[2.2,5.1],
 'palm_right':[6.1,1.7], 'palm_left_tip':[-7.2,-.1],
 'fern_left':[-5.8,.35], 'fern_mid':[-1.1,2.6], 'fern_right':[4.9,.4],
 'turtle_beach':[-4.3,-3.0], 'crab_beach':[-1.6,-3.0], 'gull_beach':[4.8,-2.7]
}

def build():
    import bpy
    from mathutils import Vector
    rng=random.Random(83)
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
        for block in list(datablocks):
            if block.users==0:datablocks.remove(block)
    scene=bpy.context.scene
    collection=bpy.data.collections.new('V3 LANDSCAPE • sculpted cove');scene.collection.children.link(collection)
    def move(o):
        for c in list(o.users_collection):c.objects.unlink(o)
        collection.objects.link(o);return o
    def mat(name,color,rough=.62,metal=0.):
        m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
        p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
        return m
    sand=mat('Warm ivory • continuous beach',(.76,.51,.25))
    ground=mat('Hand-sculpted terrain • vertex painted',(.1,.4,.16))
    n=ground.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Palette'
    ground.node_tree.links.new(n.outputs['Color'],ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    palette={
     'grass':(.065,.32,.085),'grass_sun':(.16,.44,.08),'sand':(.76,.54,.27),
     'wet':(.50,.35,.16),'stone':(.23,.35,.32),'stone_light':(.34,.45,.36),'stone_dark':(.17,.25,.26),
     'wood':(.34,.16,.065),'wood_sun':(.51,.28,.12),'wood_honey':(.44,.215,.085),
     'endgrain':(.60,.36,.17),'grain':(.20,.085,.035),'rope':(.69,.47,.23),
     'shell_cream':(.95,.79,.51),'shell_coral':(.87,.25,.12),'shell_ridge':(.99,.56,.30),
     'foam':(.53,.91,.79),'iron':(.055,.11,.105),'sign':(.08,.29,.25)
    }
    materials={k:mat('V3 '+k,v,.7 if k not in ['iron'] else .35) for k,v in palette.items()}
    water=mat('Lagoon • continuous teal depth',(.015,.35,.38),.22)
    wn=water.node_tree.nodes;wp=wn.get('Principled BSDF');wp.inputs['Coat Weight'].default_value=.32;wp.inputs['Coat Roughness'].default_value=.18
    wc=wn.new('ShaderNodeVertexColor');wc.layer_name='Palette';water.node_tree.links.new(wc.outputs['Color'],wp.inputs['Base Color'])
    noise=wn.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2.8;noise.inputs['Detail'].default_value=2
    bump=wn.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.13;bump.inputs['Distance'].default_value=.065
    water.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);water.node_tree.links.new(bump.outputs['Normal'],wp.inputs['Normal'])
    def mesh(name,verts,faces,material,smoothnorm=True):
        me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
        o=bpy.data.objects.new(name,me);collection.objects.link(o)
        if material:o.data.materials.append(material)
        for p in me.polygons:p.use_smooth=smoothnorm
        return o
    def colors(o,cols):
        ca=o.data.color_attributes.new(name='Palette',type='FLOAT_COLOR',domain='POINT')
        for d,c in zip(ca.data,cols):d.color=(*c,1)
    def tube(name,points,radii,ma,sides=10):
        vs=[]
        for i,p in enumerate(points):
            p=Vector(p);v=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)]);v.normalize()
            ref=Vector((0,0,1)) if abs(v.z)<.9 else Vector((0,1,0));u=v.cross(ref).normalized();w=v.cross(u).normalized()
            r=radii[i] if isinstance(radii,list) else radii
            for j in range(sides):vs.append(tuple(p+r*(math.cos(j*TAU/sides)*u+math.sin(j*TAU/sides)*w)))
        fs=[tuple(range(sides-1,-1,-1))]
        for i in range(len(points)-1):
            for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;fs.append((a,b,b+sides,a+sides))
        fs.append(tuple((len(points)-1)*sides+j for j in range(sides)))
        return mesh(name,vs,fs,ma)
    def bevel(o,width=.07,segments=3):
        mod=o.modifiers.new('Soft hand-finished edges','BEVEL');mod.width=width;mod.segments=segments
        mod.affect='EDGES'
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        return o
    def box(name,loc,scale,ma,rotation=0,width=.04):
        bpy.ops.mesh.primitive_cube_add(size=2,location=loc);o=move(bpy.context.object);o.name=name;o.scale=scale;o.rotation_euler.z=rotation
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma);bevel(o,width,3)
        return o
    # Continuous manifold surface: 72 radii × 256 angular samples, stitched to a submerged skirt.
    N=256;R=72;verts=[(CENTER[0],CENTER[1],terrain_height(*CENTER))];cols=[]
    def terrain_color(x,y):
        d=edge_distance(x,y);g=grass_mask(x,y)
        dune=mix(palette['wet'],palette['sand'],smooth(.1,1.1,d))
        light=.5+.5*math.sin(x*.42+y*.54)*math.cos(y*.21-x*.17)
        turf=mix(palette['grass'],palette['grass_sun'],.36*light)
        return mix(dune,turf,g)
    cols=[terrain_color(*CENTER)]
    for j in range(1,R+1):
        q=j/R
        for i in range(N):
            t=i*TAU/N;r=island_boundary(t)*q
            x=CENTER[0]+r*math.cos(t);y=CENTER[1]+r*math.sin(t)
            verts.append((x,y,terrain_height(x,y)));cols.append(terrain_color(x,y))
    fs=[]
    for i in range(N):fs.append((0,1+i,1+(i+1)%N))
    for j in range(R-1):
        for i in range(N):a=1+j*N+i;b=1+j*N+(i+1)%N;fs.append((a,a+N,b+N,b))
    skirt=len(verts)
    for i in range(N):
        x,y,z=verts[1+(R-1)*N+i];verts.append((x*.96,y*.96,-1.35));cols.append(palette['wet'])
    for i in range(N):a=1+(R-1)*N+i;b=1+(R-1)*N+(i+1)%N;fs.append((a,skirt+i,skirt+(i+1)%N,b))
    fs.append(tuple(skirt+i for i in reversed(range(N))))
    terrain=mesh('Cove terrain • single continuous sculpted solid',verts,fs,ground);colors(terrain,cols)
    terrain['placement_api']='build_landscape.terrain_height(x, y)';terrain['design']='One continuous terrain: sandy cove slopes into rolling emerald hills.'
    # Large seamless water field: a continuous depth-color gradient, not stacked discs.
    V=[];C=[];F=[];S=124;extent=38
    for j in range(S+1):
        y=-extent+2*extent*j/S
        for i in range(S+1):
            x=-extent+2*extent*i/S;d=edge_distance(x,y)
            near=math.exp(-max(0,-d)**2/7.2)
            c=mix((.009,.235,.29),(.055,.51,.44),near*.85)
            V.append((x,y,SEA_Z));C.append(c)
    for j in range(S):
        for i in range(S):a=j*(S+1)+i;F.append((a,a+1,a+S+2,a+S+1))
    ocean=mesh('Ocean • seamless depth graded lagoon',V,F,water);colors(ocean,C)
    # Sculpted outcrops: original skewed clay blocks, not scattered UV spheres.
    def rock(name,loc,scale,seed):
        # Hand-shaped clay blocks: no spherical balls or sedimentary ring bands.
        rr=random.Random(seed);vs=[]
        for z,fac in [(-.70,.82),(.74,.94)]:
            for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                vs.append((scale[0]*(x*fac+rr.uniform(-.09,.09)+.08*z),scale[1]*(y*fac+rr.uniform(-.09,.09)-.07*z),scale[2]*(z+rr.uniform(-.08,.08))))
        fs=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
        o=mesh(name,vs,fs,materials['stone'],True);o.location=loc;o.rotation_euler=(rr.uniform(-.06,.06),rr.uniform(-.09,.09),rr.uniform(-.4,.4))
        o.data.materials.append(materials['stone_light']);o.data.materials.append(materials['stone_dark'])
        for p in o.data.polygons:p.material_index=1 if p.index==5 else 0
        bevel(o,min(scale)*.46,5);return o
    outcrops=[
      ('West cliff master',(-8.4,2.5,.49),(1.35,1.60,1.20),31),
      ('West cliff shoulder',(-7.8,4.1,.75),(1.12,1.2,1.12),33),
      ('West cliff toe',(-9.65,1.8,.08),(.87,1.08,.71),34),
      ('East cliff master',(8.38,1.9,.54),(1.32,1.50,1.28),41),
      ('East cliff saddle',(7.5,3.5,.89),(1.36,1.37,1.11),43),
      ('East cliff toe',(9.45,.58,.12),(.78,1.13,.71),44),
      ('Rear rock shoulder',(-.6,7.28,1.01),(1.34,1.02,1.28),51),
      ('Rear low slab',(1.1,7.28,.75),(1.23,.84,.86),52),
      ('Cove right sandstone',(7.48,-2.77,.40),(.96,.68,.76),61),
      ('Cove right toe',(8.37,-3.04,.09),(.58,.45,.44),62)
    ]
    for name,loc,sc,seed in outcrops:rock(name,loc,sc,seed)
    # Curved timber pier. Every board is a rounded solid, spaced and gently weathered.
    def dockpath(t):return Vector((-7.25-4.05*t,-2.12-2.88*t+.74*math.sin(math.pi*t),.48+.12*math.sin(math.pi*t)))
    def dockframe(t):
        d=(dockpath(min(1,t+.002))-dockpath(max(0,t-.002))).normalized();side=Vector((-d.y,d.x,0));return d,side
    count=19
    for j in range(count):
        t=j/(count-1);p=dockpath(t);d,s=dockframe(t);angle=math.atan2(s.y,s.x)
        ma=materials[['wood_honey','wood_sun','wood'][j%3]]
        o=box(f'Pier board {j+1:02d} • softened timber',p,(.91+rng.uniform(-.05,.05),.126,.105),ma,angle+rng.uniform(-.012,.012),.055)
        # Two slender open surface grains, not texture noise.
        for k in []: # Fine wood grain intentionally omitted for Q / toy style.
            q=p+s*(-.65)+d*(k*.045);pts=[]
            for h in range(7):
                u=h/6;v=q+s*(1.3*u)+d*(.018*math.sin(u*math.pi*2+j));v.z=p.z+.108;pts.append(v)
            tube(f'Pier board {j+1:02d} grain {k}',pts,.0065,materials['grain'],5)
        for sign in [-1,1]:
            q=p+s*(sign*.69);q.z=p.z+.113
            tube('Dark wooden peg',[q,q+Vector((0,0,.012))],.027,materials['iron'],8)
    # Structural under-beams follow the bend, and remain visible in the water.
    for sign in [-1,1]:
        pts=[]
        for j in range(13):
            t=j/12;p=dockpath(t);_,s=dockframe(t);p+=s*(sign*.57);p.z-=.20;pts.append(p)
        tube('Curved structural bearer',pts,.12,materials['wood'],10)
    posts={}
    for j,t in enumerate([.05,.38,.70,1.]):
        p=dockpath(t);_,s=dockframe(t)
        for sign in [-1,1]:
            q=p+s*(sign*.94);top=q+Vector((0,0,.65 if j in [0,3] else .57))
            tube('Pier mooring post',[(q.x,q.y,-.74),(q.x+.025,q.y+.012,top.z)],[.105,.125],materials['wood_honey'],12)
            tube('Post endgrain cap',[(top.x,top.y,top.z),(top.x,top.y,top.z+.035)],[.125,.115],materials['endgrain'],12)
            # Small top ring hints the timber cross-section.
            pts=[(top.x+.075*math.cos(h*TAU/20),top.y+.075*math.sin(h*TAU/20),top.z+.038) for h in range(21)]
            tube('Post growth ring',pts,.006,materials['wood'],5);posts[j,sign]=top
    # Only outer safety rope, keeping the beach approach open.
    for sign in [-1,1]:
        for j in range(3):
            a=posts[j,sign];b=posts[j+1,sign];pts=[]
            for h in range(19):
                u=h/18;q=a.lerp(b,u);q.z-=.16+.22*math.sin(math.pi*u);pts.append(q)
            tube('Loose natural fibre railing',pts,.035,materials['rope'],8)
        for j in [0,3]:
            p=posts[j,sign];pts=[]
            for h in range(49):
                u=h/48;angle=TAU*2*u;pts.append((p.x+.136*math.cos(angle),p.y+.136*math.sin(angle),p.z-.23+.11*u))
            tube('Rope lashing at pier post',pts,.023,materials['rope'],7)
    # A neat welcome sign is an authored focal prop near the pier approach.
    sx,sy=-6.15,-1.90;sz=terrain_height(sx,sy)
    tube('Beach sign • forked oak post',[(sx,sy,sz-.13),(sx+.05,sy,sz+1.16)],[.075,.065],materials['wood'],10)
    board=box('Beach sign • weathered direction board',(sx,sy,sz+.93),(.57,.085,.24),materials['sign'],-.12,.09)
    # Wood inlay sun and three rounded crest strokes: no illegible text.
    for k in range(3):
        pts=[]
        for j in range(15):
            u=j/14;pts.append((sx-.31+u*.60,sy-.091,sz+.83+k*.075+.022*math.sin(u*TAU)))
        tube('Sign • wave inlay',pts,.012,materials['shell_cream'],6)
    # Shells are solid scalloped fans with raised radial ribs, organized into two tiny beach stories.
    def shell(name,loc,scale,rot,coral=False):
        vs=[];fs=[];radial=6;ang=24
        for r in range(radial+1):
            u=r/radial
            for j in range(ang+1):
                a=-.15+1.30*math.pi*j/ang;scallop=1+.07*math.cos(j/ang*math.pi*12)*u**3
                x=u*.37*math.cos(a)*scallop;y=u*.39*math.sin(a)*scallop
                z=.11*math.sin(u*math.pi*.8)+.022*math.cos(j/ang*math.pi*12)*u
                vs.append((x,y,z))
        for r in range(radial):
            for j in range(ang):a=r*(ang+1)+j;fs.append((a,a+1,a+ang+2,a+ang+1))
        o=mesh(name,vs,fs,materials['shell_coral' if coral else 'shell_cream']);o.location=loc;o.scale=(scale,scale,scale);o.rotation_euler.z=rot
        so=o.modifiers.new('Thick pearly shell rim','SOLIDIFY');so.thickness=.025
        bevel(o,.009,2)
        for j in range(0): # Keep clean shell silhouette, no micro-rib realism.
            a=-.15+1.30*math.pi*j/6;pts=[]
            for k in range(8):
                u=.12+.83*k/7;x=u*.37*math.cos(a);y=u*.39*math.sin(a);z=.11*math.sin(u*math.pi*.8)+.028
                xx=loc[0]+scale*(x*math.cos(rot)-y*math.sin(rot));yy=loc[1]+scale*(x*math.sin(rot)+y*math.cos(rot));zz=loc[2]+scale*z
                pts.append((xx,yy,zz))
            tube(name+' • sculpted rib',pts,.008*scale,materials['shell_ridge' if coral else 'endgrain'],6)
    for i,(x,y,sc,rot,coral) in enumerate([(-4.55,-3.63,.78,.3,False),(-4.12,-3.46,.47,-.7,True),(5.5,-3.63,.64,.2,True),(5.99,-3.42,.45,1.7,False)]):
        shell(f'Scallop story {i+1}',(x,y,terrain_height(x,y)+.025),sc,rot,coral)
    for i,(x,y,s) in enumerate([(-4.82,-3.39,.13),(-4.35,-3.75,.09),(5.74,-3.19,.12),(6.12,-3.62,.095),(-8.8,-.8,.22),(-8.45,-.61,.16)]):
        rock('Selected tide pebble',(x,y,terrain_height(x,y)+s*.28),(s,s*.72,s*.40),120+i)
    # Fine discontinuous foam follows only three coves; no closed graphic outline.
    for idx,(a,b,offset) in enumerate([(-2.67,-2.02,-.16),(-1.92,-1.38,-.23),(-1.20,-.57,-.12),(-2.41,-2.15,-.49),(-1.73,-1.49,-.62)]):
        vs=[];fs=[];steps=52
        for j in range(steps+1):
            u=j/steps;t=a+(b-a)*u;r=island_boundary(t)-offset
            width=.055*math.sin(math.pi*u)**.55
            for dr in [-width,width]:vs.append(((r+dr)*math.cos(t),(r+dr)*math.sin(t)+CENTER[1],SEA_Z+.014))
        for j in range(steps):fs.append((j*2,j*2+1,j*2+3,j*2+2))
        mesh(f'Cove foam • tapered arc {idx+1}',vs,fs,materials['foam'])
    # Lighting is deliberately clear and saturated, with contact shadows that reveal sculpting.
    world=bpy.data.worlds.new('Warm marine studio');scene.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.38,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.42
    def area(name,location,power,size,color):
        bpy.ops.object.light_add(type='AREA',location=location);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((0,1,1.5))-o.location).to_track_quat('-Z','Y').to_euler();return o
    area('Key • golden coastal sun',(-9,-12,19),2100,9,(1.,.88,.67))
    area('Fill • blue open sky',(13,3,14),1500,11,(.62,.83,1.))
    bpy.ops.object.light_add(type='SUN',location=(0,0,15));sun=bpy.context.object;sun.name='Sun • readable soft shadows';sun.data.energy=1.8;sun.data.angle=.20;sun.rotation_euler=(.40,-.45,-.55)
    bpy.ops.object.camera_add(location=(18,-24,19));cam=bpy.context.object;cam.name='CAM • v3 landscape';cam.rotation_euler=(Vector((-1,.8,1.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=31;scene.camera=cam
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False
    scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=.35
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'landscape_preview.png');scene.render.film_transparent=False
    scene['V3']='Premium sculpted crescent cove; all original meshes and reproducible Python source.'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'landscape.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for o in collection.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'landscape.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_materials='EXPORT')
    stats={'objects':len(collection.objects),'mesh_objects':sum(o.type=='MESH' for o in collection.objects),'vertices':sum(len(o.data.vertices) for o in collection.objects if o.type=='MESH'),'terrain_dimensions':list(terrain.dimensions),'placements':{n:[x,y,terrain_height(x,y)] for n,(x,y) in PLACEMENTS.items()},'render':{'engine':'Cycles CPU','samples':48,'denoising':False,'size':[1280,960]}}
    (OUT/'landscape_manifest.json').write_text(json.dumps(stats,indent=2))
    write_contract()
    if '--no-render' not in sys.argv:bpy.ops.render.render(write_still=True)
    print('LANDSCAPE_COMPLETE '+json.dumps(stats))

if __name__=='__main__': build()
