"""Independent evaluated-Blender pose and mesh checks, after reopening final source."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
species=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'otter'
reports=[]
for team in ['blue','orange']:
 path=HERE/species/f'{species}_{team}_rigged.blend';bpy.ops.wm.open_mainfile(filepath=str(path));rig=bpy.data.objects['CharacterRig'];scene=bpy.context.scene
 grip=bpy.data.objects['GunGrip'].matrix_world.translation.copy();muzzle=bpy.data.objects['Muzzle'].matrix_world.translation.copy()
 report={'species':species,'team':team,'status':'PASS','actual_armature_modifiers':0,'clips':{},'physical_muzzle':[muzzle.x*1.3,muzzle.z*1.3+.04,-muzzle.y*1.3]}
 for o in bpy.context.scene.objects:
  if o.type=='MESH':report['actual_armature_modifiers']+=sum(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)
 assert report['actual_armature_modifiers']>=10
 for action in bpy.data.actions:
  rig.animation_data.action=action
  metric={'max_right_palm_error':0.,'max_arm_joint_gap':0.,'max_leg_joint_gap':0.,'min_hindpaw_surface_height':1e9,'max_bone_length_relative_error':0.}
  for frame in range(int(action.frame_range.x),int(action.frame_range.y)+1):
   scene.frame_set(frame);bpy.context.view_layer.update()
   metric['max_right_palm_error']=max(metric['max_right_palm_error'],(rig.pose.bones['Hand.R'].head-grip).length)
   for side in ['L','R']:
    for a,b in [('UpperArm.','Forearm.'),('Forearm.','Hand.'),('Thigh.','Shin.'),('Shin.','Foot.')]:
     v=(rig.pose.bones[a+side].tail-rig.pose.bones[b+side].head).length
     key='max_arm_joint_gap' if a in ['UpperArm.','Forearm.'] else 'max_leg_joint_gap';metric[key]=max(metric[key],v)
    for bn in ['UpperArm.','Forearm.','Thigh.','Shin.','Foot.']:
     pb=rig.pose.bones[bn+side];metric['max_bone_length_relative_error']=max(metric['max_bone_length_relative_error'],abs(pb.length/pb.bone.length-1))
   # Every frame's final evaluated ankle/paw mesh, not only a marker.
   deps=bpy.context.evaluated_depsgraph_get()
   for o in bpy.context.scene.objects:
    if o.type=='MESH' and o.name in ['Shin_Skinned','ShinR_Skinned']:
     ev=o.evaluated_get(deps);me=ev.to_mesh();low=min((ev.matrix_world@v.co).z for v in me.vertices);metric['min_hindpaw_surface_height']=min(metric['min_hindpaw_surface_height'],low);ev.to_mesh_clear()
  assert metric['max_right_palm_error']<2e-5,(action.name,metric)
  assert metric['max_arm_joint_gap']<2e-5 and metric['max_leg_joint_gap']<2e-5,(action.name,metric)
  assert metric['max_bone_length_relative_error']<2e-5,(action.name,metric)
  assert metric['min_hindpaw_surface_height']>-.006,(action.name,metric)
  report['clips'][action.name]=metric
 reports.append(report)
(HERE/species/'evaluated_pose_validation.json').write_text(json.dumps({'status':'PASS','assets':reports},indent=2));print('EVALUATED_POSE_VALIDATION',json.dumps(reports))
