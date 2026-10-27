"""Render articulated otter inspection stills using the live runtime idle pose.
Run: blender -b --python art/source/animals/otter/render_otter.py
The exported GLBs keep rest joint transforms; this is a source-only pose preview.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent

def xyz(p):return (p[0],-p[2],p[1])

def setup(team):
    bpy.ops.wm.open_mainfile(filepath=str(HERE/f'otter_{team}.blend'))
    for name,a,fa in [('ArmR',.50,.70),('ArmL',.20,.35)]:
        arm=bpy.data.objects[name];arm.rotation_euler.x=a
        fore=next(o for o in arm.children if o.name.startswith('Forearm'))
        fore.rotation_euler.x=fa
    bpy.data.objects['ArmL'].rotation_euler.y=-.09
    scene=bpy.context.scene;scene.render.resolution_x=850;scene.render.resolution_y=950
    scene.render.image_settings.file_format='PNG'
    return scene

for team in ['blue','orange']:
    scene=setup(team);scene.render.filepath=str(HERE/f'otter_{team}_held_closeup.png')
    bpy.ops.render.render(write_still=True)
scene=setup('blue');camera=scene.camera;camera.location=xyz((-3.5,1.7,2.9));target=Vector(xyz((0,.75,.15)));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=2.25
scene.render.filepath=str(HERE/'otter_blue_rear_tail.png');bpy.ops.render.render(write_still=True)
