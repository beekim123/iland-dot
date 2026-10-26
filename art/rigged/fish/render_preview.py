import bpy, os, sys
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'fish_rigged.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=False;s.cycles.max_bounces=2;s.render.threads_mode='FIXED';s.render.threads=2
s.render.resolution_x=480;s.render.resolution_y=360;s.render.resolution_percentage=100
# Real sampled 12fps preview; final source animation remains 24fps.
s.frame_step=2;s.frame_start=1;s.frame_end=95
os.makedirs(os.path.join(OUT,'frames'),exist_ok=True);s.render.filepath=os.path.join(OUT,'frames','fish_');s.render.image_settings.file_format='PNG'
bpy.ops.render.render(animation=True)
print('FISH_ANIMATION_PREVIEW_READY',flush=True)
