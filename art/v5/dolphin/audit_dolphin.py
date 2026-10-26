import bpy,json,os,math
from mathutils import Vector
O=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=O+'/dolphin_rigged.blend')
rig=bpy.data.objects['Dolphin_Rig'];objs=[o for o in bpy.data.objects if any(m.type=='ARMATURE' for m in o.modifiers)]
sc=bpy.context.scene;qa=json.load(open(O+'/rig_qa.json'));dg=bpy.context.evaluated_depsgraph_get()
def coords(f):
 sc.frame_set(f);dg.update();return {o.name:[v.co.copy() for v in o.evaluated_get(dg).data.vertices] for o in objs}
a=coords(1);b=coords(13);end=coords(97)
qa['max_pose_displacement_m']=max((p-q).length for n in a for p,q in zip(a[n],b[n]));qa['loop_max_vertex_error_m']=max((p-q).length for n in a for p,q in zip(a[n],end[n]));qa['finite_vertices']=all(math.isfinite(x) for points in b.values() for p in points for x in p)
assert qa['max_pose_displacement_m']>.05 and qa['loop_max_vertex_error_m']<1e-5 and qa['finite_vertices']
json.dump(qa,open(O+'/rig_qa.json','w'),indent=2)
sc.frame_set(1);sc.cycles.samples=32;sc.render.filepath=O+'/dolphin_pose_clean.png';bpy.ops.render.render(write_still=True)
