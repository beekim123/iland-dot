"""Embed the separately authored v3 assets and render honest Blender approval views.

Run with Blender 4.3.2:
  blender -b -t 8 --python art/v3/assemble_scene.py -- --draft
  blender -b -t 8 --python art/v3/assemble_scene.py

All source meshes/materials are appended (not externally linked). Render-only water,
lights and cameras stay in the .blend but are excluded from the portable GLB.
"""
from pathlib import Path
import argparse
import bpy
import json
import math
import sys
import importlib.util
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art' / 'v3'
ARGS = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--draft', action='store_true')
parser.add_argument('--view', choices=['all', 'overview', 'closeup'], default='all')
parser.add_argument('--assemble-only', action='store_true')
args = parser.parse_args(ARGS)

# These filenames are the hand-off contract; all v3 source data stays independent.
SOURCES = {
    'Landscape': ART / 'landscape.blend',
    'Plants': ART / 'plants.blend',
    'Animals': ART / 'animals.blend',
}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
stage = bpy.data.collections.new('Render Stage (excluded from GLB)')
scene.collection.children.link(stage)


def append_asset(label, filepath):
    if not filepath.exists():
        raise FileNotFoundError(f'Missing approved source: {filepath}')
    group = bpy.data.collections.new(f'V3 {label}')
    scene.collection.children.link(group)
    with bpy.data.libraries.load(str(filepath), link=False) as (src, dst):
        dst.objects = [name for name in src.objects if not name.lower().startswith('studio')]
    objects = []
    for ob in dst.objects:
        if ob is None:
            continue
        if ob.type in {'CAMERA', 'LIGHT'} or ob.get('render_only'):
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        group.objects.link(ob)
        objects.append(ob)
    return group, objects


def matte(name, color, roughness=0.7):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    return material


def link_stage(ob):
    for col in list(ob.users_collection):
        col.objects.unlink(ob)
    stage.objects.link(ob)
    ob['render_only'] = True
    return ob


def point_at(ob, target):
    ob.rotation_euler = (Vector(target)-ob.location).to_track_quat('-Z', 'Y').to_euler()


def add_area(name, position, power, size, color, target=(0, 0, 0)):
    data = bpy.data.lights.new(name, type='AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    data.color = color
    ob = bpy.data.objects.new(name, data)
    stage.objects.link(ob)
    ob.location = position
    ob['render_only'] = True
    point_at(ob, target)
    return ob


def world_bbox(objects):
    return [ob.matrix_world @ Vector(p) for ob in objects if ob.type == 'MESH' and not ob.hide_render for p in ob.bound_box]


def add_camera(name, location, target, scale=30, fit_objects=None, margin=1.12):
    data = bpy.data.cameras.new(name)
    data.type = 'ORTHO'
    data.lens = 50
    data.ortho_scale = scale
    data.clip_end = 500
    ob = bpy.data.objects.new(name, data)
    stage.objects.link(ob)
    ob.location = location
    ob['render_only'] = True
    point_at(ob, target)
    bpy.context.view_layer.update()
    if fit_objects:
        points = world_bbox(fit_objects)
        invrot = ob.rotation_euler.to_matrix().transposed()
        projected = [invrot @ (p-Vector(target)) for p in points]
        lo = Vector(tuple(min(p[i] for p in projected) for i in range(3)))
        hi = Vector(tuple(max(p[i] for p in projected) for i in range(3)))
        offset = ob.rotation_euler.to_matrix() @ Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, 0))
        ob.location += offset
        aspect = scene.render.resolution_x / scene.render.resolution_y
        data.ortho_scale = max(hi.x-lo.x, (hi.y-lo.y)*aspect) * margin
    return ob


groups = {}
asset_objects = []
for label, filepath in SOURCES.items():
    groups[label], obs = append_asset(label, filepath)
    asset_objects.extend(obs)

# Asset-specific placement is inserted below after the source workers' hand-off.
# BEGIN PLACEMENT
spec = importlib.util.spec_from_file_location('v3_terrain', ART/'build_landscape.py')
terrain_api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terrain_api)
placements = []
plant_templates = {ob.name: ob for ob in list(groups['Plants'].objects) if ob.type == 'EMPTY' and ob.parent is None}

def instantiate(name, asset, xy, scale=1.0, yaw=0.0):
    template = plant_templates[asset]
    sources = [template] + list(template.children_recursive)
    mapping = {}
    for src in sources:
        ob = src.copy()
        ob.name = name if src == template else name+' / '+src.name
        groups['Plants'].objects.link(ob)
        mapping[src] = ob
    for src,ob in mapping.items():
        ob.parent = mapping.get(src.parent)
    root = mapping[template]
    root.location = (*xy, terrain_api.terrain_height(*xy)-0.035)
    root.rotation_euler = (0, 0, yaw)
    root.scale = (scale,)*3
    asset_objects.extend(mapping.values())
    placements.append({'name':name,'asset':asset,'position':list(root.location),'scale':scale,'yaw':yaw})
    return root

# Three linked canopy masses with a dominant left/back group, not an even ring.
for n,a,xy,s,yaw in [
    ('Hero curved palm','Palm_A',(-5.2,2.5),1.00,-.55),
    ('Companion high palm','Palm_B',(-2.5,4.7),.90,.50),
    ('Rear canopy palm','Palm_C',(1.7,4.8),.92,-.30),
    ('Right sentinel palm','Palm_B',(5.7,1.9),.80,-.55),
    ('Left leaning young palm','Palm_C',(-7.2,-.1),.70,1.05),
    ('Right young palm','Palm_C',(6.5,-.15),.59,-1.00),
]: instantiate(n,a,xy,s,yaw)

# Purposeful broadleaf understory: overlapping large and small leaves form coherent islands.
for n,xy,rotation,size in [
    ('Left grove',(-5.4,.8),.3,1.35),
    ('Left inner grove',(-3.8,2.6),-.5,1.30),
    ('Rear saddle grove',(-.8,3.9),.8,1.20),
    ('Right grove',(5.25,.7),-.8,1.35),
    ('Right back grove',(4.0,3.2),.4,1.20),
]:
    x,y=xy
    instantiate(n+' broadleaf','Foliage_Monstera',(x,y),size,rotation)
    instantiate(n+' upright','Foliage_Banana',(x+.58,y+.30),size*.93,rotation+1.2)
    instantiate(n+' fern','Fern_A',(x-.52,y-.42),size*.75,rotation-.7)
    instantiate(n+' flowers','Shrub_Coral' if 'Left' in n else 'Shrub_Cream',(x+.20,y-.53),size*.85,rotation+.4)

for n,asset,xy,s,rot in [
    ('Left beach edge flowers','Shrub_Cream',(-5.55,-1.55),1.08,-.5),
    ('Left beach broadleaf','Foliage_Banana',(-6.4,-1.0),1.12,.5),
    ('Cove left fern','Fern_A',(-3.20,-1.5),.95,-.4),
    ('Cove inner flowers','Shrub_Coral',(-.8,-.6),1.10,.5),
    ('Cove right flowers','Shrub_Coral',(4.5,-1.15),1.00,-.6),
    ('Cove right broadleaf','Foliage_Monstera',(5.2,-1.0),1.12,.3),
]: instantiate(n,asset,xy,s,rot)

# Only a few well-scaled tufts at transitions; no confetti carpet.
for i,(x,y,scale) in enumerate([(-6.6,-1.3,1.2),(-5.1,-1.7,1.0),(-3.5,-1.8,.8),(-1.9,.1,.9),(3.9,-1.1,.9),(5.6,-.8,1.0),(6.6,.2,.8)]):
    instantiate('Selected grass tuft %02d'%i,'Grass_A',(x,y),scale,i*.7)

# Remove the studio templates now their actual geometry is instanced in the landscape.
original_plants = [ob for root in plant_templates.values() for ob in [root]+list(root.children_recursive)]
for ob in original_plants:
    if ob in asset_objects: asset_objects.remove(ob)
    bpy.data.objects.remove(ob, do_unlink=True)

# Character roots are authored at foot Z=0 and forward -Y.
actor_specs = [
    ('TurtleRoot',(-4.3,-3.0),1.65,-.24),
    ('CrabRoot',(-1.6,-3.0),1.72,.16),
    ('SeagullRoot',(4.8,-2.7),1.70,-.58),
]
for name,xy,scale,yaw in actor_specs:
    actor = bpy.data.objects.get(name)
    if actor:
        actor.location = (*xy,terrain_api.terrain_height(*xy)+.035)
        actor.rotation_euler = (0,0,yaw)
        actor.scale = (scale,)*3
        placements.append({'name':name,'asset':name,'position':list(actor.location),'scale':scale,'yaw':yaw})
# The fish stays available/editable in the master, in a little visible shallow-water pair.
fish = bpy.data.objects.get('FishRoot')
if fish:
    fish.location = (1.5,-5.5,-.035)
    fish.rotation_euler = (0,0,-1.05)
    fish.scale = (1.3,)*3
    # Ocean is opaque by design, so swimming fish are not faked above it for this view.
    fish.hide_render = True
    for child in fish.children_recursive: child.hide_render = True

# The authored graded ocean is rendering context, not geometry for runtime import.
authored_ocean = bpy.data.objects.get('Ocean • seamless depth graded lagoon')
if authored_ocean:
    link_stage(authored_ocean)
    asset_objects.remove(authored_ocean)
    for mat in authored_ocean.data.materials:
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == 'BUMP': node.inputs['Strength'].default_value = 0.0
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value = 0.82
                    node.inputs['Specular IOR Level'].default_value = 0.0
                    node.inputs['Coat Weight'].default_value = 0.0
(ART/'assembly_placements.json').write_text(json.dumps(placements,indent=2))
# END PLACEMENT

bpy.context.view_layer.update()

# A calm continuous teal ocean, without noisy particles/glints or a visible plane edge.
bpy.ops.mesh.primitive_plane_add(size=250, location=(0, 0, -0.115))
ocean = link_stage(bpy.context.object)
ocean.name = 'Render ocean — quiet teal context only'
ocean.data.materials.append(matte('Render ocean teal', (0.009, 0.235, 0.29), 0.85))
water_bsdf = ocean.data.materials[0].node_tree.nodes.get('Principled BSDF')
water_bsdf.inputs['Specular IOR Level'].default_value = 0.0

# Deliberately lower ambience than v1: warm key, restrained cool fill, readable forms.
scene.world = bpy.data.worlds.new('Soft tropical daylight')
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value = (0.50, 0.64, 0.72, 1)
bg.inputs['Strength'].default_value = 0.42
add_area('Key — broad warm sunlight', (-10, -12, 18), 2900, 10, (1.0, 0.83, 0.64))
add_area('Fill — gentle sky', (9, -1, 13), 1200, 12, (0.67, 0.83, 1.0))
add_area('Rim — canopy separation', (-5, 10, 17), 1700, 9, (1.0, 0.93, 0.78))

sun_data = bpy.data.lights.new('Soft morning sun', type='SUN')
sun_data.energy = 0.8
sun_data.angle = math.radians(24)
sun_data.color = (1.0, 0.90, 0.75)
sun = bpy.data.objects.new('Soft morning sun', sun_data)
stage.objects.link(sun)
sun['render_only'] = True
sun.rotation_euler = (math.radians(23), math.radians(-28), math.radians(-30))

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24 if args.draft else 64
scene.cycles.use_denoising = False  # This CPU build does not support OpenImageDenoise.
scene.cycles.use_adaptive_sampling = True
scene.cycles.adaptive_threshold = 0.04 if args.draft else 0.015
scene.cycles.max_bounces = 6
scene.cycles.diffuse_bounces = 3
scene.cycles.glossy_bounces = 3
scene.render.resolution_x = 1000 if args.draft else 1600
scene.render.resolution_y = 750 if args.draft else 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '8'
scene.render.film_transparent = False
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.10
scene.view_settings.gamma = 1
scene.render.image_settings.compression = 15

model_meshes = [ob for ob in asset_objects if ob.type == 'MESH']
overview = add_camera('01 — Island composition', (18, -29, 24), (0, 0, 1.5), fit_objects=model_meshes, margin=1.09)
closeup = add_camera('02 — Sculpted friends and beach', (5, -20, 11), (-0.2, -2.2, 0.9), scale=13.2)
scene.camera = overview
suffix = '_draft' if args.draft else ''
scene.render.filepath = str(ART/f'island_v3_overview{suffix}.png')

# Verify real model content and record measurements, not a render-only substitute.
# Blender retains empty Library datablocks after an append until orphan purge.
bpy.ops.object.make_local(type='ALL')
bpy.ops.outliner.orphans_purge(do_recursive=True)
linked_ids = [(kind, item.name, item.library.filepath) for kind in ['objects','meshes','materials','collections','images','node_groups','worlds','curves','armatures','textures','cameras','lights','actions','scenes'] for item in getattr(bpy.data,kind) if item.library]
print('LINKED_IDS', linked_ids, flush=True)
assert not linked_ids, 'Appended data must be local before removing library bookkeeping.'
for library in list(bpy.data.libraries): bpy.data.libraries.remove(library)
print('LIBRARIES_AFTER_LOCAL', len(bpy.data.libraries), flush=True)
bpy.context.view_layer.update()
points = world_bbox(model_meshes)
metrics = {
    'blender_version': bpy.app.version_string,
    'sources': {key:str(path.relative_to(ROOT)) for key,path in SOURCES.items()},
    'mesh_objects': len(model_meshes),
    'vertices': sum(len(ob.data.vertices) for ob in model_meshes),
    'polygons': sum(len(ob.data.polygons) for ob in model_meshes),
    'triangles': sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in model_meshes),
    'materials': sorted({ma.name for ob in model_meshes for ma in ob.data.materials if ma}),
    'external_libraries': len(bpy.data.libraries),
    'bounds': {'min':[min(p[i] for p in points) for i in range(3)], 'max':[max(p[i] for p in points) for i in range(3)]},
    'render': {'engine':'CYCLES', 'device':'CPU', 'samples':scene.cycles.samples, 'denoise':False,
               'resolution':[scene.render.resolution_x, scene.render.resolution_y], 'view_transform':'AgX', 'exposure':scene.view_settings.exposure},
    'views': [{'name':c.name, 'position':list(c.location), 'ortho_scale':c.data.ortho_scale} for c in [overview,closeup]],
}
assert metrics['external_libraries'] == 0, 'Final model must have no linked-library dependencies.'
assert metrics['mesh_objects'] > 10 and metrics['vertices'] > 1000, 'Unexpectedly empty assembly.'
print('ASSEMBLY_METRICS', json.dumps(metrics), flush=True)
(ART/'assembly_metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf8')

# Pack any image assets if the sculptors added them; material-only geometry needs none.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'sunny_shell_island_v3.blend'))
bpy.ops.object.select_all(action='DESELECT')
for ob in asset_objects:
    if ob.type in {'MESH', 'EMPTY', 'ARMATURE'}:
        ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ART/'sunny_shell_island_v3.glb'), export_format='GLB', use_selection=True,
                         export_yup=True, export_cameras=False, export_lights=False, export_apply=True)
# Standalone landscape+vegetation export has no actors (prevents later duplication).
bpy.ops.object.select_all(action='DESELECT')
for key in ['Landscape','Plants']:
    for ob in groups[key].objects:
        if ob.type in {'MESH','EMPTY'} and not ob.get('render_only'):
            ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ART/'environment_v3.glb'), export_format='GLB', use_selection=True,
                         export_yup=True, export_cameras=False, export_lights=False, export_apply=True)
print('PORTABLE_MODELS_READY', flush=True)

if not args.assemble_only:
    if args.view in {'all', 'overview'}:
        bpy.ops.render.render(write_still=True)
        print('OVERVIEW_READY', scene.render.filepath, flush=True)
    if args.view in {'all', 'closeup'}:
        scene.camera = closeup
        scene.render.filepath = str(ART/f'island_v3_friends{suffix}.png')
        bpy.ops.render.render(write_still=True)
        print('CLOSEUP_READY', scene.render.filepath, flush=True)
    scene.camera = overview
    scene.render.filepath = str(ART/'island_v3_overview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/'sunny_shell_island_v3.blend'))
print('V3_ASSEMBLY_COMPLETE', flush=True)
