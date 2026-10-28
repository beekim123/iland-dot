import bpy, os,json
from mathutils import Vector
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=root+'/source/monkey.blend')
rig=bpy.data.objects['MonkeyRig'];mesh=bpy.data.objects['MonkeySkin']
for t in rig.animation_data.nla_tracks:t.mute=True
report={};fail=[]
for name in ['idle','run','grab','swing','air','land','fall']:
 rig.animation_data.action=bpy.data.actions[name];duration=int(rig.animation_data.action.frame_range[1]);samples=[];maxgrip=0
 for frame in [0,duration//4,duration//2,3*duration//4,duration]:
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();evaluated=mesh.evaluated_get(dg);v=evaluated.to_mesh();samples.append([evaluated.matrix_world@p.co for p in v.vertices]);evaluated.to_mesh_clear()
  grip=(rig.pose.bones['handNear'].head+rig.pose.bones['handFar'].head)/2
  maxgrip=max(maxgrip,(grip-Vector((0,0,.45))).length)
 delta=max((a-b).length for sample in samples[1:] for a,b in zip(samples[0],sample))
 if delta<.001:fail.append(name+' no evaluated vertex motion')
 if name in ['grab','swing'] and maxgrip>.002:fail.append(name+' raw hand error')
 report[name]={'max_evaluated_vertex_motion_m':delta,'raw_grip_error_m':maxgrip}
weights=[sum(g.weight for g in v.groups) for v in mesh.data.vertices]
if max(abs(w-1) for w in weights)>.001:fail.append('weights not normalized')
report['weight_error']=max(abs(w-1) for w in weights);report['failures']=fail
open(root+'/source/skin_verification.json','w').write(json.dumps(report,indent=2));print(json.dumps(report));assert not fail
