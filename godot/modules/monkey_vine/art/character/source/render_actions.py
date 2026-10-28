import bpy,os
from mathutils import Vector
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(root+'/previews',exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=root+'/source/monkey.blend');rig=bpy.data.objects['MonkeyRig']
for tr in rig.animation_data.nla_tracks:tr.mute=True
P=lambda p:Vector((p[0],-p[2],p[1]))
bpy.ops.object.camera_add(location=P((.9,.45,4)));cam=bpy.context.object;cam.rotation_euler=(P((-.1,.02,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.6;bpy.context.scene.camera=cam
for pos,power,size in [((2,3,4),180,4),((-2,1,2),90,3)]:
 bpy.ops.object.light_add(type='AREA',location=P(pos));l=bpy.context.object;l.data.energy=power;l.data.size=size;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.world.color=(.08,.1,.09);s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=False;s.render.resolution_x=720;s.render.resolution_y=720;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
for clip,frame in [('swing',12),('air',9),('run',6)]:
 rig.animation_data.action=bpy.data.actions[clip];s.frame_set(frame);s.render.filepath=root+'/previews/monkey_'+clip+'.png';bpy.ops.render.render(write_still=True)
