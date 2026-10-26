import bpy,os
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'fish_rigged.blend'))
s=bpy.context.scene;s.frame_set(1);r=bpy.data.objects['Fish_Rig']
for pb in r.pose.bones:
 pb.keyframe_insert('rotation_euler',frame=97,group=pb.name)
 if pb.name=='root':pb.keyframe_insert('location',frame=97,group=pb.name)
s.frame_end=96;bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'fish_rigged.blend'));s.frame_end=97
bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o in r.children_recursive:o.select_set(True)
bpy.context.view_layer.objects.active=r
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'fish_rigged.glb'),use_selection=True,export_format='GLB',export_animations=True,export_skins=True,export_yup=True,export_frame_range=True,export_force_sampling=True,export_animation_mode='ACTIONS',export_apply=False)
