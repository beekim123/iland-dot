"""Offline catalogue studio portraits of the project's actual GLB assets, not gameplay screenshots."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parents[1]/'covers'
JOBS=[('bloom_skirmish','modules/bloom_skirmish/art/models/animals/rigged/fox/fox_blue_rigged.glb',(0.65,.86,.77)),('tide_gulp','modules/tide_gulp/art/fish/moonfish_1.glb',(.62,.79,.88)),('beach_cleanup','modules/beach_cleanup/art/vehicle/cart_model.glb',(.88,.80,.61)),('volcano_escape','modules/volcano_escape/art/character/otter.glb',(.85,.66,.55))]
for name,rel,bg in JOBS:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/rel))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 depsgraph=bpy.context.evaluated_depsgraph_get()
 evaluated=[o.evaluated_get(depsgraph) for o in meshes]
 points=[o.matrix_world@Vector(p) for o in evaluated for p in o.bound_box]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 center=(lo+hi)*.5; span=max(hi-lo)
 if name in ("bloom_skirmish","volcano_escape"): center.z+=span*.20
 # Retain original geometry, rigs, materials. Frame the asset in a studio, not a fabricated scene.
 bpy.ops.object.camera_add(location=center+Vector((1.3,2.3,1.05))*span)
 camera=bpy.context.object;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=span*1.9
 scene=bpy.context.scene;scene.camera=camera
 for pos,power,size in [((2,-3,4),650,4),((-3,-1,2),350,3)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(pos)*span);light=bpy.context.object;light.data.energy=power*span*span;light.data.shape='DISK';light.data.size=size*span;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 world=bpy.data.worlds.new('Catalogue studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(*bg,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
 scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=False
 scene.render.resolution_x=640;scene.render.resolution_y=360;scene.render.resolution_percentage=100
 scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/(name+'.png'))
 bpy.ops.render.render(write_still=True)
