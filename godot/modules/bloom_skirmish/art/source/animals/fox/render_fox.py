"""Non-exported local studio QA; all staging is temporary, not model content."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
team='blue'
if '--' in sys.argv:team=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/f'fox_{team}.blend'))
root=bpy.data.objects['AthleteRoot']
# Same natural ready stance as runtime, preserving animation pivots.
bpy.data.objects['ArmR'].rotation_euler.x=.50
bpy.data.objects['ArmL'].rotation_euler.x=.20
bpy.data.objects['ArmL'].rotation_euler.y=-.09
for n in ['ArmR','ArmL']:
    fore=next(o for o in bpy.data.objects[n].children if o.name.startswith('Forearm'))
    fore.rotation_euler.x=.70 if n=='ArmR' else .35
sc=bpy.context.scene;sc.render.engine='BLENDER_EEVEE_NEXT';sc.render.resolution_x=1100;sc.render.resolution_y=1100;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.36,.44,.50,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.55
sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast'
def area(name,loc,energy,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
area('Key',(-3,4,5),500,4);area('Fill',(4,2,3),220,3);area('Rim',(-2,-3,4),550,3)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));floor=bpy.context.object;m=bpy.data.materials.new('Studio pale floor');m.diffuse_color=(.25,.31,.32,1);floor.data.materials.append(m)
d=bpy.data.cameras.new('Studio Camera');cam=bpy.data.objects.new('Studio Camera',d);bpy.context.collection.objects.link(cam);cam.location=(2.7,5.2,2.45);target=Vector((-.08,.02,.80));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=2.05;sc.camera=cam
sc.render.filepath=str(HERE/f'fox_{team}_studio.png');bpy.ops.render.render(write_still=True)
