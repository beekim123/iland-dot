import bpy,sys,os
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'seagull_rigged.blend'))
s=bpy.context.scene
if '--eevee' in sys.argv:s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=16
s.render.filepath=os.path.join(OUT,'eevee_test.png');s.frame_set(13)
if '--test' in sys.argv:bpy.ops.render.render(write_still=True)
else:
 os.makedirs(os.path.join(OUT,'frames'),exist_ok=True)
 s.render.filepath=os.path.join(OUT,'frames/frame_');s.frame_start=1;s.frame_end=96
 bpy.ops.render.render(animation=True)
