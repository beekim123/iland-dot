import bpy,os
OUT=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'seagull_rigged.blend'))
s=bpy.context.scene;s.render.resolution_x=480;s.render.resolution_y=360;s.cycles.samples=4;s.cycles.max_bounces=2;s.render.threads_mode='FIXED';s.render.threads=2
os.makedirs(os.path.join(OUT,'frames_quick'),exist_ok=True)
for f in range(1,97,2):
 s.frame_set(f);s.render.filepath=os.path.join(OUT,'frames_quick/frame_%04d.png'%f);bpy.ops.render.render(write_still=True)
