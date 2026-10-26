import bpy,os
out=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(out,'turtle_rigged.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=3;s.cycles.max_bounces=2;s.cycles.use_denoising=False;s.render.threads_mode='FIXED';s.render.threads=2
s.render.resolution_x=480;s.render.resolution_y=360;s.render.resolution_percentage=100
s.frame_start=1;s.frame_end=95;s.frame_step=2
os.makedirs(os.path.join(out,'draft_frames'),exist_ok=True)
for i,fr in enumerate(range(1,97,2)):
 s.frame_set(fr);s.render.filepath=os.path.join(out,'draft_frames','frame_%03d.png'%i);bpy.ops.render.render(write_still=True)
print('DRAFT_COMPLETE',flush=True)
