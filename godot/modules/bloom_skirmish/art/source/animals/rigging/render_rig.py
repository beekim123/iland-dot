import bpy,sys,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
species=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'otter'
team='blue'
bpy.ops.wm.open_mainfile(filepath=str(HERE/species/f'{species}_{team}_rigged.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['CharacterRig']
def g(p):return Vector((p[0],-p[2],p[1]))
# Source-only QA studio is never exported with game assets.
camdata=bpy.data.cameras.new('QA_Camera');cam=bpy.data.objects.new('QA_Camera',camdata);bpy.context.collection.objects.link(cam)
cam.location=g((2.8,1.6,-3.8));target=g((0,.82,.06));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=2.2 if species!='rabbit' else 2.5
scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.render.resolution_x=560;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.film_transparent=False;scene.world.color=(.28,.28,.28);scene.view_settings.view_transform='AgX'
for name,loc,power,size in [('Key',(-3,4,-4),550,4),('Fill',(3,2,-2),300,3),('Rim',(1,3,4),650,3)]:
 ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size;o=bpy.data.objects.new(name,ld);bpy.context.collection.objects.link(o);o.location=g(loc);o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
# Matte floor gives honest sole/contact evidence.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));floor=bpy.context.object
mat=bpy.data.materials.new('QA warm neutral floor');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.22,.23,.22,1);bs.inputs['Roughness'].default_value=1;floor.data.materials.append(mat)
for action,frame in [('idle',1),('run',5),('run',14),('spray',7),('pod',13),('celebration',13)]:
 rig.animation_data.action=bpy.data.actions[action];scene.frame_set(frame);bpy.context.view_layer.update()
 scene.render.filepath=str(HERE/species/f'{species}_{team}_{action}_{frame:02d}.png');bpy.ops.render.render(write_still=True)
