"""Headless visual QA of the exact shared runtime idle pose (not exported rest).
Run: blender -b --python art/source/animals/rabbit/render_rabbit.py
"""
import bpy
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent

def xyz(p):return (p[0],-p[2],p[1])
def setup(team):
    bpy.ops.wm.open_mainfile(filepath=str(HERE/f'rabbit_{team}.blend'))
    for name,a,fa in [('ArmR',.50,.70),('ArmL',.20,.35)]:
        arm=bpy.data.objects[name];arm.rotation_euler.x=a
        fore=next(o for o in arm.children if o.name.startswith('Forearm'));fore.rotation_euler.x=fa
    bpy.data.objects['ArmL'].rotation_euler.y=-.09
    scene=bpy.context.scene;scene.render.resolution_x=850;scene.render.resolution_y=1000
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
    scene.eevee.taa_render_samples=32
    return scene
for team in ['blue','orange']:
    scene=setup(team);scene.render.filepath=str(HERE/f'rabbit_{team}_held_closeup.png');bpy.ops.render.render(write_still=True)
scene=setup('blue');camera=scene.camera;camera.location=xyz((-3.4,1.8,3.1));target=Vector(xyz((0,.95,.08)));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=2.35
scene.render.filepath=str(HERE/'rabbit_blue_rear_tail.png');bpy.ops.render.render(write_still=True)
